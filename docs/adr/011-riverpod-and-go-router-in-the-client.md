# ADR 011: Riverpod and go_router in the client

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The client needs dependency injection, testable state and route guards driven by permissions.

## Decision

Use Riverpod for state and dependency injection, go_router for navigation, with feature-first folders and four layers (presentation, application, domain, data).

## Consequences

Riverpod provider overrides double as the mechanism that swaps the demo backend for the HTTP backend (ADR 012).
