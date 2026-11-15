# ADR 005: pgx and sqlc for data access

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Tenancy scoping and row locking (receipt numbering) need explicit, reviewable SQL.

## Decision

Write SQL in `services/api/db/queries`, generate typed Go with sqlc, execute with pgx v5. No ORM.

## Consequences

Queries are visible in review and checked at generate time. Dynamic queries need care. Unlikely to revisit.
