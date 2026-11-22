// Package notifytest provides a recording Mailer for tests.
package notifytest

import (
	"context"
	"fmt"
	"sync"

	"github.com/tgwtea/penny/services/api/internal/notify"
)

// Mailer keeps every message it is asked to send.
type Mailer struct {
	mu   sync.Mutex
	sent []notify.Message
	// Fail makes every send fail, to test retries.
	Fail bool
	// FailAfter, when positive, lets that many sends through and fails the
	// rest; -1 or 0 turns it off.
	FailAfter int
}

// Name is "test".
func (m *Mailer) Name() string { return "test" }

// Send records msg.
func (m *Mailer) Send(_ context.Context, msg notify.Message) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.Fail || (m.FailAfter > 0 && len(m.sent) >= m.FailAfter) {
		return "", fmt.Errorf("test mailer set to fail")
	}
	m.sent = append(m.sent, msg)
	return fmt.Sprintf("test-%d", len(m.sent)), nil
}

// Sent returns a copy of every message sent so far.
func (m *Mailer) Sent() []notify.Message {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]notify.Message(nil), m.sent...)
}
