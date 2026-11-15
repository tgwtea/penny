# ADR 007: River for background jobs

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Reminders must be scheduled atomically with the change that causes them, and the homelab should not run another stateful service.

## Decision

Use River, a Postgres-backed job queue, with jobs inserted in the same transaction as the data change.

## Consequences

No Redis or broker to operate or back up; job state is in the same backups. Revisit if job throughput strains the database.
