# Contributing

Penny uses trunk-based development. `main` is always deployable; every change reaches it through a pull request with green checks.

## Branches

Short-lived branches off `main`, named by intent:

| Prefix | For |
| --- | --- |
| `feat/` | New behaviour |
| `fix/` | Bug fixes |
| `refactor/` | Changes that keep behaviour |
| `docs/` | Documentation only |
| `chore/` | Tooling, CI, dependencies, repository housekeeping |
| `prototype/` | Throwaway experiments. Never merged into `main` |

Keep branches small enough to review in one sitting. Rebase on `main` rather than merging `main` into your branch.

## Commits and pull request titles

[Conventional Commits](https://www.conventionalcommits.org/), with the component as scope:

```
feat(api): verify Firebase ID tokens
fix(client): keep week view on today after sign-in
chore(repo): pin GitHub Actions by commit SHA
```

| Scope | Covers |
| --- | --- |
| `api` | `services/api/` |
| `client` | `apps/client/` |
| `ui` | `packages/penny_ui/` |
| `contract` | `api/` and generated code |
| `deploy` | `deploy/` |
| `docs` | `docs/` and top-level Markdown |
| `repo` | CI, tooling, repository configuration |
| `deps` | Dependency updates |

Pull requests are squash-merged, so the PR title becomes the commit on `main`. The `pr-title` check enforces the format.

## Pull requests

- One concern per PR. A database migration ships in the same PR as the code that needs it, never alongside unrelated changes.
- Fill in the PR template, including how you verified the change.
- Generated code (`packages/penny_api/`, Go server stubs) is committed. Regenerate with `task gen`; CI fails if the committed output is stale.
- An architectural decision gets an ADR in `docs/adr/` in the same PR (copy `000-template.md`).

## Required checks

Branch protection on `main` requires:

- `ci-ok`: the single gate job in `ci.yml`. It passes only when every component job that ran has passed. Path filters decide which component jobs run, so this one job is what protection points at.
- `pr-title`: Conventional Commits check on the PR title.

`tools/github/apply-ruleset.sh` applies these rules to the GitHub repository.

## Running checks locally

```sh
task lint
task test
```

Both run in CI with the same task definitions and the tool versions pinned in `.mise.toml`.
