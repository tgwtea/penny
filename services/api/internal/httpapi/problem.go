package httpapi

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/tgwtea/penny/services/api/internal/apperr"
	"github.com/tgwtea/penny/services/api/internal/httpapi/gen"
)

// problemKind is one stable problem type in the contract. Clients branch on
// Type; changing one is a breaking change.
type problemKind struct {
	Type   string
	Title  string
	Status int
}

var (
	problemValidation         = problemKind{"urn:penny:problem:validation", "The request is not valid", http.StatusBadRequest}
	problemUnauthenticated    = problemKind{"urn:penny:problem:unauthenticated", "Sign-in required", http.StatusUnauthorized}
	problemForbidden          = problemKind{"urn:penny:problem:forbidden", "Not allowed", http.StatusForbidden}
	problemNotFound           = problemKind{"urn:penny:problem:not-found", "Not found", http.StatusNotFound}
	problemMethodNotAllowed   = problemKind{"urn:penny:problem:method-not-allowed", "Method not allowed", http.StatusMethodNotAllowed}
	problemConflict           = problemKind{"urn:penny:problem:conflict", "Conflict", http.StatusConflict}
	problemPreconditionFailed = problemKind{"urn:penny:problem:precondition-failed", "Changed since you loaded it", http.StatusPreconditionFailed}
	problemInternal           = problemKind{"urn:penny:problem:internal", "Something went wrong on the server", http.StatusInternalServerError}
)

// kindFor maps a service error to its problem kind. This table is the one
// place domain errors become HTTP statuses.
func kindFor(err error) (problemKind, bool) {
	switch {
	case errors.Is(err, apperr.ErrValidation):
		return problemValidation, true
	case errors.Is(err, apperr.ErrUnauthenticated):
		return problemUnauthenticated, true
	case errors.Is(err, apperr.ErrForbidden):
		return problemForbidden, true
	case errors.Is(err, apperr.ErrNotFound):
		return problemNotFound, true
	case errors.Is(err, apperr.ErrConflict):
		return problemConflict, true
	case errors.Is(err, apperr.ErrPreconditionFailed):
		return problemPreconditionFailed, true
	default:
		return problemInternal, false
	}
}

// problemWriter turns errors into RFC 9457 responses.
type problemWriter struct {
	logger *slog.Logger
}

// writeError writes the problem for err. Errors that are not apperr kinds are
// bugs: they are logged in full and the client gets no detail.
func (p problemWriter) writeError(w http.ResponseWriter, r *http.Request, err error) {
	kind, known := kindFor(err)
	if !known {
		p.logger.ErrorContext(r.Context(), "request failed", slog.Any("error", err))
		p.write(w, r, kind, "")
		return
	}
	var detail string
	var appErr *apperr.Error
	if errors.As(err, &appErr) {
		detail = appErr.Detail
	}
	p.write(w, r, kind, detail)
}

// writeDecodeError answers a request the generated code could not decode,
// such as a malformed parameter. Those messages name the parameter and are
// safe to return.
func (p problemWriter) writeDecodeError(w http.ResponseWriter, r *http.Request, err error) {
	p.write(w, r, problemValidation, err.Error())
}

func (p problemWriter) write(w http.ResponseWriter, r *http.Request, kind problemKind, detail string) {
	body := gen.Problem{
		Type:     kind.Type,
		Title:    kind.Title,
		Status:   int32(kind.Status),
		Instance: ptr(r.URL.Path),
	}
	if detail != "" {
		body.Detail = ptr(detail)
	}
	if id := requestIDFrom(r.Context()); id != "" {
		body.RequestId = ptr(id)
	}
	if kind.Status == http.StatusUnauthorized {
		w.Header().Set("WWW-Authenticate", "Bearer")
	}
	w.Header().Set("Content-Type", "application/problem+json")
	w.WriteHeader(kind.Status)
	if err := json.NewEncoder(w).Encode(body); err != nil {
		p.logger.WarnContext(r.Context(), "write problem response", slog.Any("error", err))
	}
}

func ptr[T any](v T) *T {
	return &v
}
