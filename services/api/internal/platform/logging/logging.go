// Package logging builds the process logger: log/slog, JSON in every shared
// environment, with request-scoped attributes taken from the context.
//
// Privacy rule (docs/architecture.md, "Observability"): log identifiers such
// as request_id, workspace_id and user_id. Never log emails, names, tokens or
// request bodies.
package logging

import (
	"context"
	"io"
	"log/slog"
)

// New returns a logger writing to w in the given format ("json" or "text").
func New(w io.Writer, level slog.Level, format string) *slog.Logger {
	opts := &slog.HandlerOptions{Level: level}
	var h slog.Handler
	if format == "text" {
		h = slog.NewTextHandler(w, opts)
	} else {
		h = slog.NewJSONHandler(w, opts)
	}
	return slog.New(contextHandler{Handler: h})
}

type attrsKey struct{}

// WithAttrs returns a context whose log records carry attrs in addition to
// any added by an outer call. Use it for identifiers that describe the whole
// request, such as its ID or the team it acts on.
func WithAttrs(ctx context.Context, attrs ...slog.Attr) context.Context {
	existing, _ := ctx.Value(attrsKey{}).([]slog.Attr)
	merged := make([]slog.Attr, 0, len(existing)+len(attrs))
	merged = append(merged, existing...)
	merged = append(merged, attrs...)
	return context.WithValue(ctx, attrsKey{}, merged)
}

// contextHandler adds the attributes stored by WithAttrs to every record
// logged with a *Context method (InfoContext, ErrorContext, ...).
type contextHandler struct {
	slog.Handler
}

func (h contextHandler) Handle(ctx context.Context, r slog.Record) error {
	if attrs, ok := ctx.Value(attrsKey{}).([]slog.Attr); ok {
		r.AddAttrs(attrs...)
	}
	return h.Handler.Handle(ctx, r)
}

func (h contextHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return contextHandler{Handler: h.Handler.WithAttrs(attrs)}
}

func (h contextHandler) WithGroup(name string) slog.Handler {
	return contextHandler{Handler: h.Handler.WithGroup(name)}
}
