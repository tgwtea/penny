# tools/checks

Rules for the Flutter client that the Dart analyzer cannot express. `task lint:client` runs them; CI fails on any violation.

```sh
cd tools/checks && dart run bin/check_client.dart    # checks apps/client
dart test                                            # the checker's own tests
```

## Boundaries (AGENTS.md, docs/architecture.md "Client")

| Layer (folder) | May import from the app |
| --- | --- |
| `features/*/presentation/` | presentation, application, domain, `core/` |
| `features/*/application/` | application, domain, `core/` |
| `features/*/domain/` | domain, `core/`; plain Dart, no Flutter widgets, Riverpod or penny_ui |
| `features/*/data/`, `data/` | data, domain, `core/` |
| `core/` | `core/` only |
| `demo/` | anything except `app/` |
| `app/`, `main.dart` | anything (the composition root) |

Also:

- Only `data/` may import `package:penny_api`; generated types never leave it.
- Only `data/` and the composition root may import `package:http`.
- Only `app/backend_overrides.dart` may import `lib/demo/`, so deleting the demo needs no other change.

## Design tokens (DESIGN.md, ADR 016)

App code takes colours, spacing, sizes, radii and type from penny_ui. Flagged:

- `Color(...)`, `Color.fromARGB(...)` and `Colors.x` (except `Colors.transparent`)
- numeric literals in `EdgeInsets`, `SizedBox`, `BorderRadius` and `Radius`; zero is allowed
- literal `fontSize`, `letterSpacing`, `fontFamily`, `elevation` or `borderRadius` arguments
- `TextStyle(...)`: start from a `PennyText` style instead

A line ending in `// penny-checks: allow <reason>` is exempt. Prefer adding the missing token or component to penny_ui.
