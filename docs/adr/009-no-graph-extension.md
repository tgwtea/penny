# ADR 009: No graph extension

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

A graph extension was proposed for relationships between teams, tutors, students and contacts.

## Decision

Do not adopt Apache AGE or another graph extension. Relationships are shallow and fixed-depth; joins and recursive CTEs cover every planned query.

## Consequences

No custom database image and no coupling of Postgres upgrades to an extension's release cadence. Revisit if a real multi-hop query appears.
