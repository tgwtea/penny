# Penny

Penny handles the admin side of tutoring for solo tutors and small studios: who teaches whom, when and where, who has paid, and who needs a reminder. It generates PayNow payment links and records payments and receipts. It never moves money.

> **Status:** see the [build plan](docs/architecture.md#component-by-component-build-plan) for which phases are done. Sign-in works against the local Firebase Auth emulator; [`docs/runbooks/firebase-auth-setup.md`](docs/runbooks/firebase-auth-setup.md) moves an environment to a real Firebase project.

## Repository map

| Path | What lives there | Phase |
| --- | --- | --- |
| `api/` | `openapi.yaml`, the contract between client and server, plus shared test fixtures | 1 |
| `apps/client/` | Flutter app for web, Android, iOS, Windows, macOS and Linux | 2 |
| `packages/penny_api/` | Dart client generated from the contract (never hand-edited) | 2 |
| `packages/penny_ui/` | Design tokens, theme and components | 2 |
| `services/api/` | Go module: `api`, `worker` and `migrate` binaries | 1 |
| `deploy/` | Kustomize manifests that ArgoCD syncs to the cluster | 1 |
| `docs/` | Architecture, decision records (ADRs), runbooks | 0 |
| `tools/` | Code generators (design tokens, Dart client, app icon), client boundary checks, Firebase Auth emulator image, GitHub setup scripts | 0 to 2 |

Only the contract in `api/` crosses between client and server: `apps/` never imports from `services/`, or the reverse.

## Getting started

You need [mise](https://mise.jdx.dev) and Docker. Everything else is pinned in `.mise.toml`.

```sh
mise install          # installs Go, Flutter, task and the CLI tools at pinned versions
task                  # lists every task
task dev              # starts Postgres (PostGIS), Mailpit and the Firebase Auth emulator
task test             # runs every component's tests (components that do not exist yet are skipped)
task lint             # lints workflows and every component
task dev:down         # stops the local stack
task run:api          # migrates the local database and serves the API on :8080
task run:client       # the app on demo data; task run:client:web runs it against the local API
task ui:catalogue     # the design system's Widgetbook catalogue
task test:e2e         # the web client in headless Chrome against the real API (needs Chrome and chromedriver)
```

If another PostgreSQL already listens on 5432, pick another port for Penny's: `export PENNY_POSTGRES_PORT=55432` before `task dev` and every other task.

Local services once `task dev` is running:

| Service | Address |
| --- | --- |
| PostgreSQL 18 + PostGIS | `postgres://penny:penny@localhost:5432/penny` (port from `PENNY_POSTGRES_PORT`) |
| Penny API (`task run:api`) | http://localhost:8080, metrics on http://localhost:9090/metrics |
| Mailpit (catches all outgoing email) | UI at http://localhost:8025, SMTP on `localhost:1025` |
| Firebase Auth emulator | `localhost:9099`, emulator UI at http://localhost:4000: accounts, and the verification and reset emails it "sent" |

## Documentation

- [Architecture and build plan](docs/architecture.md)
- [Architecture decision records](docs/adr/)
- [Deployment](deploy/README.md) and [runbooks](docs/runbooks/)
- [Contributing: branches, commits, pull requests](CONTRIBUTING.md)
- [Rules for coding agents](AGENTS.md)
- [Design principles](DESIGN.md)

## Licence

Not yet chosen. Until a licence is added, all rights are reserved by the author.
