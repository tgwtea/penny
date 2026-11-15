// Package db holds the database schema as embedded goose migrations.
//
// Migrations are plain SQL, numbered, and forward-only (ADR 006): a file is
// never edited once merged, and a mistake is fixed by a new migration. Each
// file has an Up section only.
package db

import "embed"

// Migrations contains every file in migrations/, applied in numeric order.
//
//go:embed migrations/*.sql
var Migrations embed.FS

// MigrationsDir is the directory inside Migrations that holds the files.
const MigrationsDir = "migrations"
