# Rules for coding agents

Read this before changing anything in this repository. Humans follow the same rules; this file just states them explicitly.

## Before you start

1. Read `docs/architecture.md`, at least the sections for the components you will touch.
2. Read any ADR in `docs/adr/` that covers the area.
3. For UI work, read `DESIGN.md`. Do not introduce colours, sizes, fonts or icons that are not in `packages/penny_ui`.
4. If the task is ambiguous or conflicts with an ADR, stop and ask. Do not resolve a conflict with an ADR silently.

## Boundaries

- `apps/` and `services/` never import from each other. The contract in `api/openapi.yaml` is the only shared surface.
- Generated code (`packages/penny_api/`, Go server stubs) is never edited by hand. Change the contract, then run `task gen`.
- Go: handlers decode and map; services hold business rules, transactions and authorization checks; stores hold SQL and are always scoped by `workspace_id`.
- Flutter: `presentation` may import `application` and `domain` only. Only `data/` may import `package:penny_api`. `demo/` is only referenced from the composition root.
- Every authorization decision goes through the `authz` package. Client-side checks are for display only.
- Money is integer cents. Timestamps are UTC `timestamptz`. IDs are UUIDv7.

## Git

- Never commit to `main`. Branch with a prefix from `CONTRIBUTING.md`.
- Conventional Commits with a component scope.
- One concern per commit and per PR.
- Do not add dependencies without saying so in the PR description, with the reason no existing dependency fits.

## Commands

| Task | Command |
| --- | --- |
| Install toolchain | `mise install` |
| Local services | `task dev`, `task dev:down` |
| Lint everything | `task lint` |
| Test everything | `task test` |
| Regenerate code from the contract | `task gen` |

Run `task lint` and `task test` before declaring work done.

## Completion summary

End every piece of work with:

1. **Changed**: files and behaviour, one line each.
2. **Verified**: the commands you ran and their results. Say plainly if something could not be verified and why.
3. **Not done / follow-ups**: anything skipped, deferred or uncertain.
4. **Decisions**: any choice that was not dictated by the task or an ADR, and whether it needs an ADR.
