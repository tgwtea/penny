# services/api

One Go module (ADR 002). Today it builds two binaries; `worker` joins them when background jobs arrive (Phase 7).

| Binary | What it does |
| --- | --- |
| `cmd/api` | Serves the contract in `api/openapi.yaml` on `:8080` and Prometheus metrics on `:9090` |
| `cmd/migrate` | Applies goose and River migrations. Runs as a Kubernetes Job before each rollout (ADR 006) |

## Layout

```text
cmd/api, cmd/migrate   entry points: read config, wire dependencies, run
db/migrations/         goose SQL, numbered, forward-only, embedded into the binaries
internal/apperr/       the errors services return (not found, forbidden, conflict, ...)
internal/httpapi/      generated server (gen/), thin handlers, middleware, problem mapping
internal/platform/     config, logging, database pool, health checks, metrics, tracing,
                       HTTP server, schema migrations, test databases
```

Business modules (`identity`, `workspace`, `authz`, `scheduling`, ...) arrive with the phases that need them. Each has a service (use cases, transactions, the `authz` check) and a store (SQL, always scoped by `workspace_id`). Handlers in `httpapi` call services and never touch SQL; `golangci-lint`'s `depguard` enforces that.

## Running locally

From the repository root, with the local stack up (`task dev`):

```sh
task run:api          # applies migrations, then serves on http://localhost:8080
curl localhost:8080/readyz
```

## Configuration

Environment variables only; the process exits at startup if any is invalid, listing every problem.

| Variable | Default | Meaning |
| --- | --- | --- |
| `PENNY_DATABASE_URL` | required | `postgres://` URL. User and password may come from `PGUSER` and `PGPASSWORD` instead |
| `PENNY_HTTP_ADDR` | `:8080` | API listener (api only) |
| `PENNY_ADMIN_ADDR` | `:9090` | `/metrics` listener, never exposed through the ingress (api only) |
| `PENNY_CORS_ORIGINS` | none | Comma-separated browser origins allowed to call the API, such as the web client (api only) |
| `PENNY_SHUTDOWN_TIMEOUT` | `20s` | How long in-flight requests get after SIGTERM (api only) |
| `PENNY_LOG_LEVEL` | `info` | `debug`, `info`, `warn` or `error` |
| `PENNY_LOG_FORMAT` | `json` | `json` or `text` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | none | Turns on trace export over OTLP/HTTP. Other `OTEL_*` variables work as the SDK documents |

## Errors

Services return `apperr` kinds (`apperr.ErrNotFound`, or `apperr.New(apperr.ErrConflict, "a sentence for the user")`). `internal/httpapi/problem.go` maps each kind to one RFC 9457 problem type; it is the only place that knows status codes. Any other error is a bug: it is logged with the request ID and the client gets a 500 without detail.

## Tests

```sh
task test:api
```

Tests that need PostgreSQL use `internal/platform/pgtest`, which creates an empty database per test and drops it afterwards. They run when `PENNY_TEST_DATABASE_URL` points at a server where the role may create databases, and are skipped otherwise:

```sh
PENNY_TEST_DATABASE_URL=postgres://penny:penny@localhost:5432/penny?sslmode=disable task test:api
```

CI sets the variable and `PENNY_TEST_REQUIRE_DB=1`, which turns the skip into a failure.

## Code generation

`internal/httpapi/gen` is generated from the contract by oapi-codegen, pinned as a Go tool in `go.mod`. Regenerate with `task gen`; never edit it by hand.

## Container image

`Dockerfile` builds one distroless image holding both binaries, so the migrate Job and the API Deployment always run the same build:

```sh
docker build -t penny-api services/api
```
