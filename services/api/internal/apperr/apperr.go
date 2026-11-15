// Package apperr defines the errors services return to say why a request
// cannot be served. The HTTP layer maps each kind to one problem type
// (internal/httpapi/problem.go); services never think about status codes.
//
// Return a kind directly when there is nothing to add:
//
//	return apperr.ErrNotFound
//
// or wrap it with a sentence that is safe to show to the person making the
// request (it ends up in the problem's detail):
//
//	return apperr.New(apperr.ErrConflict, "This lesson was changed by someone else. Reload it and try again.")
//
// Any other error is treated as a bug: it is logged and the client sees a
// generic 500 with no detail.
package apperr

import "errors"

// The kinds of failure a service can report.
var (
	ErrValidation         = errors.New("validation failed")
	ErrUnauthenticated    = errors.New("unauthenticated")
	ErrForbidden          = errors.New("forbidden")
	ErrNotFound           = errors.New("not found")
	ErrConflict           = errors.New("conflict")
	ErrPreconditionFailed = errors.New("precondition failed")
)

// Error is a kind plus a detail written for the person making the request.
type Error struct {
	Kind   error
	Detail string
}

// New returns an Error of kind with a client-facing detail.
func New(kind error, detail string) *Error {
	return &Error{Kind: kind, Detail: detail}
}

func (e *Error) Error() string {
	if e.Detail == "" {
		return e.Kind.Error()
	}
	return e.Kind.Error() + ": " + e.Detail
}

func (e *Error) Unwrap() error {
	return e.Kind
}
