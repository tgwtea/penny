# ADR 006: goose migrations, forward-only, run as a pre-deploy Job

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Schema changes must be ordered, repeatable and never raced by several API replicas.

## Decision

Plain SQL migrations with goose, applied by the `migrate` binary as an ArgoCD PreSync Job. Forward-only in shared environments; breaking changes use expand, migrate, contract across releases. A separate `penny_migrator` role holds DDL rights; the app role has DML only.

## Consequences

Rollouts stop on a failed migration. Rollbacks are new forward migrations.
