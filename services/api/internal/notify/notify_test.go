package notify

import (
	"context"
	"encoding/json"
	"flag"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

var update = flag.Bool("update", false, "rewrite golden files in testdata/")

func golden(t *testing.T, name, got string) {
	t.Helper()
	path := "testdata/" + name
	if *update {
		if err := os.WriteFile(path, []byte(got), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s (run go test -update to create it): %v", path, err)
	}
	if got != string(want) {
		t.Errorf("%s differs from the golden file:\n%s", name, got)
	}
}

func reminder() LessonReminder {
	return LessonReminder{
		ContactName: "Priya", StudentFirstName: "Arjun", TeamName: "Koh Guitar Studio",
		Tutors: "Mei Lin Tan and Aisha Rahman", Day: "tomorrow", Date: "Friday 20 November",
		StartTime: "16:00", EndTime: "16:45", Place: "Studio room 2", Address: "1 Orchard Road, Singapore 238859",
		Policy:         "Cancel at least 24 hours before the lesson. Missed lessons are charged; late cancellations are not.",
		UnsubscribeURL: "http://localhost:5173/unsubscribe/token", UnsubscribeText: "Stop lesson reminders",
	}
}

func TestLessonReminderEmail(t *testing.T) {
	r, err := render("lesson_reminder", reminder())
	if err != nil {
		t.Fatal(err)
	}
	if r.Subject != "Reminder: Arjun's lesson tomorrow at 16:00" {
		t.Errorf("subject = %q", r.Subject)
	}
	golden(t, "lesson_reminder.txt", r.Text)
	golden(t, "lesson_reminder.html", r.HTML)
}

func TestInvitationEmail(t *testing.T) {
	r, err := render("member_invitation", Invitation{
		InviteeName: "Mei", InviterName: "Daniel Koh", TeamName: "Koh Guitar Studio", Role: "teacher",
		Email: "meilin@kohguitar.example", SignInURL: "http://localhost:5173/sign-in",
	})
	if err != nil {
		t.Fatal(err)
	}
	if r.Subject != "Daniel Koh added you to Koh Guitar Studio on Penny" {
		t.Errorf("subject = %q", r.Subject)
	}
	golden(t, "member_invitation.txt", r.Text)
	golden(t, "member_invitation.html", r.HTML)
}

func TestEmailsEscapeWhatPeopleTyped(t *testing.T) {
	data := reminder()
	data.Place = `<script>alert("x")</script>`
	r, err := render("lesson_reminder", data)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(r.HTML, "<script>") {
		t.Error("the HTML body carries an unescaped script tag")
	}
}

func TestUnsubscribeTokens(t *testing.T) {
	secret := []byte("0123456789abcdef0123456789abcdef")
	claim := unsubscribeClaim{WorkspaceID: uuid.New(), ContactID: uuid.New(), Category: LessonReminders}
	token := signUnsubscribe(secret, claim)

	got, ok := verifyUnsubscribe(secret, token)
	if !ok || got != claim {
		t.Fatalf("verify(sign(claim)) = %+v, %v", got, ok)
	}
	if _, ok := verifyUnsubscribe([]byte("another secret, another studio...."), token); ok {
		t.Error("a token verified under another secret")
	}
	payload, sig, _ := strings.Cut(token, ".")
	tampered := signUnsubscribe(secret, unsubscribeClaim{WorkspaceID: claim.WorkspaceID, ContactID: uuid.New(), Category: LessonReminders})
	otherPayload, _, _ := strings.Cut(tampered, ".")
	if _, ok := verifyUnsubscribe(secret, otherPayload+"."+sig); ok {
		t.Error("a token with a swapped payload verified")
	}
	if _, ok := verifyUnsubscribe(secret, payload); ok {
		t.Error("a token without a signature verified")
	}
	receipts := signUnsubscribe(secret, unsubscribeClaim{WorkspaceID: claim.WorkspaceID, ContactID: claim.ContactID, Category: Receipts})
	if _, ok := verifyUnsubscribe(secret, receipts); ok {
		t.Error("a link to stop receipts verified; receipts cannot be stopped")
	}
}

func TestMaskEmail(t *testing.T) {
	if got := maskEmail("priya@example.com"); got != "p***@example.com" {
		t.Errorf("maskEmail = %q", got)
	}
}

func TestRelativeDay(t *testing.T) {
	now := time.Date(2026, 11, 19, 16, 20, 0, 0, time.UTC)
	for when, want := range map[time.Time]string{
		now.Add(time.Hour):      "today",
		now.Add(24 * time.Hour): "tomorrow",
		now.Add(72 * time.Hour): "on Sunday",
	} {
		if got := relativeDay(when, now); got != want {
			t.Errorf("relativeDay(%v) = %q, want %q", when, got, want)
		}
	}
	if got := joinNames([]string{"Mei", "Aisha", "Ravi"}); got != "Mei, Aisha and Ravi" {
		t.Errorf("joinNames = %q", got)
	}
}

func TestMIMEMessage(t *testing.T) {
	msg := Message{
		To: Address{Name: "Priya Nair", Email: "priya@example.com"}, Subject: "Reminder: Arjun's lesson — tomorrow",
		Text: "Hi Priya", HTML: "<p>Hi Priya</p>", Category: LessonReminders, Unsubscribe: "http://localhost:8080/v1/unsubscribe/t",
	}
	b, id, err := buildMIME(Address{Name: "Penny", Email: "no-reply@penny.invalid"}, msg, time.Date(2026, 11, 19, 8, 20, 0, 0, time.UTC))
	if err != nil {
		t.Fatal(err)
	}
	s := string(b)
	for _, want := range []string{
		`From: "Penny" <no-reply@penny.invalid>`, `To: "Priya Nair" <priya@example.com>`,
		"Subject: =?utf-8?q?", "List-Unsubscribe: <http://localhost:8080/v1/unsubscribe/t>",
		"List-Unsubscribe-Post: List-Unsubscribe=One-Click", "multipart/alternative", "text/plain; charset=utf-8", "text/html; charset=utf-8",
	} {
		if !strings.Contains(s, want) {
			t.Errorf("message lacks %q", want)
		}
	}
	if !strings.HasSuffix(id, "@penny.invalid>") {
		t.Errorf("Message-ID = %q, want it on the sender's domain", id)
	}
}

func TestPostmarkMailer(t *testing.T) {
	var got postmarkMessage
	var token string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token = r.Header.Get("X-Postmark-Server-Token")
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &got)
		_, _ = w.Write([]byte(`{"ErrorCode":0,"Message":"OK","MessageID":"pm-123"}`))
	}))
	defer srv.Close()

	m := NewPostmarkMailer("server-token", Address{Name: "Penny", Email: "no-reply@penny.invalid"}, srv.URL)
	id, err := m.Send(context.Background(), Message{
		To: Address{Email: "priya@example.com"}, Subject: "s", Text: "t", HTML: "h",
		Category: LessonReminders, Unsubscribe: "http://localhost:8080/v1/unsubscribe/t",
	})
	if err != nil || id != "pm-123" {
		t.Fatalf("Send = %q, %v", id, err)
	}
	if token != "server-token" || got.Tag != "lesson_reminders" || got.MessageStream != "outbound" || len(got.Headers) != 2 {
		t.Errorf("request = token %q, %+v", token, got)
	}

	failing := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnprocessableEntity)
		_, _ = w.Write([]byte(`{"ErrorCode":300,"Message":"Invalid email request"}`))
	}))
	defer failing.Close()
	if _, err := NewPostmarkMailer("t", Address{Email: "a@b.c"}, failing.URL).Send(context.Background(), Message{To: Address{Email: "x"}}); err == nil {
		t.Error("Send succeeded against a failing provider")
	}
}
