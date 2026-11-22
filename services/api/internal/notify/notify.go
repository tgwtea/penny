// Package notify sends Penny's emails (ADR 014): lesson reminders and team
// invitations now, payment reminders and receipts in Phase 8.
//
// Emails go out through the Mailer interface: SMTP to Mailpit locally and
// in CI, a transactional provider over HTTPS elsewhere. They are sent by
// background jobs enqueued in the same transaction as the change that needs
// them (ADR 007), so a lesson is never saved without its reminder. Every
// send is written to email_log with the provider's message ID, and every
// email a contact may stop carries a signed unsubscribe link (RFC 8058).
package notify

import (
	"context"
)

// Category is a kind of email. Contacts may stop the ones Stoppable lists;
// receipts are the record of a payment and always go out.
type Category string

// The categories.
const (
	LessonReminders  Category = "lesson_reminders"
	PaymentReminders Category = "payment_reminders"
	Invitations      Category = "invitations"
	Receipts         Category = "receipts"
	PaymentRequests  Category = "payment_requests"
)

// Stoppable reports whether contacts may unsubscribe from c.
func (c Category) Stoppable() bool {
	return c == LessonReminders || c == PaymentReminders
}

// Message is one email to one person.
type Message struct {
	To       Address
	Subject  string
	Text     string
	HTML     string
	Category Category
	// Unsubscribe is the one-click URL for List-Unsubscribe, for
	// categories a contact may stop.
	Unsubscribe string
}

// Address is a named email address.
type Address struct {
	Name  string
	Email string
}

// Mailer sends email. It returns the provider's ID for the message, to
// look it up when someone says it never arrived.
type Mailer interface {
	Send(ctx context.Context, m Message) (providerMessageID string, err error)
	// Name is the provider, as email_log records it.
	Name() string
}
