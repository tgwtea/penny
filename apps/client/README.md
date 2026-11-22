# client

The Penny app for web, Android, iOS, Windows, macOS and Linux, built on Penny's own design system (`packages/penny_ui`). It does not reuse the earlier `penny-frontend` prototype.

## Running it

```sh
task run:client                   # demo data, no server; add a device: task run:client -- -d windows
task run:api                      # in another terminal, then:
task run:client:web               # Chrome on :5173 against the local API
```

| `--dart-define` | Values | Default |
| --- | --- | --- |
| `PENNY_BACKEND` | `demo` (in-memory data in `lib/demo/`) or `http` (the Go API) | `demo` |
| `PENNY_API_URL` | The API's address | `http://localhost:8080`; on the web, `config.json` beside `index.html` first |
| `PENNY_FIREBASE_*` | The Firebase project for the `http` backend (`PROJECT_ID`, `API_KEY`, `APP_ID`, `AUTH_DOMAIN`, `MESSAGING_SENDER_ID`) | None: the local Auth emulator under `demo-penny`. See `docs/runbooks/firebase-auth-setup.md` |

The web image is built once and promoted between environments, so it reads the API address and Firebase settings at run time from `/config.json`, which nginx writes from `PENNY_API_URL` and `PENNY_FIREBASE_*` when the container starts (`Dockerfile`, `nginx/`).

## Signing in

Every session state has one page (`app/routes.dart`, `redirectFor`): loading or a failed load, signed out, email not verified, signed in. In `http` mode `FirebaseIdentityProvider` (the only Firebase code, in `features/auth/data/`) signs people in and `HttpSessionRepository` turns that plus `GET /v1/me` into the session; `ApiConnection` (`data/`) attaches a fresh ID token to every API call. In `demo` mode the sign-in page offers the demo personas instead, and the shell shows "Viewing as".

## Teams

Someone signed in without a team is sent to `/onboarding`: "Do you teach on your own, or run a team?". Either answer creates a team they own; a team of one hides every team feature, and its owner reaches the team list from the Account page. `/team` (owners only) lists members and adds teachers by email: they stay "Invited" until they sign in to Penny with that address, then join automatically. People in several teams switch from the sidebar's team name or the Account page.

`TeamRepository` (`features/team/domain/`) has `HttpTeamRepository` and, in `lib/demo/`, `DemoTeamRepository` over `DemoStore`, the in-memory data every demo repository shares. Both keep the server's rules (owners first, no duplicate emails, never a team without an owner); `test/contract/team_repository_contract.dart` checks them against both.

## Lessons and students

Today (`features/lessons/presentation/today_screen.dart`) lists the day's lessons in the team's timezone with the now line. Owners of a team switch between their own lessons and everyone's; on everyone's, each lesson names its tutor. Mark done offers Undo for six seconds, which reopens the lesson. A clash is a warning on the lesson and on Today, never a block: saving a lesson that overlaps another switches the sheet to "Keep it" or "Change the time".

Lesson details (`/lessons/:id`) show the lesson's facts, its clashes, its cancellation and make-up, its tutors, attendance, fee and who bills it, its tasks, goals and notes, the lead tutor's cancellation policy and its history. Its buttons follow the viewer's capabilities; the server checks the same rules. Students (`/students`, `/students/:id`) are searched, added with a first contact, and archived. Places (`/places`, from Account) and cancellation policies (your own on Account, each member's from the Team page) are edited in sheets.

The rules the server applies are mirrored as plain Dart in `features/lessons/domain/` so the demo backend and the screens agree with it: `findClashes` (`clash_rule.dart`, checked against the shared fixtures in `api/fixtures/clashes/`), and `isLateCancellation` and `isBillable` (`policy.dart`). Each tutor's policy is transparent: the lesson sheet says before cancelling whether it is late and whether it will be charged. Without a policy of their own a tutor has Penny's default: 24 hours' notice, late cancellations not charged, no-shows charged.

Times: the server sends UTC instants. `TeamTime` (`core/team_time.dart`) turns them into the team's wall-clock time and back; `activeTeamProvider` carries it with the membership and capabilities. It knows a table of Asian timezones without daylight saving (Singapore, Kuala Lumpur and their neighbours), which covers the teams Penny is offered to today; any other name reads as UTC until the client gains a timezone database. "Now" comes from `clockProvider`, so tests and the demo can stand at any moment.

## Demo data

`DemoStore` (`lib/demo/`) seeds two teams around the current week, from `demo/scenarios/`:

- `studio.dart`, Koh Guitar Studio: Daniel (owner), Mei and six more teachers, 40 students with a parent each, a weekly timetable for this week and next, and today as the designs draw it: a done lesson with a ticked task, a no-show, Mei booked twice at 16:00 and 16:30, a late cancellation with a make-up tomorrow, and a group lesson Mei leads with Aisha assisting. Mei's policy asks for 48 hours and charges late cancellations.
- `solo.dart`, Priya's team of one: five students and lessons on other days, so Today is empty and says when the next lesson is.

`demoOverrides(persona:, clock:)` starts the demo at any moment; widget tests use `designsNow` (Thursday 19 November 2026, 16:20 in Singapore) from `test/support/pump_app.dart`.

## Structure

```text
lib/
  main.dart                    reads the configuration, picks the backend, runs the app
  app/                         composition root: backend_overrides.dart, config, router and guard, shell
  core/                        plain Dart shared by every layer: configuration values, failures, capabilities
  data/                        HTTP plumbing shared by the features' data/ folders
  features/<feature>/
    presentation/              screens and widgets: penny_ui components only
    application/               Riverpod providers and controllers
    domain/                    entities and repository interfaces, plain Dart
    data/                      Http*Repository: wraps the generated client and maps to domain types
  demo/                        Demo*Repository, personas; referenced only by app/backend_overrides.dart
```

`tools/checks` enforces the rules that keep this shape (`task lint:client`): which layer may import which, that only `data/` touches `package:penny_api`, that nothing but the composition root reaches `demo/`, and that no raw colours or literal sizes appear outside penny_ui.

## Adding a repository

1. Declare the interface in `features/<feature>/domain/`.
2. Implement it twice: `data/Http…Repository` and `demo/Demo…Repository`.
3. Add a provider in `application/` that throws until overridden, and override it in both branches of `app/backend_overrides.dart`.
4. Write the behaviour once in `test/contract/<name>_contract.dart` and run it against both implementations in `test/contract/repositories_test.dart`. The HTTP implementation runs against a fake server (`package:http/testing.dart`).

## Navigation and permissions

Routes live in `app/routes.dart`. The guard (`redirectFor`) sends each session state to its one page (loading, sign-in, "Check your email", onboarding) and back to where the person was headed afterwards; it is a pure function with its own tests. Screens needing a capability are wrapped in `CapabilityGate`, which shows "Only the team owner can see this" rather than bouncing. Both are for clarity only: the server refuses unauthorised requests regardless.

Under 600 px wide the shell has a top bar and bottom navigation; from 600 px a sidebar. A team of one hides every team feature.

## Brand assets

The app icon is pixel art generated from `tools/brand/penny_icon.py`; see `assets/brand/README.md`. Platform icons are regenerated with `task gen:icons` (`flutter_launcher_icons` covers Android, iOS, web, Windows and macOS; Linux has no packaged icon yet).

## Tests

`task test:client` runs every test here and in penny_ui. Golden images run on Linux only; `task test:goldens` runs them in Docker from any machine.

| Folder | What it tests |
| --- | --- |
| `test/contract/` | Each repository contract, against the demo and the HTTP implementation (the latter on `test/fakes/`) |
| `test/app/`, `test/features/` | The router guard, and the whole app driven as a person would, at phone and laptop widths (`test/support/pump_app.dart` starts it on demo data) |
| `test/data/` | HTTP plumbing and repositories against a fake API and identity provider |
| `integration_test/` | End to end in a real browser against the real API, a fresh database and the Auth emulator: `task test:e2e` (`tools/e2e/run.sh`) |
