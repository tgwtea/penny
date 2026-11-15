# ADR 001: One monorepo with path-filtered CI

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Penny has a Flutter client, a Go service, an API contract and deployment manifests that change together. Separate repositories would turn one contract change into three coordinated pull requests.

## Decision

Keep everything in one repository. CI runs each component's jobs only when its paths change, and a single `ci-ok` job is the required check.

## Consequences

One PR can change the contract, the server and the client atomically. CI must stay path-aware to keep runs fast. Revisit if a separate team takes ownership of a component.
