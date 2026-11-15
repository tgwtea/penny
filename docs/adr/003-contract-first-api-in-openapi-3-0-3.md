# ADR 003: Contract-first API in OpenAPI 3.0.3

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The client and server must agree on every request and response, and the client must be able to run against a demo backend with the same shapes.

## Decision

`api/openapi.yaml` is written by hand first. Go server stubs (oapi-codegen strict server) and the Dart client are generated from it and committed. CI fails on stale generated code and on unannounced breaking changes (`oasdiff`). Use 3.0.3 until Go and Dart generators fully support 3.1.

## Consequences

Contract changes are visible and reviewable. Generators constrain some schema idioms. Moving to 3.1 later is mechanical.
