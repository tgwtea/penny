package notify

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

// TestSMTPMailerDeliversToMailpit sends a real email through Mailpit (task
// dev) and reads it back from Mailpit's API. It runs when
// PENNY_TEST_MAILPIT_URL (such as http://localhost:8025) is set, with
// PENNY_TEST_SMTP_ADDR (default localhost:1025).
func TestSMTPMailerDeliversToMailpit(t *testing.T) {
	api := os.Getenv("PENNY_TEST_MAILPIT_URL")
	if api == "" {
		t.Skip("set PENNY_TEST_MAILPIT_URL to send through Mailpit")
	}
	addr := os.Getenv("PENNY_TEST_SMTP_ADDR")
	if addr == "" {
		addr = "localhost:1025"
	}
	to := fmt.Sprintf("parent-%d@example.com", time.Now().UnixNano())
	r, err := render("lesson_reminder", reminder())
	if err != nil {
		t.Fatal(err)
	}
	m := NewSMTPMailer(addr, Address{Name: "Koh Guitar Studio", Email: "reminders@penny.invalid"}, "", "", clock.System{})
	if _, err := m.Send(context.Background(), Message{
		To: Address{Name: "Priya Nair", Email: to}, Subject: r.Subject, Text: r.Text, HTML: r.HTML,
		Category: LessonReminders, Unsubscribe: "http://localhost:8080/v1/unsubscribe/token",
	}); err != nil {
		t.Fatal(err)
	}

	var found struct {
		Messages []struct {
			ID      string `json:"ID"`
			Subject string `json:"Subject"`
		} `json:"messages"`
	}
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) && len(found.Messages) == 0 {
		req, _ := http.NewRequestWithContext(context.Background(), http.MethodGet, api+"/api/v1/search?query=to:"+to, nil)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		_ = json.NewDecoder(resp.Body).Decode(&found)
		resp.Body.Close()
		if len(found.Messages) == 0 {
			time.Sleep(200 * time.Millisecond)
		}
	}
	if len(found.Messages) != 1 || found.Messages[0].Subject != r.Subject {
		t.Fatalf("Mailpit has %+v, want the reminder", found.Messages)
	}

	req, _ := http.NewRequestWithContext(context.Background(), http.MethodGet, api+"/api/v1/message/"+found.Messages[0].ID+"/headers", nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var headers map[string][]string
	if err := json.NewDecoder(resp.Body).Decode(&headers); err != nil {
		t.Fatal(err)
	}
	if got := headers["List-Unsubscribe-Post"]; len(got) != 1 || got[0] != "List-Unsubscribe=One-Click" {
		t.Errorf("List-Unsubscribe-Post = %v", got)
	}
}
