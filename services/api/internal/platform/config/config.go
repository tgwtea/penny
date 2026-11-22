package config

import (
	"log/slog"
	"net/mail"
	"net/netip"
	"strings"
	"time"
)

// Log configures structured logging.
type Log struct {
	Level  slog.Level // PENNY_LOG_LEVEL: debug, info (default), warn, error
	Format string     // PENNY_LOG_FORMAT: json (default) or text
}

// API configures the HTTP server binary.
type API struct {
	// HTTPAddr serves the public API (PENNY_HTTP_ADDR, default :8080).
	HTTPAddr string
	// AdminAddr serves /metrics for Prometheus only. It is never routed
	// through the ingress (PENNY_ADMIN_ADDR, default :9090).
	AdminAddr string
	// DatabaseURL is the app role's connection string (PENNY_DATABASE_URL).
	DatabaseURL string
	// CORSOrigins are the browser origins allowed to call the API, such as
	// the web client's https://app.<domain> (PENNY_CORS_ORIGINS, comma
	// separated). Empty means no cross-origin access.
	CORSOrigins []string
	// ShutdownTimeout bounds how long in-flight requests may take to finish
	// after SIGTERM (PENNY_SHUTDOWN_TIMEOUT, default 20s).
	ShutdownTimeout time.Duration
	// PublicURL is the API's address as browsers and calendar apps reach it,
	// such as https://api.example.com, for links the API hands out
	// (PENNY_PUBLIC_URL, default http://localhost:8080).
	PublicURL string
	// AppURL is the web client's address, for links back to the app
	// (PENNY_APP_URL, default http://localhost:5173).
	AppURL string
	// UnsubscribeSecret signs the unsubscribe links in emails
	// (PENNY_UNSUBSCRIBE_SECRET, required, at least 32 characters). The
	// API checks them; the worker signs them. Both need the same value.
	UnsubscribeSecret string
	// TrustedProxies are the ingress's addresses, whose X-Forwarded-For
	// names the client for rate limits (PENNY_TRUSTED_PROXIES, comma-
	// separated CIDRs such as 10.42.0.0/16). Empty trusts no proxy.
	TrustedProxies []netip.Prefix
	Firebase       Firebase
	Log            Log
}

// Mail configures how the worker sends email (ADR 014).
type Mail struct {
	// Provider is smtp (Mailpit locally and in CI) or postmark
	// (PENNY_MAIL_PROVIDER, default smtp).
	Provider string
	// FromName and FromEmail are the sender (PENNY_MAIL_FROM, such as
	// "Penny <reminders@example.com>").
	FromName  string
	FromEmail string
	// SMTPAddr is host:port of the SMTP server (PENNY_SMTP_ADDR, default
	// localhost:1025, Mailpit). PENNY_SMTP_USERNAME and PENNY_SMTP_PASSWORD
	// are optional.
	SMTPAddr     string
	SMTPUsername string
	SMTPPassword string
	// PostmarkToken is the server token (PENNY_POSTMARK_TOKEN, required for
	// postmark).
	PostmarkToken string
}

// Worker configures the background job binary.
type Worker struct {
	// AdminAddr serves /metrics and the health probes (PENNY_ADMIN_ADDR,
	// default :9091, so it can run beside the API locally).
	AdminAddr string
	// DatabaseURL is the app role's connection string (PENNY_DATABASE_URL).
	DatabaseURL string
	// PublicURL is the API's public address, for links in emails
	// (PENNY_PUBLIC_URL, default http://localhost:8080).
	PublicURL string
	// AppURL is the web client's address (PENNY_APP_URL).
	AppURL string
	// UnsubscribeSecret signs unsubscribe links (PENNY_UNSUBSCRIBE_SECRET).
	UnsubscribeSecret string
	Mail              Mail
	// ShutdownTimeout bounds how long running jobs get to finish after
	// SIGTERM before they are released to run again (PENNY_SHUTDOWN_TIMEOUT,
	// default 30s).
	ShutdownTimeout time.Duration
	Log             Log
}

// Firebase configures how bearer tokens are verified (ADR 004).
type Firebase struct {
	// ProjectID is the Firebase project whose ID tokens are accepted
	// (PENNY_FIREBASE_PROJECT_ID, required).
	ProjectID string
	// AuthEmulatorHost is the host:port of the Firebase Auth emulator
	// (PENNY_FIREBASE_AUTH_EMULATOR_HOST). Set only locally and in CI:
	// the API then accepts the emulator's unsigned tokens, so the project
	// ID must be a demo- project, which cannot exist outside the emulator.
	AuthEmulatorHost string
}

// UsesEmulator reports whether tokens come from the Auth emulator.
func (f Firebase) UsesEmulator() bool { return f.AuthEmulatorHost != "" }

// Migrate configures the schema migration binary.
type Migrate struct {
	// DatabaseURL is the migrator role's connection string, which holds DDL
	// rights the app role does not (PENNY_DATABASE_URL).
	DatabaseURL string
	Log         Log
}

// LoadAPI reads the API server's configuration.
func LoadAPI(lookup LookupFunc) (API, error) {
	r := newReader(lookup)
	cfg := API{
		HTTPAddr:          r.listenAddr("PENNY_HTTP_ADDR", ":8080"),
		AdminAddr:         r.listenAddr("PENNY_ADMIN_ADDR", ":9090"),
		DatabaseURL:       r.databaseURL("PENNY_DATABASE_URL"),
		CORSOrigins:       r.origins("PENNY_CORS_ORIGINS"),
		ShutdownTimeout:   r.duration("PENNY_SHUTDOWN_TIMEOUT", 20*time.Second),
		PublicURL:         r.publicURL("PENNY_PUBLIC_URL", defaultPublicURL),
		AppURL:            r.publicURL("PENNY_APP_URL", defaultAppURL),
		UnsubscribeSecret: r.secret("PENNY_UNSUBSCRIBE_SECRET", 32),
		TrustedProxies:    r.prefixes("PENNY_TRUSTED_PROXIES"),
		Firebase:          readFirebase(r),
		Log:               readLog(r),
	}
	if cfg.HTTPAddr == cfg.AdminAddr {
		r.fail("PENNY_ADMIN_ADDR", "must differ from PENNY_HTTP_ADDR")
	}
	return cfg, r.err()
}

// defaultPublicURL is the API under `task run:api`, and defaultAppURL the
// web client under `task run:client:web`.
const (
	defaultPublicURL = "http://localhost:8080"
	defaultAppURL    = "http://localhost:5173"
)

// LoadWorker reads the worker binary's configuration.
func LoadWorker(lookup LookupFunc) (Worker, error) {
	r := newReader(lookup)
	cfg := Worker{
		AdminAddr:         r.listenAddr("PENNY_ADMIN_ADDR", ":9091"),
		DatabaseURL:       r.databaseURL("PENNY_DATABASE_URL"),
		PublicURL:         r.publicURL("PENNY_PUBLIC_URL", defaultPublicURL),
		AppURL:            r.publicURL("PENNY_APP_URL", defaultAppURL),
		UnsubscribeSecret: r.secret("PENNY_UNSUBSCRIBE_SECRET", 32),
		Mail:              readMail(r),
		ShutdownTimeout:   r.duration("PENNY_SHUTDOWN_TIMEOUT", 30*time.Second),
		Log:               readLog(r),
	}
	return cfg, r.err()
}

func readMail(r *reader) Mail {
	m := Mail{
		Provider:      r.oneOf("PENNY_MAIL_PROVIDER", "smtp", "smtp", "postmark"),
		SMTPAddr:      r.string("PENNY_SMTP_ADDR", "localhost:1025"),
		SMTPUsername:  r.value("PENNY_SMTP_USERNAME"),
		SMTPPassword:  r.value("PENNY_SMTP_PASSWORD"),
		PostmarkToken: r.value("PENNY_POSTMARK_TOKEN"),
	}
	from, err := mail.ParseAddress(r.string("PENNY_MAIL_FROM", "Penny <no-reply@penny.invalid>"))
	if err != nil {
		r.fail("PENNY_MAIL_FROM", "must be an address such as \"Penny <reminders@example.com>\"")
	} else {
		m.FromName, m.FromEmail = from.Name, from.Address
	}
	if m.Provider == "postmark" && m.PostmarkToken == "" {
		r.fail("PENNY_POSTMARK_TOKEN", "is required when PENNY_MAIL_PROVIDER is postmark")
	}
	return m
}

// LoadMigrate reads the migrate binary's configuration.
func LoadMigrate(lookup LookupFunc) (Migrate, error) {
	r := newReader(lookup)
	cfg := Migrate{
		DatabaseURL: r.databaseURL("PENNY_DATABASE_URL"),
		Log:         readLog(r),
	}
	return cfg, r.err()
}

func readFirebase(r *reader) Firebase {
	f := Firebase{
		ProjectID:        r.required("PENNY_FIREBASE_PROJECT_ID"),
		AuthEmulatorHost: r.value("PENNY_FIREBASE_AUTH_EMULATOR_HOST"),
	}
	if f.UsesEmulator() && f.ProjectID != "" && !strings.HasPrefix(f.ProjectID, "demo-") {
		r.fail("PENNY_FIREBASE_AUTH_EMULATOR_HOST",
			"may only be set with a demo- project ID; the emulator's tokens are unsigned")
	}
	return f
}

func readLog(r *reader) Log {
	return Log{
		Level:  r.logLevel("PENNY_LOG_LEVEL", slog.LevelInfo),
		Format: r.oneOf("PENNY_LOG_FORMAT", "json", "json", "text"),
	}
}
