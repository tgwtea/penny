// Package database opens the pgx connection pool shared by a process.
package database

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/tgwtea/penny/services/api/internal/platform/health"
)

// Open creates a connection pool. It does not connect: the first query or
// Ping does. That keeps the API serving /livez during a database outage, while
// /readyz reports it.
//
// Settings missing from url, such as the user and password, are read from the
// standard libpq variables (PGUSER, PGPASSWORD, ...), which is how the cluster
// supplies credentials without putting them in a URL.
func Open(ctx context.Context, url, applicationName string) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		// pgx errors can quote the connection string; never pass them on.
		return nil, fmt.Errorf("parse database URL: invalid connection settings")
	}
	if cfg.ConnConfig.RuntimeParams == nil {
		cfg.ConnConfig.RuntimeParams = map[string]string{}
	}
	cfg.ConnConfig.RuntimeParams["application_name"] = applicationName
	// Penny stores every timestamp as timestamptz in UTC; make the session
	// agree so any text rendering of a time is in UTC too.
	cfg.ConnConfig.RuntimeParams["timezone"] = "UTC"

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("create database pool: %w", err)
	}
	return pool, nil
}

// PingCheck reports whether the database accepts connections.
func PingCheck(pool *pgxpool.Pool) health.Check {
	return health.Check{
		Name: "database",
		Run: func(ctx context.Context) error {
			if err := pool.Ping(ctx); err != nil {
				return fmt.Errorf("database is unreachable")
			}
			return nil
		},
	}
}
