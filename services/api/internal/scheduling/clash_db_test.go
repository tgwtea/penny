package scheduling_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/tgwtea/penny/services/api/internal/app"
	"github.com/tgwtea/penny/services/api/internal/identity/identitytest"
	"github.com/tgwtea/penny/services/api/internal/platform/clock"
	"github.com/tgwtea/penny/services/api/internal/platform/schema/schematest"
	"github.com/tgwtea/penny/services/api/internal/scheduling"
)

// TestClashQueryMatchesTheSharedFixtures books each fixture's lessons
// through the service and checks the database's clash query reports
// exactly the clashes the pure rule (and the client's) does.
func TestClashQueryMatchesTheSharedFixtures(t *testing.T) {
	files, err := filepath.Glob("../../../../api/fixtures/clashes/*.json")
	if err != nil || len(files) == 0 {
		t.Fatalf("no fixtures: %v", err)
	}
	for _, f := range files {
		t.Run(filepath.Base(f), func(t *testing.T) {
			var fx struct {
				Lessons []struct {
					ID       string    `json:"id"`
					Start    time.Time `json:"start"`
					End      time.Time `json:"end"`
					Status   string    `json:"status"`
					Tutors   []string  `json:"tutors"`
					Students []string  `json:"students"`
				} `json:"lessons"`
				Clashes []struct {
					Lesson  string `json:"lesson"`
					With    string `json:"with"`
					Tutor   string `json:"tutor"`
					Student string `json:"student"`
				} `json:"clashes"`
			}
			b, err := os.ReadFile(f)
			if err != nil {
				t.Fatal(err)
			}
			if err := json.Unmarshal(b, &fx); err != nil {
				t.Fatal(err)
			}

			team := newTeam(t)
			ctx := context.Background()
			tutors, students := map[string]uuid.UUID{}, map[string]uuid.UUID{}
			lessonName := map[uuid.UUID]string{}
			for _, l := range fx.Lessons {
				in := scheduling.LessonInput{StartsAt: l.Start, EndsAt: l.End}
				for i, name := range l.Tutors {
					role := scheduling.Assisting
					if i == 0 {
						role = scheduling.Lead
					}
					in.Tutors = append(in.Tutors, scheduling.TutorInput{MembershipID: team.tutor(tutors, name), Role: role})
				}
				for _, name := range l.Students {
					in.StudentIDs = append(in.StudentIDs, team.student(students, name))
				}
				lesson, err := team.svc.CreateLesson(ctx, team.owner, team.id, in)
				if err != nil {
					t.Fatalf("book %s: %v", l.ID, err)
				}
				lessonName[lesson.ID] = l.ID
				team.setStatus(lesson, l.Status)
			}

			lessons, _, err := team.svc.ListLessons(ctx, team.owner, team.id, scheduling.LessonQuery{
				From: time.Date(2026, 11, 18, 0, 0, 0, 0, time.UTC), To: time.Date(2026, 11, 21, 0, 0, 0, 0, time.UTC),
			})
			if err != nil {
				t.Fatal(err)
			}
			nameOf := func(m map[string]uuid.UUID, id *uuid.UUID) string {
				for name, v := range m {
					if id != nil && v == *id {
						return name
					}
				}
				return ""
			}
			var got, want []scheduling.ClashPair
			for _, l := range lessons {
				for _, c := range l.Clashes {
					got = append(got, scheduling.ClashPair{
						Lesson: lessonName[l.ID], With: lessonName[c.LessonID],
						Tutor: nameOf(tutors, c.MembershipID), Student: nameOf(students, c.StudentID),
					})
				}
			}
			for _, c := range fx.Clashes {
				want = append(want, scheduling.ClashPair{Lesson: c.Lesson, With: c.With, Tutor: c.Tutor, Student: c.Student})
			}
			scheduling.SortClashPairs(got)
			scheduling.SortClashPairs(want)
			if !slices.Equal(got, want) {
				t.Errorf("database clashes\n got %+v\nwant %+v", got, want)
			}
		})
	}
}

// team is a test team: an owner, and tutors and students made on demand.
type team struct {
	t     *testing.T
	svc   *scheduling.Service
	owner uuid.UUID
	id    uuid.UUID
	// exec runs SQL that returns one id, for setting up tutors directly.
	exec func(sql string, args ...any) uuid.UUID
}

func newTeam(t *testing.T) *team {
	t.Helper()
	pool := schematest.NewDatabase(t)
	verifier := identitytest.NewVerifier()
	clk := clock.NewFixed(time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC))
	services, err := app.New(app.Deps{Pool: pool, Verifier: verifier, Clock: clk})
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	verifier.Add("owner", identitytest.Person("owner-uid", "owner@example.com", "Owner"))
	owner, err := services.Users.Authenticate(ctx, "owner")
	if err != nil {
		t.Fatal(err)
	}
	m, err := services.Teams.Create(ctx, owner, "Fixture Studio", "")
	if err != nil {
		t.Fatal(err)
	}
	tm := &team{t: t, svc: services.Scheduling, owner: owner.ID, id: m.Workspace.ID}
	tm.exec = func(sql string, args ...any) uuid.UUID {
		var id uuid.UUID
		if err := pool.QueryRow(ctx, sql, args...).Scan(&id); err != nil {
			t.Fatal(err)
		}
		return id
	}
	return tm
}

// tutor returns the membership for name, adding them as an active teacher.
func (tm *team) tutor(seen map[string]uuid.UUID, name string) uuid.UUID {
	if id, ok := seen[name]; ok {
		return id
	}
	user := tm.exec(`INSERT INTO users (firebase_uid, email, display_name) VALUES ($1, $1 || '@example.com', $1) RETURNING id`, name)
	id := tm.exec(`INSERT INTO workspace_memberships (workspace_id, user_id, role, status, display_name, email, joined_at)
		VALUES ($1, $2, 'teacher', 'active', $3, $3 || '@example.com', now()) RETURNING id`, tm.id, user, name)
	seen[name] = id
	return id
}

func (tm *team) student(seen map[string]uuid.UUID, name string) uuid.UUID {
	if id, ok := seen[name]; ok {
		return id
	}
	s, err := tm.svc.CreateStudent(context.Background(), tm.owner, tm.id, scheduling.StudentInput{Name: name})
	if err != nil {
		tm.t.Fatal(err)
	}
	seen[name] = s.ID
	return s.ID
}

func (tm *team) setStatus(l scheduling.Lesson, status string) {
	ctx := context.Background()
	var err error
	switch status {
	case "scheduled":
	case "completed":
		_, err = tm.svc.CompleteLesson(ctx, tm.owner, tm.id, l.ID, l.Version, nil)
	case "no_show":
		_, err = tm.svc.MarkNoShow(ctx, tm.owner, tm.id, l.ID, l.Version)
	case "cancelled":
		_, err = tm.svc.CancelLesson(ctx, tm.owner, tm.id, l.ID, l.Version, scheduling.CancelInput{Party: scheduling.CancelledByTutor})
	default:
		tm.t.Fatalf("unknown status %q", status)
	}
	if err != nil {
		tm.t.Fatalf("set %s: %v", status, err)
	}
}
