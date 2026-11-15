# services/api

One Go module building three binaries: `api` (HTTP server), `worker` (River background jobs) and `migrate` (goose and River migrations, run as a Kubernetes Job before each rollout).

Arrives in Phase 1. See `docs/architecture.md`, "Backend (Go)".
