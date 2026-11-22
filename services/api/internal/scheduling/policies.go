package scheduling

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/authz"
	"github.com/tgwtea/penny/services/api/internal/scheduling/schedulingsql"
)

// GetPolicy returns a tutor's cancellation policy, or the default. Any
// member may read it: it is shown to parents too.
func (s *Service) GetPolicy(ctx context.Context, userID, workspaceID, membershipID uuid.UUID) (Policy, error) {
	var out Policy
	err := s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, _ authz.Actor, st store) error {
		if err := s.checkMember(ctx, tx, workspaceID, membershipID); err != nil {
			return err
		}
		var err error
		out, err = st.policy(ctx, membershipID)
		return err
	})
	return out, err
}

// SetPolicy sets a tutor's cancellation policy: their own, or anyone's for
// an owner.
func (s *Service) SetPolicy(ctx context.Context, userID, workspaceID, membershipID uuid.UUID, in PolicyInput) (Policy, error) {
	if in.NoticeHours < 0 || in.NoticeHours > MaxNoticeHours {
		return Policy{}, apperr.New(apperr.ErrValidation, "Ask for between 0 hours and two weeks of notice.")
	}
	summary, err := optionalText(in.Summary, "the policy", 500)
	if err != nil {
		return Policy{}, err
	}
	var out Policy
	err = s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if err := authz.SetCancellationPolicy(a, membershipID); err != nil {
			return err
		}
		if err := s.checkStaff(ctx, tx, workspaceID, []uuid.UUID{membershipID}, "The tutor"); err != nil {
			return err
		}
		before, err := st.policy(ctx, membershipID)
		if err != nil {
			return err
		}
		row, err := st.q.UpsertCancellationPolicy(ctx, schedulingsql.UpsertCancellationPolicyParams{
			WorkspaceID: workspaceID, MembershipID: membershipID, NoticeHours: int32(in.NoticeHours),
			LateCancellationBillable: in.LateCancellationBillable, NoShowBillable: in.NoShowBillable,
			Summary: summary, UpdatedBy: a.UserID,
		})
		if err != nil {
			return fmt.Errorf("set cancellation policy: %w", err)
		}
		out = toPolicy(row)
		return s.record(ctx, tx, a, "policy.updated", "membership", membershipID, policyAudit(before), policyAudit(out))
	})
	return out, err
}

// checkMember confirms a membership is in the team.
func (s *Service) checkMember(ctx context.Context, tx pgx.Tx, workspaceID, membershipID uuid.UUID) error {
	members, err := s.teams.MembersByID(ctx, tx, workspaceID, []uuid.UUID{membershipID})
	if err != nil {
		return err
	}
	if _, ok := members[membershipID]; !ok {
		return apperr.ErrNotFound
	}
	return nil
}

func policyAudit(p Policy) map[string]any {
	return map[string]any{
		"notice_hours": p.NoticeHours, "late_cancellation_billable": p.LateCancellationBillable,
		"no_show_billable": p.NoShowBillable, "default": p.IsDefault,
	}
}
