# ADR 002: Modular monolith: one Go module, api and worker binaries

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Expected scale is tens of teams and a few thousand lessons a month. Microservices would add network calls, deployments and failure modes with no scaling benefit.

## Decision

One Go module with one package per business capability (identity, workspace, authz, scheduling, billing, notify, audit). It builds `api`, `worker` and `migrate` binaries. Modules talk through exported service interfaces or jobs enqueued in the same transaction, never by reading each other's tables.

## Consequences

Simple to run and debug. Module boundaries are enforced by convention and `depguard`, not by the network, so they need review discipline. Revisit if one module needs independent scaling or release cadence.
