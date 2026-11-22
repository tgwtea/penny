package notify

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"mime"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/mail"
	"strings"
	"testing"
	"time"
)

func paymentRequestEmail() PaymentEmail {
	return PaymentEmail{
		ContactName: "Priya", StudentFirstName: "Arjun", TeamName: "Koh Guitar Studio", PayeeName: "Mei Lin Tan",
		Amount: "S$ 138.90", Reference: "PNY-7K3Q9X", DueDate: "Thursday 26 November",
		Lines: []PaymentEmailLine{
			{Description: "Guitar, Grade 5, Tue 10 Nov 2026", Amount: "S$ 60.00"},
			{Description: "Guitar, Grade 5, Tue 17 Nov 2026 (missed)", Amount: "S$ 60.00"},
			{Description: "Grade 5 theory book", Amount: "S$ 18.90"},
		},
		Note: "Thank you for a lovely term.", PayURL: "http://localhost:5173/pay/token", CoTaught: true,
		Policy: "Cancel at least 24 hours before the lesson. Missed lessons are charged; late cancellations are not.",
	}
}

func TestPaymentEmails(t *testing.T) {
	reminder := paymentRequestEmail()
	reminder.UnsubscribeURL, reminder.UnsubscribeText = "http://localhost:5173/unsubscribe/token", "Stop payment reminders"
	for _, c := range []struct {
		template, subject string
		data              any
	}{
		{"payment_request", "Payment request from Mei Lin Tan: S$ 138.90 for Arjun's lessons", paymentRequestEmail()},
		{"payment_reminder", "Reminder: S$ 138.90 for Arjun's lessons was due Thursday 26 November", reminder},
		{"payer_confirmed", "Arjun's parent says they paid PNY-7K3Q9X", PayerConfirmedEmail{
			PayeeName: "Mei", StudentFirstName: "Arjun", TeamName: "Koh Guitar Studio", Amount: "S$ 138.90",
			Reference: "PNY-7K3Q9X", RequestURL: "http://localhost:5173/payments/id",
		}},
		{"receipt", "Receipt R-0042 from Mei Lin Tan: S$ 138.90", ReceiptEmail{
			ContactName: "Priya", StudentFirstName: "Arjun", TeamName: "Koh Guitar Studio", PayeeName: "Mei Lin Tan",
			Number: "R-0042", Amount: "S$ 138.90", PaidOn: "Thursday 19 November 2026", Reference: "PNY-7K3Q9X",
			Replaces: "R-0041", SHA256: strings.Repeat("ab", 32),
		}},
	} {
		r, err := render(c.template, c.data)
		if err != nil {
			t.Fatal(err)
		}
		if r.Subject != c.subject {
			t.Errorf("%s subject = %q", c.template, r.Subject)
		}
		golden(t, c.template+".txt", r.Text)
		golden(t, c.template+".html", r.HTML)
	}
}

func TestPayeeHearsWhenBothHaveConfirmed(t *testing.T) {
	r, err := render("payer_confirmed", PayerConfirmedEmail{
		PayeeName: "Mei", StudentFirstName: "Arjun", TeamName: "Koh Guitar Studio", Amount: "S$ 138.90",
		Reference: "PNY-7K3Q9X", Closed: true, ReceiptNumber: "R-0042", RequestURL: "http://localhost:5173/payments/id",
	})
	if err != nil {
		t.Fatal(err)
	}
	if r.Subject != "PNY-7K3Q9X is paid" || !strings.Contains(r.Text, "receipt R-0042 is on its way to them") {
		t.Errorf("closed update = %q\n%s", r.Subject, r.Text)
	}
}

func TestMIMEMessageWithAttachment(t *testing.T) {
	pdf := bytes.Repeat([]byte("%PDF-1.4 receipt "), 20)
	msg := Message{
		To: Address{Email: "priya@example.com"}, Subject: "Receipt R-0042", Text: "Hi", HTML: "<p>Hi</p>", Category: Receipts,
		Attachments: []Attachment{{Filename: "Receipt R-0042.pdf", ContentType: "application/pdf", Content: pdf}},
	}
	raw, _, err := buildMIME(Address{Email: "no-reply@penny.invalid"}, msg, time.Date(2026, 11, 19, 8, 20, 0, 0, time.UTC))
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := mail.ReadMessage(bytes.NewReader(raw))
	if err != nil {
		t.Fatal(err)
	}
	mediaType, params, err := mime.ParseMediaType(parsed.Header.Get("Content-Type"))
	if err != nil || mediaType != "multipart/mixed" {
		t.Fatalf("Content-Type = %q, %v", parsed.Header.Get("Content-Type"), err)
	}
	parts := multipart.NewReader(parsed.Body, params["boundary"])
	var types []string
	var attached []byte
	for {
		p, err := parts.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
		types = append(types, strings.Split(p.Header.Get("Content-Type"), ";")[0])
		if p.FileName() == "Receipt R-0042.pdf" {
			encoded, _ := io.ReadAll(p)
			attached, err = base64.StdEncoding.DecodeString(strings.ReplaceAll(string(encoded), "\r\n", ""))
			if err != nil {
				t.Fatal(err)
			}
		}
	}
	if strings.Join(types, ",") != "multipart/alternative,application/pdf" || !bytes.Equal(attached, pdf) {
		t.Errorf("parts = %v, attachment intact = %v", types, bytes.Equal(attached, pdf))
	}
}

func TestPostmarkSendsAttachments(t *testing.T) {
	var got postmarkMessage
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &got)
		_, _ = w.Write([]byte(`{"ErrorCode":0,"Message":"OK","MessageID":"pm-1"}`))
	}))
	defer srv.Close()
	m := NewPostmarkMailer("t", Address{Email: "no-reply@penny.invalid"}, srv.URL)
	if _, err := m.Send(context.Background(), Message{
		To: Address{Email: "priya@example.com"}, Category: Receipts,
		Attachments: []Attachment{{Filename: "Receipt R-0042.pdf", ContentType: "application/pdf", Content: []byte("%PDF")}},
	}); err != nil {
		t.Fatal(err)
	}
	if len(got.Attachments) != 1 || got.Attachments[0].Content != base64.StdEncoding.EncodeToString([]byte("%PDF")) || got.Attachments[0].ContentType != "application/pdf" {
		t.Errorf("attachments = %+v", got.Attachments)
	}
}

func TestFamilyInvitationsSayWhatTheyAreFor(t *testing.T) {
	for role, want := range map[string]string{
		"parent":  "as a parent, so you can follow your children's lessons and payments on Penny.",
		"student": "as a student, so you can see your lessons and what to work on.",
	} {
		r, err := render("member_invitation", Invitation{
			InviteeName: "Priya", InviterName: "Daniel Koh", TeamName: "Koh Guitar Studio", Role: role,
			Email: "priya@example.com", SignInURL: "http://localhost:5173/sign-in",
		})
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(r.Text, want) || !strings.Contains(r.HTML, want) {
			t.Errorf("%s invitation lacks %q:\n%s", role, want, r.Text)
		}
	}
}
