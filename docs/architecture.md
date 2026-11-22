# Penny: Architecture and Build Plan

Nov 15, 2026 · @leifsen

## Summary

Penny is a modular monolith: one Go codebase building an `api` and a `worker` binary, one PostgreSQL database run by CloudNativePG on the homelab K3s cluster, and one Flutter client for web, Android, iOS and desktop (Windows, macOS, Linux). A single OpenAPI contract sits between client and server. The client reaches data only through domain repository interfaces, so the in-memory demo backend from the team-timetable PRD and the real Go server swap at one composition root.

Build order: monorepo and CI skeleton, a design system and key screen designs, a deployed walking skeleton, authentication (email/password and Google), teams and roles (owner, teacher, solo), then lessons and the timetable. Email reminders, PayNow payment links and receipts follow. Student and parent roles and encrypted messaging are reserved in the model, not built.

### Decisions (settled 15 Nov 2026)

| # | Decision | Outcome |
| --- | --- | --- |
| D1 | Identity | Firebase Auth handles email/password and Google sign-in; Penny stores no passwords |
| D2 | Graph extension | None for now; revisit only if a real multi-hop query appears |
| D3 | Double-booked tutor | Warn, never block |
| D4 | Lesson size | Any number of students and any number of tutors per lesson, no hard limit |
| D5 | Existing frontend | Not reused. The client is a fresh build on a new design system, designed before it is coded |
| D6 | Email | Transactional provider over HTTPS; never SMTP from the homelab |
| D7 | Co-taught lesson billing | The lead tutor (who created the lesson) bills it and decides the split off-app; Penny records one payee and states that the split is arranged outside the app |

## Goals and scope

Penny handles the admin side of tutoring for solo tutors and small studios: who teaches whom, when, where, who has paid, and who needs reminding. It records payments; it never moves money.

| Capability | In first release | Reserved for later |
| --- | --- | --- |
| Authentication | Email/password and Google sign-in | Other identity providers, SSO |
| Authorization | Owner, teacher, solo tutor (a team of one) | Student, parent |
| Scheduling | Lessons as individual events, recurring series, day/week/month views, team timetable, tasks, goals and notes per lesson, structured locations | Two-way Google Calendar sync, rooms and resources |
| Notifications | Email reminders for lessons and payments | Push notifications, SMS |
| Payments | PayNow QR on a unique link per payment request; payee confirms receipt | Any automated bank reconciliation |
| Receipts | Immutable, numbered, traceable to one payment record | Tax invoices |
| Messaging | None (email covers it) | End-to-end encrypted messaging between two people |

**Scale assumption.** Tens of teams, hundreds of users, a few thousand lessons a month. One Postgres primary with two replicas is ample; nothing here needs sharding, a message broker or a cache tier.

**Quality attributes, in priority order**

1. **Correctness of records.** Lessons, payments and receipts are what tutors argue with parents about. Every change is attributable and receipts are immutable.
2. **Changeability.** Modules with explicit boundaries, a versioned API contract, forward-only migrations, and one place to swap each external dependency (identity, email, storage).
3. **Operability on a homelab.** GitOps-deployed, observable, backed up off-site, and movable to a VPS or managed cluster without rewriting anything.
4. **Privacy.** Students are often minors; collect the minimum and keep personal data out of logs.

**Non-goals.** Processing payments, microservices, multi-region, offline-first sync, real-time collaborative editing.

## System overview

The client reaches one API through one tunnel. Firebase, the email provider, the payer's bank, GitHub and off-site backup storage are the only things Penny depends on but does not run.

(Diagram: see the "Penny: Architecture and Build Plan" doc, https://claude.ai/artifact/1F9jFDUWMpVEDGhxMQL3sv. Inside the homelab K3s cluster: web, api, worker, migrate Job, ArgoCD, PostgreSQL via CloudNativePG, monitoring. Outside: Firebase Auth, the payer's bank app, the email provider, GitHub, off-site backups.)

A request leaves the client with a Firebase ID token, enters through Cloudflare Tunnel and reaches `api`, which checks permissions and writes to Postgres. `worker` takes jobs from the same database and sends email. ArgoCD pulls manifests from GitHub; nothing pushes into the cluster. PayNow moves money from the payer's bank to the teacher without passing through Penny.

## Key architecture decisions

Each row becomes an ADR in `docs/adr/` (one Markdown file per decision: context, decision, consequences). Rows marked D were settled in the Summary.

| ADR | Decision | Chosen | Rejected, and why | Revisit when |
| --- | --- | --- | --- | --- |
| 001 | Repository shape | One monorepo, path-filtered CI | Polyrepo: contract changes would span three PRs | A second team owns a component |
| 002 | Service shape | Modular monolith: `api` + `worker` binaries from one Go module | Microservices: network calls, deploys and failure modes with no scale benefit | One module needs independent scaling or a different release cadence |
| 003 | Contract | OpenAPI 3.0.3 in `api/openapi.yaml`, server and client generated from it | Code-first: the contract drifts silently; gRPC: weak Flutter web story | Tooling for 3.1 matures on both sides |
| 004 | Identity (D1) | Firebase Auth as the identity provider; Penny's own DB owns users, roles and permissions | Roles in Firebase custom claims: cached in tokens for up to an hour and per-team roles do not fit | Firebase cost or lock-in becomes a problem; swap the verifier for a self-hosted OIDC provider |
| 005 | Data access | `pgx` v5 + `sqlc` (SQL in, typed Go out) | ORM: hides queries that matter for tenancy and locking | Never, probably |
| 006 | Migrations | `goose`, plain SQL, forward-only, run as a pre-deploy Kubernetes Job | Auto-migrate on API start: concurrent replicas race |  |
| 007 | Background work | River (Postgres-backed job queue, transactional enqueue) | Redis or NATS: another stateful service to run and back up | Queue throughput exceeds what one Postgres comfortably serves |
| 008 | Database operator | CloudNativePG, 3 instances, local storage, off-site object-store backups | Hand-rolled StatefulSet: you rebuild failover and backups |  |
| 009 | Graph extension (D2) | None. Relational tables, recursive CTEs where needed | Apache AGE: custom image, upgrade coupling, no query that needs it | A real multi-hop query appears (for example, referral networks) |
| 010 | Location data | PostGIS available from day one; geography column on locations | Bare lat/lng: fine now, painful for distance queries later |  |
| 011 | Client state and routing | Riverpod + go\_router, feature-first folders, four layers | Bloc: equally valid; Riverpod's provider overrides double as the backend-swap mechanism |  |
| 012 | Client backend swap | Domain repository interfaces, implementations chosen by `--dart-define=PENNY_BACKEND=demo or http` | Mock server for demos: one more process to run during a sales meeting |  |
| 013 | Deployment | ArgoCD pulls from `deploy/` in this repo; CI never pushes to the cluster | GitHub Actions `kubectl apply`: needs inbound access to the homelab |  |
| 014 | Email (D6) | Transactional provider behind a `Mailer` interface; Mailpit locally | SMTP from the homelab |  |
| 015 | Messaging | Deferred; adopt an existing E2EE protocol, never custom crypto | Rolling our own: the hard parts are key management, not encryption | Email alerts stop being enough |
| 016 | Visual design (D5) | Penny's own design system (tokens and components) on Material 3, in packages/penny\_ui, with a Widgetbook catalogue and golden tests | Stock Material defaults: the look most generated apps share | A user study shows a component confusing people |

## Monorepo layout

Only the contract crosses between client and server: `apps/` never imports from `services/` or the reverse.

```text
penny/
├── api/
│   ├── openapi.yaml          the contract, single source of truth
│   └── fixtures/             shared JSON test cases (clash detection, PayNow payloads)
├── apps/
│   └── client/               Flutter app (web, Android, iOS), fresh build
├── packages/
│   ├── penny_api/            generated Dart client, committed, never hand-edited
│   └── penny_ui/             design tokens, theme, components, Widgetbook catalogue
├── services/
│   └── api/                  Go module: cmd/api, cmd/worker, cmd/migrate
├── deploy/
│   ├── base/                 Kustomize base: Deployments, Services, CNPG Cluster, Jobs
│   └── overlays/
│       ├── dev/
│       └── prod/
├── docs/
│   ├── adr/                  architecture decision records
│   ├── runbooks/             restore, rotate secrets, failed migration, queue backlog
│   └── architecture.md       this document, exported
├── tools/                    codegen configs, boundary-check scripts
├── compose.yaml              local stack: Postgres+PostGIS, Mailpit, Firebase Auth emulator
├── Taskfile.yml              one entry point: task dev, task gen, task test, task lint
├── .mise.toml                pinned Go, Flutter, Node (for Firebase CLI), task, sqlc
├── .github/
│   ├── workflows/
│   ├── CODEOWNERS
│   └── pull_request_template.md
├── AGENTS.md                 rules for coding agents (layering, commands, completion summary)
├── DESIGN.md                 design principles; points to the design system
├── CONTRIBUTING.md           branching, commits, review
└── README.md
```

**Tooling choices**

- **Taskfile over Make**: readable YAML, cross-platform, task dependencies with caching on file checksums. Every CI step calls a task, so local and CI runs are identical.
- **mise for toolchain pinning**: one file pins Go, Flutter and CLI versions; CI reads the same file.
- **Generated code is committed** (`packages/penny_api`, Go server stubs). Reviewers see contract effects in the diff, and CI fails if regenerating produces a change.

## Backend (Go)

One Go module, one domain package per business capability, three thin entry points. Modules never read each other's tables; they call each other's exported service interfaces or enqueue a job in the same transaction.

```text
services/api/
├── cmd/
│   ├── api/          HTTP server
│   ├── worker/       River job workers and periodic jobs
│   └── migrate/      goose + River migrations, run as a Kubernetes Job
├── internal/
│   ├── platform/     config, slog, pgx pool, http server, OpenTelemetry, clock, id generator
│   ├── httpapi/      generated strict-server interface, thin handlers, middleware
│   ├── identity/     users, token Verifier interface, Firebase adapter
│   ├── workspace/    teams, memberships, roles
│   ├── authz/        capability matrix and resource rules, pure functions
│   ├── scheduling/   students, locations, series, lessons, lesson items, clash detection
│   ├── billing/      payee accounts, payment requests, PayNow encoder, payment records, receipts
│   ├── notify/       Mailer interface, templates, reminder jobs, email log
│   ├── audit/        append-only audit log writer
│   ├── privacy/      PDPA data exports, composed from each module's part
│   └── messaging/    reserved, empty
└── db/
    ├── migrations/   goose SQL, numbered
    └── queries/      sqlc query files, one folder per module
```

**Inside a module**, three layers:

| Layer | Owns | Must not |
| --- | --- | --- |
| Handler (`httpapi`) | Decode request, call one service method, map result and errors to the contract | Contain business rules or SQL |
| Service (`scheduling.Service`) | Use cases, the transaction boundary, the `authz` check, enqueueing follow-up jobs | Know about HTTP |
| Store (`scheduling.Store` interface, sqlc-backed) | Queries, always scoped by `workspace_id` | Make authorization decisions |

**Libraries**: standard `net/http` (Go 1.22+ pattern routing) under oapi-codegen's strict server; `pgx` v5; `sqlc`; `goose`; River; `log/slog`; OpenTelemetry; Prometheus client. Import boundaries are enforced in CI with golangci-lint's `depguard` (for example, `httpapi` may not import `db`).

**Cross-cutting rules**

- Configuration from environment variables only, validated at startup; the process exits on a bad config rather than running half-configured.
- `Clock` and `IDGenerator` are injected, so reminder timing and receipts are testable.
- Graceful shutdown: stop accepting requests, drain in-flight work, let River finish or release jobs.
- Errors: services return typed domain errors (`ErrNotFound`, `ErrForbidden`, `ErrConflict`, `ErrValidation`); one mapper turns them into RFC 9457 problem responses.

**Testing**: unit tests for `authz` and domain logic (table-driven); store tests against a real Postgres (CI service container, testcontainers-go locally); API tests that drive the generated Go client against an `httptest` server.

## Client (Flutter)

Screens depend on domain interfaces, never on where data comes from. The demo backend and the Go server are two implementations of the same repositories, chosen once at startup.

```text
apps/client/lib/
├── main.dart              reads PENNY_BACKEND, builds the ProviderScope overrides
├── app/                   router, shell, theme, composition root (backend_overrides.dart)
├── core/                  env, failures, formatting, clock, capability model
├── data/                  HTTP plumbing shared by the features' data/ folders
├── features/
│   ├── auth/              presentation / application / domain / data
│   ├── onboarding/
│   ├── team/
│   ├── students/
│   ├── lessons/
│   ├── timetable/
│   └── payments/
└── demo/                  seed scenarios, in-memory store, Demo*Repository, persona switcher
```

| Layer | Contains | May import |
| --- | --- | --- |
| presentation | Widgets, screens, view models | application, domain |
| application | Riverpod notifiers and use cases (`CompleteLesson`, `ReassignLesson`) | domain |
| domain | Entities, value objects, repository interfaces, pure rules (clash detection) | nothing in the app |
| data | `Http*Repository` (wraps `packages/penny_api`), `FirebaseAuthRepository`, DTO mappers | domain, generated client |

**How the swap works**

1. `domain/lesson_repository.dart` declares `abstract interface class LessonRepository` with methods such as `watchLessons(range, teacherIds)`.
2. `data/http_lesson_repository.dart` and `demo/demo_lesson_repository.dart` both implement it.
3. `app/backend_overrides.dart` returns the Riverpod overrides for `BackendKind.demo` or `BackendKind.http`. That function is the only place that knows both exist.
4. A shared contract test suite (`test/contract/lesson_repository_contract.dart`) runs against both implementations, the HTTP one against a fake server, so they cannot drift apart.
5. Generated API types never leave `data/`; mappers convert them to domain entities. A contract change touches mappers, not screens.

**Session and capabilities.** `SessionController` exposes the signed-in user, the active team and that team's capability set (from `GET /v1/me`, or from the demo persona). Screens and router guards ask `session.can(Capability.viewTeamTimetable)`; nothing in the UI compares role strings. Adding the student and parent roles later changes the server's capability matrix, not the screens.

**Boundary enforcement.** A CI script fails the build if `presentation/` imports `data/` or `demo/`, or if anything outside `data/` imports `package:penny_api`.

**App icon.** For now the icon is pixel art of a hand flipping a penny. Keep the master file in `apps/client/assets/brand/` on its native pixel grid and scale only by whole-number factors with nearest-neighbour sampling, otherwise the pixel edges blur. Generate platform icons (Android adaptive, iOS, web favicon and PWA manifest icons) with `flutter_launcher_icons` as a dev dependency, keeping the hand and coin inside the Android adaptive-icon safe zone.

## Design and UX

The client is designed before it is coded: a design system first, then the screens people use every day, reviewed at phone and laptop widths with realistic studio data. "Must not look vibe coded" is turned into checkable rules rather than left to taste.

**What makes an app look generated, and the rule that replaces it**

| Tell | Penny's rule |
| --- | --- |
| Stock Material colours, purple gradients, glowing accents; cream backgrounds with a clay accent | Ink and copper: cool white surfaces, deep ink for text and primary actions, copper only for now and today (the current-time line, today's date). Other colour only means a status, always with a word and an icon |
| Every element in its own card with a shadow | Flat surfaces separated by spacing and hairline dividers. Elevation only for things that float: menus, sheets, dialogs |
| Inconsistent spacing and sizes | A 4 px grid, a fixed spacing scale and one radius scale, all from tokens. No literal numbers in feature code |
| Many fonts, weights and sizes | One typeface family, a six-step type scale, two weights, tabular numerals for times and money |
| Emoji and mixed icon sets | One icon set at one stroke weight |
| Decorative animation | Motion only for continuity (a sheet rising, a lesson being moved), 150 to 250 ms |
| Screens that only cover the happy path | Every screen designed in five states: empty, loading, populated, error, no permission |
| Marketing layouts in a work tool | Dense, scannable layouts. The timetable is used every day; it should feel like a good calendar, not a landing page |

**The pixel-art icon.** Keep pixel art to brand moments: app icon, splash, sign-in and empty states. The working UI stays clean and vector, so the logo reads as character rather than as inconsistency. Mixing pixel art into buttons and navigation is the fastest way to look unfinished.

**Usability rules**

- The three most frequent jobs (see today's lessons, mark a lesson done, find a free slot) each take one tap or click from Home.
- Touch targets at least 48 px; WCAG 2.2 AA contrast in light and dark themes; layouts survive 200% text size.
- Times always in the team's timezone, in the device's 12-hour or 24-hour convention.
- Destructive actions (cancel lesson, void receipt) confirm with what will happen, and lesson changes offer undo.

**Process and artifacts**

1. **Design system**: tokens (colour, type, spacing, radius, elevation, motion) and core components (buttons, fields, list rows, lesson block, status badge, sheet, timetable grid, empty state), light and dark.
2. **Key screens** at phone and laptop widths: sign-in, onboarding, Home (today), week, team timetable, lesson detail, students, team list, payment request, public payment page.
3. **Review** against the studio scenario's real density (8 tutors on a busy Saturday, group lessons with several students), then with the studio owner at the walkthrough.
4. **Implementation** in `packages/penny_ui`: a `ThemeData` built from tokens plus `ThemeExtension`s, and Penny components. Feature code uses only these; a lint check blocks raw `Color(...)` values and literal paddings outside `penny_ui`.
5. **Guarding it**: a Widgetbook catalogue of every component in every state (a new dev dependency), and golden-image tests so visual regressions fail CI.

## API contract and code generation

`api/openapi.yaml` is written by hand first; Go server stubs and the Dart client are generated from it. Write it as OpenAPI 3.0.3 for now: oapi-codegen only gained initial 3.1 support in v2.8.0 ([release notes](https://github.com/oapi-codegen/oapi-codegen/releases)), and Dart generators are further behind. Moving to 3.1 later is a mechanical change.

**Conventions**

- Versioned prefix `/v1`; team-scoped resources live under `/v1/workspaces/{workspaceId}/...` so tenancy is visible in every URL and every log line.
- Errors are RFC 9457 `application/problem+json` with a stable `type` per domain error.
- Timestamps are RFC 3339 in UTC; money is an integer number of cents plus an ISO 4217 currency code.
- List endpoints use cursor pagination (`?cursor=&limit=`).
- Mutations on lessons carry `If-Match` with the lesson's version; a stale write returns 412.
- `POST` endpoints that create payment requests, payment records or receipts require an `Idempotency-Key` header.

**First endpoints**

| Method and path | Purpose | Who |
| --- | --- | --- |
| `GET /v1/me` | User, memberships, capability set per team | Any signed-in user |
| `POST /v1/workspaces` | Create a team (onboarding: "I run a team") | Any signed-in user |
| `GET /v1/workspaces/{id}/members` | Team list with role, student count, lessons this week | Owner |
| `POST /v1/workspaces/{id}/members` | Add a teacher | Owner |
| `GET /v1/workspaces/{id}/lessons?from&to&teacherId` | Lessons in a range, filtered | Owner: all; teacher: forced to self |
| `GET /v1/workspaces/{id}/timetable?date&days&teacherIds` | Lessons grouped by teacher, with clash markers | Owner |
| `POST /v1/workspaces/{id}/lessons` | Create a lesson or series | Owner |
| `PATCH /v1/workspaces/{id}/lessons/{lessonId}` | Edit, move, reassign, cancel | Owner |
| `POST /v1/workspaces/{id}/lessons/{lessonId}/complete` | Mark complete | Owner, or a tutor on the lesson |
| `GET /v1/pay/{token}` | Public payment page data | Anyone with the link |

**Generation pipeline** (`task gen`): lint the spec with Spectral, generate Go with oapi-codegen (strict server + models), generate Dart into `packages/penny_api`. For Dart, spike both `openapi-generator` (dart-dio target, needs Java in CI) and a pure-Dart generator in Phase 1 and keep whichever produces cleaner nullable handling. CI runs `oasdiff` against `main` and blocks unannounced breaking changes.

## Identity, authentication, authorization

Firebase proves who someone is; Penny's database decides what they may do. Keeping those apart is what lets you replace Firebase later with a self-hosted OIDC provider (Zitadel, Keycloak, Authentik) by writing one new `Verifier` adapter and one new client repository.

**Sign-in flow**

1. The client signs in with the Firebase SDK: email/password (with a verification email) or Google. On web, Google uses a popup; on Android and iOS, the native Google sign-in sheet.
2. The SDK holds a short-lived ID token (about an hour) and refreshes it. Every API call sends it as `Authorization: Bearer <token>`.
3. API middleware verifies the signature against Google's published keys and checks `aud` (the Firebase project ID), `iss`, `exp` and `email_verified`. This sits behind `identity.Verifier`; the Firebase Admin SDK is one implementation, a fake verifier is another for tests.
4. On first contact, `GET /v1/me` upserts a `users` row keyed by the Firebase UID. Onboarding then creates the user's team: a solo tutor gets a team of one with themselves as owner.
5. Each request resolves the caller's membership in the team named in the URL and loads that role's capabilities.

**Settings to fix up front**: enable "one account per email address" in Firebase so Google and password sign-ins for the same email link to one user; use separate Firebase projects for dev and prod; run the Firebase Auth emulator locally and in CI so tests never touch a real project. Offer account deletion from day one (app stores require it and it is how you honour deletion requests).

**Authorization model.** Role-based per team, plus resource rules. A person can hold different roles in different teams (a teacher at a studio who also has private students is a teacher in one team and the owner of another).

| Capability | Owner | Teacher | Student (reserved) | Parent (reserved) |
| --- | --- | --- | --- | --- |
| View own lessons | Yes | Yes |  |  |
| View every teacher's lessons and the team timetable | Yes | No |  |  |
| View and manage the team list | Yes | No |  |  |
| Create, edit, move, cancel any lesson | Yes | No |  |  |
| Reassign a lesson to another teacher | Yes | No |  |  |
| Mark own lesson complete | Yes | Yes |  |  |
| Add tasks, goals and notes on own lesson | Yes | Yes |  |  |
| Manage students | Yes | View own students only |  |  |
| Create payment requests and confirm payments | Yes | For their own lessons, as payee (ADR 024) |  |  |

The two reserved roles exist in the `membership_role` enum and in the `authz` package with an empty capability set, so adding them is a data and policy change with no schema migration.

**Enforcement, in three layers**

1. **Service layer (authoritative).** Every service method calls `authz.Can(actor, action, resource)` before acting. The policy is a pure function with a table-driven test per row of the matrix above.
2. **Postgres row-level security (defence in depth, Phase 9).** Each transaction runs `SET LOCAL app.workspace_id`; policies reject rows from other teams even if a query forgets its filter. The few operations that span teams by design (a person's own memberships, looking up a public token's team, the worker's sweeps) say so with `database.InCrossTeamTx`; a transaction scoped to neither sees no team's rows. The policies bind the app role, which owns no tables, and the API tests run as that role.
3. **Client (convenience only).** Router guards and hidden controls. They make a teacher unable to reach `/team` by typing the URL, but the server would refuse the request regardless.

A team with one member hides every team feature in the UI. There is no separate solo mode.

## Domain model and database

Every tenant table carries `workspace_id`, and foreign keys between tenant tables include it, so a lesson can never point at another team's student. PostgreSQL 18, run by CloudNativePG, with three extensions: PostGIS (locations), `btree_gist` (time-range indexes) and `citext` (case-insensitive emails).

| Table | Purpose | Key columns and rules |
| --- | --- | --- |
| `users` | A person who can sign in | `firebase_uid` unique, `email` citext, `display_name` |
| `workspaces` | A team ("Team" in the UI) | `name`, `timezone` (default Asia/Singapore) |
| `workspace_memberships` | A person's role in a team | `role` enum (owner, teacher, student, parent), `status` (active, invited, removed); unique per user and team |
| `students` | A learner; not necessarily a user | `primary_teacher_membership_id`, nullable `user_id` for the future student role |
| `student_contacts` | Who gets reminders and receipts | name, email, phone, relationship, notification preferences, nullable `user_id` for the future parent role |
| `locations` | Saved places: studio, a student's home, online | kind (in person, online), address lines, postal code, `geog` geography point, meeting URL |
| `lesson_series` | A recurrence rule that generates lessons | RFC 5545 `rrule`, wall-clock start time, duration, timezone, default tutors and students, location, fee |
| `lessons` | One lesson, always its own row | `starts_at`, `ends_at`, `status`, `kind` (regular, make-up), `makeup_for_lesson_id`, location snapshot, `fee_cents`, `version`. No tutor or student columns: both live in join tables |
| `lesson_tutors` | Tutors on a lesson, any number (D4) | lesson, membership, `role` (lead, assisting), a copy of the lesson's time range kept in sync in the same transaction, for clash queries |
| `lesson_participants` | Students in a lesson, any number (D4) | lesson, student, attendance (present, absent, late) |
| `lesson_items` | Tasks, goals, notes and comments on a lesson | `kind`, body, author, `visibility` (staff, student, contacts), `done_at` |
| `student_goals` | Goals that span lessons | student, title, status; lesson items can link to one |
| `payee_accounts` | Where a tutor receives PayNow | membership, proxy type (mobile, UEN), proxy value, display name |
| `payment_requests` | An amount owed, with a unique public link | one payee, student, `amount_cents`, `reference` (for example `PNY-7K3Q9X`), due date, `token_hash`, expiry, status |
| `payment_request_lines` | What the request covers | lesson, description, amount |
| `payment_records` | The payee's confirmation that money arrived | request, amount, paid on, method, recorded by |
| `receipts` | Immutable proof, one per payment record | per-team `receipt_number`, `content_sha256`, issued at, voided at and reason |
| `audit_events` | Append-only history of every change | actor, team, action, entity, before and after (jsonb), at |

No limit is enforced on tutors or students per lesson. The UI is designed for the common cases (one tutor with one student, one tutor with a small group) and degrades gracefully for larger ones: the lesson block shows the first names and a "+N" count.

**Conventions**: UUIDv7 primary keys (time-ordered, so indexes stay compact; Postgres 18 has a built-in `uuidv7()`); `timestamptz` stored in UTC; money as `bigint` cents plus `char(3)` currency, never floating point; `created_at` and `updated_at` everywhere; `archived_at` instead of deletes for students and members, because lessons and receipts must keep pointing at them.

**Why no graph extension.** Penny's relationships (team, member, student, contact, lesson) are shallow and fixed-depth; joins answer every query in this document. Apache AGE also trails Postgres releases: its PostgreSQL 17 release was still being proposed in September 2025 ([dev list](https://mail-archive.com/dev@age.apache.org/msg07736.html)), about a year after Postgres 17 shipped, though a March 2026 build now covers 17 and 18 ([EDB notes](https://www.enterprisedb.com/docs/pg_extensions/apache_age/rel_notes/apache_age_1.7.0.1_rel_notes/)). Adopting it means a custom CNPG image and an upgrade path you do not control, for no current query.

**Migrations**

- `goose` SQL files in `services/api/db/migrations`, forward-only in every shared environment. River's own tables are migrated from the same `migrate` binary, so one tool owns the schema.
- Schema changes that would break running code use expand, migrate, contract across separate releases: add the new column, backfill and dual-write, switch reads, then drop the old column.
- The `migrate` binary runs as an ArgoCD PreSync Job before new API pods start; a failed migration stops the rollout.
- Two database roles: `penny_migrator` (DDL) used only by the Job, `penny_app` (DML only) used by `api` and `worker`.
- CI applies every migration to an empty database, runs `sqlc vet` against the result, and also upgrades a database built from the previous release's schema.

## Scheduling, lessons, timetable

Every lesson is its own row, even when it came from a recurring series, so each one can carry its own notes, tasks, attendance, fee and payment link.

**Recurrence.** A series stores an RFC 5545 rule evaluated in the team's timezone. A periodic worker job materialises lessons over a rolling horizon (start with 12 weeks and tune). Edits offer three scopes: this lesson only, this and following (splits the series at that date), or all future lessons. Past lessons are never rewritten by a series edit.

**Lesson lifecycle**

| From | To | Who | Side effects |
| --- | --- | --- | --- |
| scheduled | completed | Owner, or a tutor on the lesson | Lesson becomes billable |
| scheduled | cancelled | Owner | Pending reminders become no-ops; optional make-up lesson created with `kind = makeup` and `makeup_for_lesson_id` |
| scheduled | no-show | Owner, or a tutor on the lesson | Billable per team policy (open question) |
| completed | scheduled | Owner | Only if no receipt references it |

**Locations.** Saved per team and picked per lesson. In-person locations store a structured Singapore address with postal code and a PostGIS point, which later allows travel-time warnings between back-to-back lessons in different places. The lesson keeps a snapshot of the address text, so editing a saved location does not rewrite history. Online lessons store a meeting URL.

**Clash detection.** A clash is one tutor on two non-cancelled lessons whose times overlap; a lesson with several tutors is checked for each of them. It warns, it does not block (D3). The rule is a pure function written twice, in Go (`scheduling`) and Dart (`domain`), because the demo backend must behave like the server. Both test suites read the same cases from `api/fixtures/clashes/*.json`, so the two implementations cannot disagree silently. A GiST index on `lesson_tutors (membership_id, time_range)` keeps the query cheap. Students can clash too (one student booked into two lessons at once); the same rule runs over `lesson_participants`.

**Team timetable (owner only).** Day view with one column per teacher and time down the side; week view with a teacher filter. A lesson with several tutors appears in each tutor's column, marked as shared. Empty slots are drawn explicitly so "who is free on Thursday at 5pm?" is answered by looking. Wide layouts show all teachers side by side; phone width shows one teacher with a switcher and never scrolls horizontally. True free/busy needs teacher availability data, which is an open question from the PRD; until then "free" means "no lesson".

**Calendar export (cheap win, Phase 6).** A per-teacher read-only iCalendar feed at an unguessable URL lets teachers subscribe from Google or Apple Calendar without any OAuth integration. Two-way sync stays out of scope.

## Notifications and background jobs

Reminders are jobs enqueued in the same database transaction as the change that causes them, so a lesson can never be saved without its reminder, or the reverse. River provides this on Postgres without a separate broker ([River](https://github.com/riverqueue/river)).

| Job | Enqueued when | Runs | On execution |
| --- | --- | --- | --- |
| `LessonReminder` | A lesson is created or moved | 24 hours before start (per-team setting) | Re-reads the lesson; does nothing if cancelled, moved or already past. Unique per lesson, kind and start time, so a move supersedes the old reminder |
| `PaymentReminder` | Periodic, daily | Morning, team timezone | Emails contacts for open requests past their due date, at most once per interval |
| `ReceiptEmail` | A receipt is issued | Immediately | Sends the receipt to the student's billing contacts |
| `MaterializeSeries` | Periodic, nightly | Off-peak | Extends every active series to the horizon |
| `PurgeExpired` | Periodic, nightly | Off-peak | Removes expired payment tokens and old job rows |

**Email delivery**

- `notify.Mailer` is an interface with two adapters: SMTP to Mailpit for local and CI, and an HTTPS adapter for a transactional provider in dev and prod (Postmark, Resend and Amazon SES all fit; pick on price and Singapore delivery).
- Do not send from the homelab: residential IP ranges are commonly blocklisted and many ISPs block outbound port 25.
- Set SPF, DKIM and DMARC on the sending domain before the first real email.
- Templates are Go `html/template` plus a plain-text part, in the repo, with golden-file tests.
- Every send is written to `email_log` with the provider's message ID, so "I never got the reminder" can be checked.
- Each contact can opt out per category with a signed unsubscribe link; transactional receipts remain on.

**Failure behaviour.** If the cluster is down, River picks up overdue jobs when it returns. A lesson reminder more than an hour late is dropped rather than sent after the lesson. The metric to alert on is reminder lag: actual send time minus scheduled time.

## Payments (PayNow) and receipts

Penny generates a PayNow QR that pays the teacher directly and records what both sides confirm. It never sees the money, so it can never prove a payment happened; a request closes only when the payee and the payer have each confirmed it (ADR 024), and the design makes both confirmations quick and traceable.

**Flow**

1. **Payee setup.** A teacher registers a PayNow proxy (mobile number or UEN) and a display name. Penny shows a test QR they scan in their own banking app: the app shows the registered recipient name, which confirms the proxy is right before any parent sees it.
2. **Payment request.** Created by an owner for any payee, or by a teacher for their own lessons, from billable lessons (done, and no-shows or late cancellations the lead tutor's policy bills) plus any extra lines. Each payee chooses whether a new request is sent at once or kept as a draft until they send it. It gets lines (one per lesson or item), an amount, a due date and a short reference such as `PNY-7K3Q9X` (Crockford base32, no ambiguous characters). Each request has exactly one payee. For a lesson with several tutors, the lead tutor (whoever created the lesson, unless the owner reassigns it) bills the whole fee and decides how it is shared under the tutors' own agreement. Penny does not split or track the shares; the lesson and the payment request state that the split is arranged outside the app.
3. **Unique link.** `https://<domain>/pay/<token>`, where the token is 128 random bits and only its SHA-256 hash is stored. Links expire and can be revoked. The page shows the payee name, amount, what it covers, the reference and the QR. It is rate-limited and shows no more about the student than a first name.
4. **Payer pays** in their banking app; money moves bank to bank, outside Penny, then taps "I've paid", which records their confirmation and notifies the payee.
5. **Payee confirms** the money arrived (matching amount and reference in their bank notification). This creates a `payment_record`. Steps 4 and 5 may happen in either order.
6. **Receipt issued** automatically from that record when the second confirmation arrives, and emailed with its PDF. Overdue requests are chased weekly until either side confirms; contacts can stop these reminders.

**QR payload.** PayNow QR codes follow SGQR, which follows EMVCo's merchant-presented QR format. Penny encodes them itself in `billing/paynow`: about a hundred lines with golden-file tests, rather than depending on a small library (the Go one found supports UEN proxies only, not mobile numbers).

| ID | Field | Penny's value |
| --- | --- | --- |
| 00 | Payload format indicator | `01` |
| 01 | Point of initiation | `12` (dynamic: one QR per request) |
| 26 | Merchant account information | sub-fields: `00` = `SG.PAYNOW`, `01` = proxy type (`0` mobile, `2` UEN), `02` = proxy value, `03` = editable flag `0` (amount fixed), `04` = expiry `YYYYMMDD` |
| 52 | Merchant category code | `0000` |
| 53 | Currency | `702` (SGD) |
| 54 | Amount | for example `120.00` |
| 58 | Country | `SG` |
| 59 | Merchant name | payee display name (25 characters max) |
| 60 | City | `Singapore` |
| 62 | Additional data | sub-field `01` = bill reference, the request's `PNY-` code |
| 63 | CRC | CRC-16/CCITT over everything before it |

Field layout from published implementations ([paynow\_qr](https://gemdocs.org/gems/paynow_qr/0.1.0/), [Python generator](https://www.github.com/poonchuanan/Python-PayNow-QR-Code-Generator), [Go generator](https://www.github.com/VirgilZhao/paynow)); verify against the MAS SGQR specification and a real scan from at least three bank apps before launch. Whether the bill reference appears in the recipient's own bank records varies by bank, especially for personal mobile-number proxies, so reconciliation stays a human check.

**Receipts and traceability**

- Chain: receipt, then exactly one payment record, then its payment request (and its reference), then the request's lines, then the lessons. Every step is a foreign key, and every transition writes an `audit_events` row.
- Receipt numbers are sequential and gapless per team. Postgres sequences can skip numbers on rollback, so Penny increments a per-team counter row locked with `SELECT ... FOR UPDATE` inside the issuing transaction.
- Receipts are immutable. A correction voids the receipt (with reason, actor and time) and issues a new one that references it. Nothing is ever edited in place.
- The receipt PDF is rendered deterministically from its row; Penny stores the SHA-256 of the content so a copy can later be shown to be unaltered.

Because Penny never holds or transmits funds, it is probably outside payment-services licensing, but that is a legal question: I'm not a lawyer, and it is worth a short check with someone who knows Singapore's Payment Services Act before charging for the product.

## Messaging (deferred)

Nothing is built for messaging until email alerts stop being enough; only the `messaging` package name is reserved. Two corrections to the requirement as written, so the eventual design starts from the right place:

- **It will be end-to-end encrypted, not peer-to-peer.** Phones and browsers cannot reliably reach each other directly; messages are relayed and stored by the server as ciphertext it cannot read.
- **Encryption is the easy part.** The hard parts are multi-device keys, key backup when a phone is lost, and key storage in a browser (Flutter web has no secure enclave). Use an existing protocol and library: the Signal protocol via libsignal, MLS via OpenMLS, or a Matrix homeserver with its Dart SDK. Never custom cryptography.

**Safeguarding comes before cryptography.** Many students are minors. End-to-end encryption between a teacher and a child means neither the studio owner nor the parent can ever review those messages. Decide first whether conversations with a minor must include a parent or the studio, then pick the protocol. This is the first open question for the messaging phase.

## Infrastructure and deployment

Penny runs on the existing three-node K3s cluster, deployed by the ArgoCD instance already there. Everything is declared in `deploy/`, so moving to a VPS or a managed cluster later is a restore and a DNS change, not a rewrite.

| Concern | Choice | Notes |
| --- | --- | --- |
| Exposure to the internet | Cloudflare Tunnel (`cloudflared` Deployment) | No open ports at home, home IP hidden, TLS at the edge |
| Ingress | Traefik (K3s default) | Routes `app.` to the client and `api.` to the API |
| Database | CloudNativePG `Cluster`, 3 instances, one per node | Replication across nodes gives HA on local-path storage, so Longhorn is not needed; this is the layout CNPG recommends |
| Backups | CNPG Barman Cloud to off-site S3-compatible storage (Cloudflare R2 or Backblaze B2) | Continuous WAL archiving for point-in-time recovery plus daily base backups; a monthly restore drill into a scratch cluster, because an untested backup is a hope |
| Secrets | Sealed Secrets, or External Secrets Operator if Vault is actually running | Never plain Secrets in git; Firebase service account, email API key, R2 keys |
| Images | GHCR, distroless static base for Go, unprivileged nginx for the web client | Tagged by commit SHA; deployed by digest |
| Workloads | `api` (2 replicas), `worker` (1 replica; River elects a leader if scaled), `migrate` (PreSync Job), `web` (2 replicas) | Requests and limits set, PodDisruptionBudgets, readiness on database reachability |
| Network policy | Default deny in Penny namespaces; allow ingress to api and web, api and worker to the database | K3s enforces NetworkPolicy with its embedded controller |
| Environments | Local (`compose.yaml`), `penny-dev` namespace (auto-deployed from `main`), `penny-prod` namespace (promoted by PR) | Separate Firebase projects and email streams per environment |

**Deployment flow.** A merge to `main` builds images and commits the new digests to `deploy/overlays/dev`; ArgoCD syncs dev. Promotion to prod is a pull request that copies those digests into `deploy/overlays/prod`, so every production change is a reviewed, revertible commit. CI never needs network access to the homelab.

**Be honest about the homelab.** One site, residential power and internet, hardware you maintain. Start with a 99.0% monthly availability objective (about 7 hours of allowed downtime), put the nodes and router on a UPS, and plan the move to rented infrastructure for when paying customers depend on reminders arriving. An option worth considering early: serve the Flutter web build from Cloudflare Pages, so the app still loads and can show a clear outage message when the API is down.

## Git workflow and GitHub Actions

Trunk-based development: `main` is always deployable to dev, work happens on short-lived branches, and every change reaches `main` through a pull request with green checks.

**Branches and commits**

- Branch names: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, and `prototype/` for throwaway work that is never merged (the team-timetable demo, per its PRD).
- Conventional Commits with the component as scope: `feat(api): verify Firebase ID tokens`, `fix(client): keep week view on today after sign-in`. The PR title is linted, and squash-merge makes it the commit on `main`.
- `main` is protected: pull request required, required checks pass, linear history, no force-push. Solo for now, so self-approval is allowed, but the checks are not optional.
- One concern per PR. A migration lands in the same PR as the code that needs it, never with unrelated changes.
- `CODEOWNERS` maps `services/`, `apps/`, `api/` and `deploy/` so future collaborators get the right reviewers.
- release-please in manifest mode cuts per-component versions and changelogs (`api/v0.3.0`, `client/v0.3.0`) from the commit history.
- Renovate keeps Go modules, pub packages, GitHub Actions and container images current, grouped into one weekly PR per ecosystem.

**Workflows**

| Workflow | Trigger | Does |
| --- | --- | --- |
| `ci.yml` | Every PR | Detects changed paths, runs the jobs below that apply, then one always-running `ci-ok` job that branch protection requires |
| api job | `services/api/**`, `api/**` | golangci-lint, `go test -race` against a Postgres service container, `sqlc diff` and `sqlc vet`, migrations on an empty database, govulncheck |
| client job | `apps/client/**`, `packages/**`, `api/**` | `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, boundary-check script, `flutter build web` |
| contract job | `api/**` | Spectral lint, `oasdiff` breaking-change check against `main`, regenerate Go and Dart and fail on any diff |
| deploy-config job | `deploy/**` | `kustomize build` for every overlay, kubeconform schema validation |
| `security.yml` | Every PR and weekly | gitleaks, CodeQL for Go, Trivy filesystem scan |
| `release.yml` | Push to `main` | Build images with Buildx, push to GHCR, Trivy image scan, SBOM, commit new digests to `deploy/overlays/dev` |
| `promote.yml` | Manual dispatch | Opens a PR copying dev digests into `deploy/overlays/prod` |
| `pr-title.yml` | PR opened or edited | Conventional Commits check on the title |

Two details that save pain later: pin third-party actions by commit SHA (Renovate updates the pins), and use `concurrency` groups so a new push cancels the superseded run. The single `ci-ok` gate exists because GitHub treats a required check from a path-filtered workflow that never ran as pending forever, which blocks unrelated PRs.

## Observability, operations, security

Measure what users feel: can they load their schedule, and did the reminder arrive on time.

**Service level objectives (starting targets, tune after a month of data)**

| SLO | Target | Measured from |
| --- | --- | --- |
| API availability (non-5xx share of requests) | 99.0% monthly | Traefik and API request metrics |
| Read latency, p95 | Under 300 ms | API histogram per route |
| Lesson reminders sent within 10 minutes of schedule | 99% | Worker reminder-lag metric |
| Backups | Daily base backup succeeds; restore drill passes monthly | CNPG metrics, drill checklist |

**Signals**

- **Metrics**: Prometheus (already running) scrapes `/metrics` on api and worker through ServiceMonitors: request rate, errors and duration per route; pgx pool stats; River queue depth and job latency; CNPG's own exporter. Grafana dashboards live in `deploy/` as JSON.
- **Logs**: `slog` JSON with `request_id`, `workspace_id` and `user_id`, never emails, names or tokens. Ship with Grafana Alloy to Loki (new component on the cluster).
- **Traces**: OpenTelemetry in code from day one; add Tempo when latency questions start.
- **Health**: `/livez` (process up) and `/readyz` (database reachable, migrations at the expected version).
- **Alerts**: Alertmanager to Telegram or Discord, only for SLO burn, backup failure, and queue backlog. Each alert links to a runbook in `docs/runbooks/`.

**Security and privacy**

- Use OWASP ASVS Level 1 as the review checklist before the first real user.
- Rate-limit the public payment page and every unauthenticated endpoint; restrict CORS to Penny's own origins; set standard security headers.
- Least privilege: separate migrator and app database roles; Kubernetes service accounts with no API permissions; secrets only via the chosen secrets operator.
- Singapore's PDPA applies: collect only what scheduling and billing need, publish a retention policy, support access, correction and deletion requests, and have a breach-response runbook, since notifiable breaches must be reported. Students are often minors, so treat contact details and lesson notes as sensitive by default.
- The audit log is append-only to the app role (insert, no update or delete grants), which also gives you a credible answer when a parent disputes a lesson or payment.

## Component-by-component build plan

Eleven phases. Each ends with something deployed to dev and a set of checks that prove it, so the plan can stop at any phase boundary with a working product. Phases 0 to 4 are specified to task level; later phases get refined when you reach them.

### Phase 0: Repository foundations

- [ ] Create the `penny` monorepo from scratch (the old `penny-frontend` is not imported)
- [ ] Folder skeleton from the layout section; `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `docs/adr/000-template.md` and ADRs 001 to 016
- [ ] `.mise.toml` pinning Go, Flutter, task, sqlc, goose; `Taskfile.yml` with `dev`, `gen`, `lint`, `test`, `build`
- [ ] `compose.yaml`: Postgres 18 with PostGIS, Mailpit, Firebase Auth emulator
- [ ] Branch protection, PR template, `CODEOWNERS`, `pr-title.yml`, Renovate config, `ci.yml` with the `ci-ok` gate and empty jobs

Done when: a fresh clone runs `task dev` and `task test` with only mise and Docker installed, and a trivial PR goes green.

### Design track: design system and key screens

Runs alongside Phases 0 and 1 (no code dependency) and must finish before Phase 2 builds any screen.

- [x] Design principles written into `DESIGN.md` (the rules table in Design and UX)
- [x] Design system: colour, type, spacing, radius, elevation and motion tokens, light and dark; core components in all states
- [ ] Key screens at phone and laptop widths: sign-in, onboarding, Home, week, team timetable, lesson detail (with several tutors and students), students, team list, payment request, public payment page
- [ ] Density check with the studio scenario (8 tutors, busy Saturday, group lessons)
- [ ] Short review pass: someone who has not seen the designs finds a free Thursday 5pm slot and marks a lesson done, unaided

First pass done on 15 Nov 2026: the [Penny design system](https://claude.ai/artifact/LPdfpG6SV6cDd2UJkdpSV7) (tokens, brand book, 15 components) and [Penny key screens](https://claude.ai/artifact/V1uvDiMuTjJ9YCapXr2vZZ) (11 phone, 4 laptop). Remaining screens and states are listed in `docs/design/screens.md`.

Done when: every key screen exists in all five states at both widths, and the tokens are final enough to code.

### Phase 1: Backend walking skeleton, deployed

- [x] `api/openapi.yaml` with `GET /livez`, `GET /readyz`, `GET /v1/me` (stubbed), problem schema
- [x] `internal/platform`: config, slog, pgx pool, HTTP server with graceful shutdown, Prometheus metrics, OTel setup
- [x] `cmd/migrate` running goose and River migrations; first migration creates extensions and `users`
- [x] Generated strict server wired; handler for health endpoints; error mapper
- [x] Dockerfiles (distroless), `release.yml` pushing to GHCR
- [x] `deploy/base` and `overlays/dev`: CNPG Cluster with off-site backups, api Deployment, migrate Job (a Sync hook after the database, see `deploy/README.md`), Service, IngressRoute, Cloudflare Tunnel route, sealed secrets (placeholders)
- [x] ArgoCD Application for `penny-dev`; ServiceMonitor and a first Grafana dashboard

Done when: merging to `main` puts a new API version live in dev with no manual step, `/readyz` is green through the tunnel, and a restore from backup into a scratch namespace works once.

Code and manifests done on 15 Nov 2026, with `GET /v1/version` added so the client can show which build it talks to. The first deployment waits on the open questions it depends on (domain, tunnel, backup bucket, sealed secrets, release app); `deploy/README.md` lists each step, and the restore drill follows `docs/runbooks/restore-database.md`.

### Phase 2: Client skeleton and demo backend

- [x] Feature-first structure, four layers, `app/backend_overrides.dart`, `PENNY_BACKEND` define
- [x] `packages/penny_ui` from the design system: tokens, `ThemeData`, `ThemeExtension`s, core components, Widgetbook, golden tests, lint against raw colours and paddings
- [x] go\_router with a guard hook; app shell responsive at phone and laptop widths
- [x] Pixel-art penny-flip icon in `assets/brand/`, platform icons generated
- [x] `packages/penny_api` generated; contract job in CI; Dart generator spike decided (ADR 022)
- [x] Boundary-check script; repository contract-test harness
- [x] `web` image and Deployment in dev

Done when: the client runs in demo and HTTP modes, the HTTP mode shows the API version from dev, and the boundary check fails a deliberately bad import.

Code done on 15 Nov 2026. The client targets web, Android, iOS, Windows, macOS and Linux. HTTP mode was checked against a local API (the dev environment waits on Phase 1's deployment steps). The Phosphor icons are bundled as fonts because `phosphor_flutter` no longer compiles (ADR 021). Shared HTTP plumbing for the features' `data/` folders lives in `lib/data/`.

### Phase 3: Authentication

- [ ] Firebase dev and prod projects; email/password with verification, Google provider, one account per email (steps in `docs/runbooks/firebase-auth-setup.md`)
- [x] Client: `AuthRepository` interface, `FirebaseAuthRepository`, sign-up, sign-in, verify-email, reset password, sign-out, delete account
- [x] Client: `DemoAuthRepository` backing the "Viewing as" persona switcher (PRD R2), visibly labelled and isolated in `demo/`
- [x] Server: `identity.Verifier` with Firebase and fake implementations; auth middleware; `GET /v1/me` upserts the user
- [x] CI runs auth tests against the Firebase emulator

Done when: a user can sign up both ways on web and Android, `/v1/me` returns them, and an expired or forged token gets 401.

Code done on 22 Nov 2026 for web, against the Firebase Auth emulator; mobile builds and the real Firebase projects are deferred. The server has a third verifier for the emulator's unsigned tokens, refused for any project ID not starting with `demo-`. The client's Firebase code is `FirebaseIdentityProvider` behind a data-layer `IdentityProvider`, and the demo's `DemoSessionRepository` doubles as its `AuthRepository`. The persona switcher is generic (it shows whatever personas the `AuthRepository` offers) because the shell may not import `demo/`. `task test:e2e` runs the web client in headless Chrome against the real API, a fresh database and the emulator.

### Phase 4: Teams, roles, onboarding

- [x] Migrations: `workspaces`, `workspace_memberships`, role enum including reserved values
- [x] `authz` package with the capability matrix and table tests; capabilities returned by `/v1/me`
- [x] Onboarding step "Do you teach on your own, or run a team?" (PRD R6); creates the team
- [x] Team list and "Add teacher" for owners (PRD R5): in-memory in demo mode, a membership row in HTTP mode (invitations later)
- [x] `SessionController`, capability-driven guards and navigation; team UI hidden for a team of one
- [x] Widget tests for visibility rules per persona; API tests that a teacher gets 403 on owner endpoints

Done when: owner, teacher and solo personas see exactly what the PRD describes, in both modes, and typing an owner URL as a teacher redirects in the client and is refused by the server.

Code done on 22 Nov 2026. An added teacher is an `invited` membership matched by email: it becomes active the first time someone signs in with that verified address, so invitation emails (Phase 7) only need to tell them. Memberships keep copies of the person's name and email, kept in step by the `account` module, because the workspace module does not read `users`. Team changes are written to the `audit_events` log, created here rather than in Phase 5. A person who signs up without a team is sent to `/onboarding`; a team of one reaches its team list from the Account page. The demo gained a fourth persona, new to Penny, to show onboarding, and a `DemoStore` that every demo repository shares. `task test:e2e` covers an owner adding a teacher who then signs up and joins.

### Phase 5: Students, lessons, lesson items

Students and contacts, locations with postal-code entry, lessons with any number of tutors and students, lifecycle transitions with PRD R7 permissions, lesson items (tasks, goals, notes), student goals, optimistic concurrency, audit events. Studio demo scenario (owner plus 7 teachers, about 40 students, a realistic week, one cancellation, one make-up, one clash) per PRD R1. Done when the contract tests pass for both repository implementations.

Client done on 22 Nov 2026, on web. Each tutor has a cancellation policy (Penny's default until they set one: 24 hours' notice, late cancellations not charged, no-shows charged), shown on the lesson, in the cancel sheet before confirming, and on Account; owners edit anyone's from the Team page. The clash, late-cancellation and billing rules are mirrored in the client's domain so the demo backend and the screens agree with the server; the clash rule runs against the shared fixtures. Undo after "Mark done" reopens the lesson. The demo seeds two teams around the current week: the studio (an owner, seven teachers, 40 students, today as the designs draw it) and a team of one. Lesson and student details are pages with Back on laptop; the side panel waits on its design (`docs/design/screens.md`).

### Phase 6: Timetable and calendar

Team timetable day view and week view with teacher filter (PRD R3), clash detection with shared fixtures, explicit empty slots, phone layout with teacher switcher, teacher-filtered Home, week and month views (PRD R4), recurring series with materialisation job, iCalendar feed. Done when the PRD's "done means" list passes, including widget tests for empty, populated and clash states.

Client done on 22 Nov 2026, on web. The Calendar page has Day, Week and Month, and Team or Mine for people who may see the team timetable. The team's day has a column for every current tutor, free or not, from `GET /timetable`; on laptop a chip filter narrows the columns and on phone one tutor shows at a time with a chip switcher, starting with the viewer. A week is a column per day on laptop and a list per day on phone, so the page never scrolls sideways; a month is a `MonthGrid` whose days open in the day view. Owners tap or hover a free time to add a lesson there for that column's tutor. Teachers and a team of one see only their own lessons; Today keeps Phase 5's Mine and Everyone. Add lesson can repeat weekly on the lesson's day; rescheduling a repeating lesson asks whether to change this lesson, this and following lessons, or all lessons from today, and the lesson page can stop the series. Account makes, copies and stops the private calendar link, shown once. The demo turns the studio's weekly lessons into series and books later weeks when someone looks ahead, as the worker would. Swiping between tutors or days on phone, and dragging lessons to move them, are not built.

### Phase 7: Email notifications

Worker binary deployed, `Mailer` with Mailpit and provider adapters, sending domain with SPF, DKIM and DMARC, templates with golden tests, lesson reminders, email log, per-category unsubscribe, reminder-lag metric and alert. Done when moving a lesson sends exactly one reminder at the new time, and a cancelled lesson sends none.

### Phase 8: Payments and receipts

Payee setup with test-scan confirmation, PayNow encoder with golden payloads verified on three bank apps, payment requests and lines, public link page, "I've paid" notice, payment records, gapless receipt numbering, PDF rendering with content hash, void and reissue, payment reminders. Done when any receipt can be traced to its lessons through the UI and the audit log.

### Phase 9: Hardening

Row-level security, ASVS Level 1 review, rate limits, PDPA access and deletion flows, retention jobs, prod overlay and first promotion, restore drill, load test at ten times expected traffic. Done when prod is live and the first runbook has been exercised.

### Phase 10: Student and parent roles

Invitations by email, linking `students.user_id` and `student_contacts.user_id`, capability sets for the two roles, a parent view of upcoming lessons, receipts and payment links.

### Phase 11: Encrypted messaging

Safeguarding decision first, then protocol selection and a design document of its own.

## How the team-timetable PRD maps onto this

The PRD's prototype becomes the client running with `PENNY_BACKEND=demo`. Nothing in it is throwaway any more except the persona switcher and the seed data, both confined to `lib/demo/`.

| PRD item | Lands in | Phase |
| --- | --- | --- |
| Team = workspace | `workspaces`; "Team" in all UI copy | 4 |
| Member with owner or teacher role | `workspace_memberships`, reserved student and parent values | 4 |
| `Lesson.teacherId` and `teacherName` | Replaced by a list of tutors (`lesson_tutors`, memberships not users, since one person can teach in several teams), with names denormalised for display (D4) | 5 |
| Lesson's student | Replaced by a list of students (`lesson_participants`) (D4) | 5 |
| `Student.teacherId` | `primary_teacher_membership_id` | 5 |
| R1 studio demo data | `lib/demo/scenarios/studio.dart` and a solo scenario, both new; include group lessons and one co-taught lesson | 5 |
| R2 "Viewing as" switcher | `DemoAuthRepository`; deleting `lib/demo/` removes it | 3 |
| R3 team timetable | `features/timetable`, clash rule shared with the server through fixtures; built new, not reusing the old week view | 6 |
| R4 tutor's own schedule | Capability-filtered queries; server limits results to lessons the caller tutors | 6 |
| R5 team list and add teacher | `features/team`; demo store or membership row | 4 |
| R6 sign-up question | `features/onboarding`, creates the team | 4 |
| R7 who can change what | `authz` capability matrix | 4 and 5 |
| Unreachable by typed URL | Router guard (demo and HTTP) plus 403 from the server (HTTP) | 4 |
| PRD constraint: reuse the existing design system | Superseded by D5: a new design system, designed first | Design track |

**If the walkthrough is soon,** take the fast path: Phase 0 and the design track, then Phase 2, then the demo-mode parts of Phases 3 to 6, and only then go back for the backend phases. The architecture is the same either way; only the order changes. The PRD's section 9 questions (who changes the timetable, availability, rooms, student assignment, who collects payment, current tools) feed straight into the open questions below and should be asked at the meeting.

## Open questions

**For you (blocks Phase 0 or 3)**

- [ ] When is the customer walkthrough? It decides whether to take the demo fast path
- [ ] Domain name for `app.` and `api.` and for sending email
- [ ] Is Vault actually running on the cluster, or should secrets use Sealed Secrets?
- [ ] Budget for managed pieces (email provider, off-site backup storage), even if small

**For the studio owner (from the PRD, ask at the walkthrough)**

- [ ] Who changes the timetable today, and how does the change reach the teacher and the parent?
- [ ] Do teachers set their own availability, or does the owner assign slots?
- [ ] Does he schedule around rooms or locations as well as teachers?
- [ ] How are students assigned to teachers, and how often does that change?
- [x] Who collects payment, the studio or each teacher? Each payee, owner or teacher, has their own PayNow account and bills for the lessons they lead (ADR 024). How the studio then pays its teachers stays outside Penny.
- [ ] Are no-shows and late cancellations billable?
- [ ] What does he use now, and what has he tried and abandoned?

**For later phases**

- [ ] Messaging with minors: must a parent or the studio be part of every conversation?
- [ ] Does any customer need tax invoices rather than receipts?

## Sources

- [oapi-codegen releases](https://github.com/oapi-codegen/oapi-codegen/releases): v2.8.0 adds initial OpenAPI 3.1 support
- [Apache AGE 1.6.0 for PostgreSQL 17, release discussion](https://mail-archive.com/dev@age.apache.org/msg07736.html) and [EDB release notes for AGE 1.7.0.1](https://www.enterprisedb.com/docs/pg_extensions/apache_age/rel_notes/apache_age_1.7.0.1_rel_notes/)
- [River job queue](https://github.com/riverqueue/river)
- PayNow payload layout: [paynow\_qr gem](https://gemdocs.org/gems/paynow_qr/0.1.0/), [Python PayNow QR generator](https://www.github.com/poonchuanan/Python-PayNow-QR-Code-Generator), [Go PayNow generator](https://www.github.com/VirgilZhao/paynow)
- Team-timetable prototype requirements (`TEAM-TIMETABLE-PROTOTYPE.md`, supplied by you)
