package config

import (
	"log/slog"
	"slices"
	"strings"
	"testing"
	"time"
)

func env(vars map[string]string) LookupFunc {
	return func(key string) (string, bool) {
		v, ok := vars[key]
		return v, ok
	}
}

const testDatabaseURL = "postgres://penny:secret@localhost:5432/penny"

func TestLoadAPIDefaults(t *testing.T) {
	cfg, err := LoadAPI(env(map[string]string{"PENNY_DATABASE_URL": testDatabaseURL}))
	if err != nil {
		t.Fatalf("LoadAPI: %v", err)
	}
	if cfg.HTTPAddr != ":8080" || cfg.AdminAddr != ":9090" {
		t.Errorf("addresses = %q, %q; want :8080, :9090", cfg.HTTPAddr, cfg.AdminAddr)
	}
	if cfg.ShutdownTimeout != 20*time.Second {
		t.Errorf("ShutdownTimeout = %v, want 20s", cfg.ShutdownTimeout)
	}
	if cfg.Log.Level != slog.LevelInfo || cfg.Log.Format != "json" {
		t.Errorf("Log = %+v, want info/json", cfg.Log)
	}
	if cfg.CORSOrigins != nil {
		t.Errorf("CORSOrigins = %v, want none", cfg.CORSOrigins)
	}
}

func TestLoadAPIReadsEveryVariable(t *testing.T) {
	cfg, err := LoadAPI(env(map[string]string{
		"PENNY_HTTP_ADDR":        "127.0.0.1:8000",
		"PENNY_ADMIN_ADDR":       ":9100",
		"PENNY_DATABASE_URL":     testDatabaseURL,
		"PENNY_CORS_ORIGINS":     "https://app.example.com/, http://localhost:5173",
		"PENNY_SHUTDOWN_TIMEOUT": "5s",
		"PENNY_LOG_LEVEL":        "debug",
		"PENNY_LOG_FORMAT":       "TEXT",
	}))
	if err != nil {
		t.Fatalf("LoadAPI: %v", err)
	}
	want := []string{"https://app.example.com", "http://localhost:5173"}
	if !slices.Equal(cfg.CORSOrigins, want) {
		t.Errorf("CORSOrigins = %v, want %v", cfg.CORSOrigins, want)
	}
	if cfg.HTTPAddr != "127.0.0.1:8000" || cfg.AdminAddr != ":9100" {
		t.Errorf("addresses = %q, %q", cfg.HTTPAddr, cfg.AdminAddr)
	}
	if cfg.ShutdownTimeout != 5*time.Second {
		t.Errorf("ShutdownTimeout = %v, want 5s", cfg.ShutdownTimeout)
	}
	if cfg.Log.Level != slog.LevelDebug || cfg.Log.Format != "text" {
		t.Errorf("Log = %+v, want debug/text", cfg.Log)
	}
}

func TestLoadAPIRejectsBadValues(t *testing.T) {
	tests := []struct {
		name    string
		vars    map[string]string
		wantErr string
	}{
		{
			name:    "missing database URL",
			vars:    map[string]string{},
			wantErr: "PENNY_DATABASE_URL: is required",
		},
		{
			name:    "database URL with the wrong scheme",
			vars:    map[string]string{"PENNY_DATABASE_URL": "mysql://u:p@h/db"},
			wantErr: "PENNY_DATABASE_URL: must be a postgres:// URL",
		},
		{
			name:    "bad duration",
			vars:    map[string]string{"PENNY_DATABASE_URL": testDatabaseURL, "PENNY_SHUTDOWN_TIMEOUT": "soon"},
			wantErr: "PENNY_SHUTDOWN_TIMEOUT",
		},
		{
			name:    "bad log level",
			vars:    map[string]string{"PENNY_DATABASE_URL": testDatabaseURL, "PENNY_LOG_LEVEL": "loud"},
			wantErr: "PENNY_LOG_LEVEL",
		},
		{
			name:    "bad log format",
			vars:    map[string]string{"PENNY_DATABASE_URL": testDatabaseURL, "PENNY_LOG_FORMAT": "xml"},
			wantErr: "PENNY_LOG_FORMAT",
		},
		{
			name:    "address without a port",
			vars:    map[string]string{"PENNY_DATABASE_URL": testDatabaseURL, "PENNY_HTTP_ADDR": "localhost"},
			wantErr: "PENNY_HTTP_ADDR",
		},
		{
			name:    "same address twice",
			vars:    map[string]string{"PENNY_DATABASE_URL": testDatabaseURL, "PENNY_ADMIN_ADDR": ":8080"},
			wantErr: "must differ from PENNY_HTTP_ADDR",
		},
		{
			name:    "wildcard origin",
			vars:    map[string]string{"PENNY_DATABASE_URL": testDatabaseURL, "PENNY_CORS_ORIGINS": "*"},
			wantErr: "PENNY_CORS_ORIGINS",
		},
		{
			name:    "origin with a path",
			vars:    map[string]string{"PENNY_DATABASE_URL": testDatabaseURL, "PENNY_CORS_ORIGINS": "https://app.example.com/login"},
			wantErr: "PENNY_CORS_ORIGINS",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := LoadAPI(env(tt.vars))
			if err == nil {
				t.Fatalf("LoadAPI succeeded, want error containing %q", tt.wantErr)
			}
			if !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("error = %q, want it to contain %q", err, tt.wantErr)
			}
		})
	}
}

func TestLoadAPIReportsEveryProblemAtOnce(t *testing.T) {
	_, err := LoadAPI(env(map[string]string{"PENNY_LOG_LEVEL": "loud", "PENNY_LOG_FORMAT": "xml"}))
	if err == nil {
		t.Fatal("LoadAPI succeeded, want error")
	}
	for _, key := range []string{"PENNY_DATABASE_URL", "PENNY_LOG_LEVEL", "PENNY_LOG_FORMAT"} {
		if !strings.Contains(err.Error(), key) {
			t.Errorf("error %q does not mention %s", err, key)
		}
	}
}

func TestDatabaseURLErrorNeverEchoesTheValue(t *testing.T) {
	_, err := LoadAPI(env(map[string]string{"PENNY_DATABASE_URL": "mysql://user:hunter2@host/db"}))
	if err == nil || strings.Contains(err.Error(), "hunter2") {
		t.Fatalf("error = %v; want an error that does not contain the password", err)
	}
}

func TestLoadMigrate(t *testing.T) {
	cfg, err := LoadMigrate(env(map[string]string{"PENNY_DATABASE_URL": testDatabaseURL}))
	if err != nil {
		t.Fatalf("LoadMigrate: %v", err)
	}
	if cfg.DatabaseURL != testDatabaseURL {
		t.Errorf("DatabaseURL = %q", cfg.DatabaseURL)
	}
	if _, err := LoadMigrate(env(map[string]string{})); err == nil {
		t.Error("LoadMigrate without PENNY_DATABASE_URL succeeded, want error")
	}
}
