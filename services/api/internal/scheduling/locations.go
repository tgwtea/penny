package scheduling

import (
	"context"
	"fmt"
	"regexp"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/scheduling/schedulingsql"
)

var postalCode = regexp.MustCompile(`^[0-9]{6}$`)

// ListLocations lists the team's current places. Any member may.
func (s *Service) ListLocations(ctx context.Context, userID, workspaceID uuid.UUID) ([]Location, error) {
	var out []Location
	err := s.inTeam(ctx, userID, workspaceID, func(_ pgx.Tx, _ authz.Actor, st store) error {
		rows, err := st.q.ListLocations(ctx, workspaceID)
		if err != nil {
			return fmt.Errorf("list locations: %w", err)
		}
		out = make([]Location, 0, len(rows))
		for _, r := range rows {
			out = append(out, toLocation(schedulingsql.GetLocationRow(r)))
		}
		return nil
	})
	return out, err
}

// CreateLocation saves a place. Needs manage_lessons.
func (s *Service) CreateLocation(ctx context.Context, userID, workspaceID uuid.UUID, in LocationInput) (Location, error) {
	in, err := validLocation(in)
	if err != nil {
		return Location{}, err
	}
	var out Location
	err = s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageLessons); err != nil {
			return err
		}
		row, err := st.q.CreateLocation(ctx, schedulingsql.CreateLocationParams{
			WorkspaceID: workspaceID, Name: in.Name, Kind: schedulingsql.LocationKind(in.Kind),
			AddressLine1: in.AddressLine1, AddressLine2: in.AddressLine2, PostalCode: in.PostalCode,
			Latitude: in.Latitude, Longitude: in.Longitude, MeetingUrl: in.MeetingURL,
		})
		if err != nil {
			return fmt.Errorf("create location: %w", err)
		}
		out = toLocation(schedulingsql.GetLocationRow(row))
		return s.record(ctx, tx, a, "location.created", "location", row.ID, nil, map[string]any{"kind": row.Kind})
	})
	return out, err
}

// UpdateLocation changes a saved place. Lessons already booked keep the
// address they were booked with.
func (s *Service) UpdateLocation(ctx context.Context, userID, workspaceID, locationID uuid.UUID, in LocationInput) (Location, error) {
	in, err := validLocation(in)
	if err != nil {
		return Location{}, err
	}
	var out Location
	err = s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageLessons); err != nil {
			return err
		}
		row, err := st.q.UpdateLocation(ctx, schedulingsql.UpdateLocationParams{
			WorkspaceID: workspaceID, ID: locationID, Name: in.Name, Kind: schedulingsql.LocationKind(in.Kind),
			AddressLine1: in.AddressLine1, AddressLine2: in.AddressLine2, PostalCode: in.PostalCode,
			Latitude: in.Latitude, Longitude: in.Longitude, MeetingUrl: in.MeetingURL,
		})
		if err != nil {
			return readErr(err, "location")
		}
		out = toLocation(schedulingsql.GetLocationRow(row))
		return s.record(ctx, tx, a, "location.updated", "location", locationID, nil, map[string]any{"kind": row.Kind})
	})
	return out, err
}

// ArchiveLocation stops offering a place.
func (s *Service) ArchiveLocation(ctx context.Context, userID, workspaceID, locationID uuid.UUID) error {
	return s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.Require(a, authz.ManageLessons); err != nil {
			return err
		}
		now := s.clock.Now()
		n, err := st.q.ArchiveLocation(ctx, schedulingsql.ArchiveLocationParams{WorkspaceID: workspaceID, ID: locationID, Now: &now})
		if err != nil {
			return fmt.Errorf("archive location: %w", err)
		}
		if n == 0 {
			return apperr.ErrNotFound
		}
		return s.record(ctx, tx, a, "location.archived", "location", locationID, nil, nil)
	})
}

func validLocation(in LocationInput) (LocationInput, error) {
	var err error
	if in.Name, err = requiredText(in.Name, "a name for the place", 100); err != nil {
		return in, err
	}
	if in.AddressLine1, err = optionalText(in.AddressLine1, "the address", 200); err != nil {
		return in, err
	}
	if in.AddressLine2, err = optionalText(in.AddressLine2, "the address", 200); err != nil {
		return in, err
	}
	if in.MeetingURL, err = optionalURL(in.MeetingURL); err != nil {
		return in, err
	}
	switch in.Kind {
	case InPerson:
		if !postalCode.MatchString(in.PostalCode) {
			return in, apperr.New(apperr.ErrValidation, "Enter the six-digit postal code.")
		}
		in.MeetingURL = ""
	case Online:
		in.AddressLine1, in.AddressLine2, in.PostalCode = "", "", ""
		in.Latitude, in.Longitude = nil, nil
	default:
		return in, apperr.New(apperr.ErrValidation, "Say whether the place is in person or online.")
	}
	if (in.Latitude == nil) != (in.Longitude == nil) {
		return in, apperr.New(apperr.ErrValidation, "Give both latitude and longitude, or neither.")
	}
	return in, nil
}
