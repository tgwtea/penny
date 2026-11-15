package config

import (
	"log/slog"
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
	Log             Log
}

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
		HTTPAddr:        r.listenAddr("PENNY_HTTP_ADDR", ":8080"),
		AdminAddr:       r.listenAddr("PENNY_ADMIN_ADDR", ":9090"),
		DatabaseURL:     r.databaseURL("PENNY_DATABASE_URL"),
		CORSOrigins:     r.origins("PENNY_CORS_ORIGINS"),
		ShutdownTimeout: r.duration("PENNY_SHUTDOWN_TIMEOUT", 20*time.Second),
		Log:             readLog(r),
	}
	if cfg.HTTPAddr == cfg.AdminAddr {
		r.fail("PENNY_ADMIN_ADDR", "must differ from PENNY_HTTP_ADDR")
	}
	return cfg, r.err()
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

func readLog(r *reader) Log {
	return Log{
		Level:  r.logLevel("PENNY_LOG_LEVEL", slog.LevelInfo),
		Format: r.oneOf("PENNY_LOG_FORMAT", "json", "json", "text"),
	}
}
