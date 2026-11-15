# ADR 012: Swappable client backend

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The client must run against in-memory demo data for walkthroughs and against the Go server in real use, with identical screens.

## Decision

Screens depend only on domain repository interfaces. `Demo*Repository` and `Http*Repository` implement them; `--dart-define=PENNY_BACKEND=demo|http` selects one at the composition root. A shared contract test suite runs against both.

## Consequences

Demo mode needs no server. Every repository change is made twice, and the contract tests keep the two honest.
