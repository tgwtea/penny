# ADR 022: Generate the Dart client with space_gen

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

ADR 003 generates the Dart client in `packages/penny_api` from `api/openapi.yaml`. The build plan asked for a spike between `openapi-generator` (dart-dio target, Java) and a pure-Dart generator, keeping whichever handles nullability more cleanly.

Spike on the Phase 1 contract (`/livez`, `/readyz`, `/v1/version`, `/v1/me`):

| | openapi-generator 7.14, dart-dio with json_serializable | space_gen 1.6 |
| --- | --- | --- |
| Nullability | Correct: required fields non-null, optional nullable | Correct, and optional fields are left out of `toJson` with null-aware map entries |
| Models | Mutable classes with annotations; `==` and `hashCode` by summing hashes | `@immutable` with `const` constructors, `Object.hashAll` |
| Build steps after generating | `build_runner` for `json_serializable`, then `dart format` | None: it runs `pub get`, `dart fix` and `dart format` itself |
| Toolchain in CI | Java plus a pinned jar | Dart only, pinned in `tools/codegen/pubspec.yaml` |
| Error responses | `DioException` with an untyped body | `ApiException<Problem>` with the decoded problem |
| HTTP client | `dio` | `package:http`, which takes a test `MockClient` directly |
| Maturity | Large project, many users | Young, one main maintainer |

## Decision

Use space_gen, pinned to an exact version in `tools/codegen`. `task gen:dart` regenerates `packages/penny_api`; the output is committed and checked by `task gen:check`.

## Consequences

Generated models are idiomatic Dart, and the contract job needs no Java. The risk is the project's youth: if it stalls, switching to openapi-generator touches only `packages/penny_api` and the mappers in each feature's `data/` folder, because generated types never leave `data/` (ADR 012).

Generated enums reject unknown values: a response containing a value the client does not know fails to decode. Adding a value to a response enum (for example a new capability) therefore breaks older clients and must be treated as a breaking change in review, even where oasdiff only warns.

The generated client reports transport failures (no connection, TLS errors) as an `ApiException` with status 400 and the cause in `innerException`. The shared mapper in `apps/client/lib/data/api_failures.dart` checks for the inner exception first, so a dropped connection is never mistaken for a rejected request.
