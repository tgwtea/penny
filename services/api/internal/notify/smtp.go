package notify

import (
	"context"
	"fmt"
	"net"
	"net/smtp"
	"time"

	"github.com/tgwtea/penny/services/api/internal/platform/clock"
)

// SMTPMailer sends through an SMTP server: Mailpit locally and in CI. Penny
// never sends real mail over SMTP from the homelab (ADR 014).
type SMTPMailer struct {
	addr  string
	from  Address
	auth  smtp.Auth
	clock clock.Clock
}

// NewSMTPMailer returns a mailer for the server at addr (host:port).
// Without a username it sends unauthenticated, as Mailpit accepts.
func NewSMTPMailer(addr string, from Address, username, password string, c clock.Clock) *SMTPMailer {
	m := &SMTPMailer{addr: addr, from: from, clock: c}
	if username != "" {
		host, _, _ := net.SplitHostPort(addr)
		m.auth = smtp.PlainAuth("", username, password, host)
	}
	return m
}

// Name is "smtp".
func (m *SMTPMailer) Name() string { return "smtp" }

// Send delivers msg.
func (m *SMTPMailer) Send(ctx context.Context, msg Message) (string, error) {
	body, id, err := buildMIME(m.from, msg, m.clock.Now())
	if err != nil {
		return "", fmt.Errorf("build message: %w", err)
	}
	done := make(chan error, 1)
	go func() { done <- smtp.SendMail(m.addr, m.auth, m.from.Email, []string{msg.To.Email}, body) }()
	select {
	case err := <-done:
		if err != nil {
			return "", fmt.Errorf("smtp send: %w", err)
		}
		return id, nil
	case <-ctx.Done():
		return "", ctx.Err()
	case <-time.After(30 * time.Second):
		return "", fmt.Errorf("smtp send: timed out")
	}
}
