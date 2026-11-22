# api

The contract between the Flutter client and the Go server (ADR 003).

| File | What it is |
| --- | --- |
| `openapi.yaml` | The contract, OpenAPI 3.0.3, written by hand. The single source of truth |
| `.spectral.yaml` | Lint rules: Spectral's OpenAPI rules plus Penny's conventions |
| `fixtures/` | JSON test cases both the Go and Dart suites read: `clashes/` (ADR 019) and `paynow/` (the QR payloads Penny encodes) |
| `accepted-breaking-changes.txt` | Breaking changes made on purpose, one oasdiff message per line, so `task lint:contract` lets them through. Each needs a reason in the PR and, usually, an ADR |

## Changing the contract

1. Edit `openapi.yaml`.
2. `task lint:contract` checks conventions and, against `main`, flags breaking changes. A breaking change made on purpose goes in `accepted-breaking-changes.txt`, copied from oasdiff's message, with its reason in the PR; remove the lines once `main` has the change.
3. `task gen` regenerates the Go server (`services/api/internal/httpapi/gen`) and the Dart client (`packages/penny_api`). Commit the output in the same change; CI fails if it is stale.

## Conventions

- Every path except `/livez` and `/readyz` is under `/v1`. Team-scoped resources live under `/v1/workspaces/{workspaceId}/...`.
- JSON property names are camelCase; enum values are snake_case.
- Errors are RFC 9457 `application/problem+json` through the shared `Problem` response. Clients branch on `type` (for example `urn:penny:problem:not-found`), never on `title` or `detail`.
- Timestamps are RFC 3339 in UTC. Money is integer cents plus an ISO 4217 currency code.
- Every operation has an `operationId` and a tag: they become method and class names in both generated clients.
