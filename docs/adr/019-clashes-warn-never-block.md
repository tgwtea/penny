# ADR 019: Clashes warn, never block

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Studios sometimes double-book on purpose, for example overlapping trial lessons.

## Decision

A tutor or student on two overlapping non-cancelled lessons is flagged as a clash in the UI and API. Nothing prevents saving it. The detection rule is shared by the Go and Dart implementations through fixtures in `api/fixtures/clashes/`.

## Consequences

No database exclusion constraint. Owners see clashes and decide.
