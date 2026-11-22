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

var (
	itemKinds    = map[string]bool{"task": true, "goal": true, "note": true}
	visibilities = map[string]bool{"staff": true, "student": true, "contacts": true}
)

// AddItem adds a task, goal or note to a lesson, for owners and the
// lesson's tutors.
func (s *Service) AddItem(ctx context.Context, userID, workspaceID, lessonID uuid.UUID, in ItemInput) (LessonItem, error) {
	body, err := requiredText(in.Body, "what to add", 2000)
	if err != nil {
		return LessonItem{}, err
	}
	if !itemKinds[in.Kind] {
		return LessonItem{}, apperr.New(apperr.ErrValidation, "An item is a task, a goal or a note.")
	}
	if in.Visibility == "" {
		in.Visibility = "staff"
	}
	if !visibilities[in.Visibility] {
		return LessonItem{}, apperr.New(apperr.ErrValidation, "Say who may see this: staff, the student or their contacts.")
	}
	var out LessonItem
	err = s.asItemEditor(ctx, userID, workspaceID, lessonID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if in.GoalID != nil {
			belongs, err := st.q.GoalBelongsToLessonStudent(ctx, schedulingsql.GoalBelongsToLessonStudentParams{
				WorkspaceID: workspaceID, GoalID: *in.GoalID, LessonID: lessonID,
			})
			if err != nil {
				return fmt.Errorf("check goal: %w", err)
			}
			if !belongs {
				return apperr.New(apperr.ErrValidation, "Link only to a goal of a student in this lesson.")
			}
		}
		row, err := st.q.CreateLessonItem(ctx, schedulingsql.CreateLessonItemParams{
			WorkspaceID: workspaceID, LessonID: lessonID, Kind: schedulingsql.ItemKind(in.Kind), Body: body,
			Visibility: schedulingsql.ItemVisibility(in.Visibility), StudentGoalID: in.GoalID, AuthorMembership: a.MembershipID,
		})
		if err != nil {
			return fmt.Errorf("add lesson item: %w", err)
		}
		if out, err = s.item(ctx, tx, st, row); err != nil {
			return err
		}
		return s.record(ctx, tx, a, "lesson.item_added", "lesson", lessonID, nil, map[string]any{"item_id": row.ID, "kind": row.Kind})
	})
	return out, err
}

// UpdateItem edits an item, or ticks or unticks a task.
func (s *Service) UpdateItem(ctx context.Context, userID, workspaceID, lessonID, itemID uuid.UUID, c ItemChanges) (LessonItem, error) {
	if c.Body != nil {
		body, err := requiredText(*c.Body, "the text", 2000)
		if err != nil {
			return LessonItem{}, err
		}
		c.Body = &body
	}
	var visibility *schedulingsql.ItemVisibility
	if c.Visibility != nil {
		if !visibilities[*c.Visibility] {
			return LessonItem{}, apperr.New(apperr.ErrValidation, "Say who may see this: staff, the student or their contacts.")
		}
		v := schedulingsql.ItemVisibility(*c.Visibility)
		visibility = &v
	}
	var out LessonItem
	err := s.asItemEditor(ctx, userID, workspaceID, lessonID, func(tx pgx.Tx, a authz.Actor, st store) error {
		existing, err := st.q.GetLessonItem(ctx, schedulingsql.GetLessonItemParams{WorkspaceID: workspaceID, LessonID: lessonID, ID: itemID})
		if err != nil {
			return readErr(err, "lesson item")
		}
		if c.Done != nil && existing.Kind != schedulingsql.ItemKindTask {
			return apperr.New(apperr.ErrValidation, "Only tasks can be ticked off.")
		}
		now := s.clock.Now()
		row, err := st.q.UpdateLessonItem(ctx, schedulingsql.UpdateLessonItemParams{
			Body: c.Body, Visibility: visibility, Done: c.Done, Now: &now,
			WorkspaceID: workspaceID, LessonID: lessonID, ID: itemID,
		})
		if err != nil {
			return readErr(err, "lesson item")
		}
		if out, err = s.item(ctx, tx, st, row); err != nil {
			return err
		}
		return s.record(ctx, tx, a, "lesson.item_updated", "lesson", lessonID, nil,
			map[string]any{"item_id": itemID, "done": row.DoneAt != nil})
	})
	return out, err
}

// DeleteItem removes an item: owners, or its author.
func (s *Service) DeleteItem(ctx context.Context, userID, workspaceID, lessonID, itemID uuid.UUID) error {
	return s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		tutors, _, err := st.tutorIDs(ctx, lessonID)
		if err != nil {
			return err
		}
		if err := authz.ViewLesson(a, tutors); err != nil {
			return err
		}
		existing, err := st.q.GetLessonItem(ctx, schedulingsql.GetLessonItemParams{WorkspaceID: workspaceID, LessonID: lessonID, ID: itemID})
		if err != nil {
			return readErr(err, "lesson item")
		}
		if err := authz.DeleteLessonItem(a, existing.AuthorMembership); err != nil {
			return err
		}
		if _, err := st.q.DeleteLessonItem(ctx, schedulingsql.DeleteLessonItemParams{WorkspaceID: workspaceID, LessonID: lessonID, ID: itemID}); err != nil {
			return fmt.Errorf("delete lesson item: %w", err)
		}
		return s.record(ctx, tx, a, "lesson.item_removed", "lesson", lessonID,
			map[string]any{"item_id": itemID, "kind": existing.Kind}, nil)
	})
}

// asItemEditor runs fn for someone who may edit the lesson's items.
func (s *Service) asItemEditor(ctx context.Context, userID, workspaceID, lessonID uuid.UUID, fn func(pgx.Tx, authz.Actor, store) error) error {
	return s.inTeam(ctx, userID, workspaceID, func(tx pgx.Tx, a authz.Actor, st store) error {
		if _, err := st.q.GetLesson(ctx, schedulingsql.GetLessonParams{WorkspaceID: workspaceID, ID: lessonID}); err != nil {
			return readErr(err, "lesson")
		}
		tutors, _, err := st.tutorIDs(ctx, lessonID)
		if err != nil {
			return err
		}
		if err := authz.EditLessonItems(a, tutors); err != nil {
			return err
		}
		return fn(tx, a, st)
	})
}

// items lists a lesson's items with their authors' names.
func (s *Service) items(ctx context.Context, tx pgx.Tx, st store, lessonID uuid.UUID) ([]LessonItem, error) {
	rows, err := st.q.ListLessonItems(ctx, schedulingsql.ListLessonItemsParams{WorkspaceID: st.workspaceID, LessonID: lessonID})
	if err != nil {
		return nil, fmt.Errorf("list lesson items: %w", err)
	}
	authors := map[uuid.UUID]bool{}
	for _, r := range rows {
		authors[r.AuthorMembership] = true
	}
	names, err := s.teams.MembersByID(ctx, tx, st.workspaceID, keys(authors))
	if err != nil {
		return nil, err
	}
	out := make([]LessonItem, 0, len(rows))
	for _, r := range rows {
		out = append(out, toItem(r, names[r.AuthorMembership].DisplayName))
	}
	return out, nil
}

func (s *Service) item(ctx context.Context, tx pgx.Tx, st store, row schedulingsql.LessonItem) (LessonItem, error) {
	names, err := s.teams.MembersByID(ctx, tx, st.workspaceID, []uuid.UUID{row.AuthorMembership})
	if err != nil {
		return LessonItem{}, err
	}
	return toItem(row, names[row.AuthorMembership].DisplayName), nil
}

func toItem(r schedulingsql.LessonItem, author string) LessonItem {
	return LessonItem{
		ID: r.ID, Kind: string(r.Kind), Body: r.Body, Visibility: string(r.Visibility), DoneAt: r.DoneAt,
		GoalID: r.StudentGoalID, Author: MemberRef{MembershipID: r.AuthorMembership, DisplayName: author}, CreatedAt: r.CreatedAt,
	}
}
