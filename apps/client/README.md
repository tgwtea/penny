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

The web image is built once and promoted between environments, so it reads the API address at run time from `/config.json`, which nginx writes from `PENNY_API_URL` when the container starts (`Dockerfile`, `nginx/`).

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

Routes live in `app/routes.dart`. The guard (`redirectFor`) sends signed-out people to sign-in and back again afterwards; it is a pure function with its own tests. Screens needing a capability are wrapped in `CapabilityGate`, which shows "Only the team owner can see this" rather than bouncing. Both are for clarity only: the server refuses unauthorised requests regardless.

Under 600 px wide the shell has a top bar and bottom navigation; from 600 px a sidebar. A team of one hides every team feature.

## Brand assets

The app icon is pixel art generated from `tools/brand/penny_icon.py`; see `assets/brand/README.md`. Platform icons are regenerated with `task gen:icons` (`flutter_launcher_icons` covers Android, iOS, web, Windows and macOS; Linux has no packaged icon yet).

## Tests

`task test:client` runs every test here and in penny_ui. Golden images run on Linux only; `task test:goldens` runs them in Docker from any machine.
