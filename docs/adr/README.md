# Architecture decision records

One file per decision. Copy `000-template.md` to propose a new one in the same PR as the change it governs. Decisions are not edited after acceptance; a new ADR supersedes an old one.

| ADR | Decision | Status |
| --- | --- | --- |
| [001](001-one-monorepo-with-path-filtered-ci.md) | One monorepo with path-filtered CI | Accepted |
| [002](002-modular-monolith-one-go-module-api-and-worker-binaries.md) | Modular monolith: one Go module, api and worker binaries | Accepted |
| [003](003-contract-first-api-in-openapi-3-0-3.md) | Contract-first API in OpenAPI 3.0.3 | Accepted |
| [004](004-firebase-identity-database-authorization.md) | Firebase Auth proves identity; Penny's database owns authorization | Accepted |
| [005](005-pgx-and-sqlc-for-data-access.md) | pgx and sqlc for data access | Accepted |
| [006](006-goose-migrations-forward-only-run-as-a-pre-deploy-job.md) | goose migrations, forward-only, run as a pre-deploy Job | Accepted |
| [007](007-river-for-background-jobs.md) | River for background jobs | Accepted |
| [008](008-cloudnativepg-for-postgresql.md) | CloudNativePG for PostgreSQL | Accepted |
| [009](009-no-graph-extension.md) | No graph extension | Accepted |
| [010](010-postgis-for-locations.md) | PostGIS for locations | Accepted |
| [011](011-riverpod-and-go-router-in-the-client.md) | Riverpod and go_router in the client | Accepted |
| [012](012-swappable-client-backend.md) | Swappable client backend | Accepted |
| [013](013-gitops-deployment-with-argocd.md) | GitOps deployment with ArgoCD | Accepted |
| [014](014-transactional-email-provider-behind-a-mailer-interface.md) | Transactional email provider behind a Mailer interface | Accepted |
| [015](015-messaging-deferred-existing-e2ee-protocols-only.md) | Messaging deferred; existing E2EE protocols only | Accepted |
| [016](016-own-design-system.md) | Penny's own design system | Accepted |
| [017](017-lessons-have-any-number-of-tutors-and-students.md) | Lessons have any number of tutors and students | Accepted |
| [018](018-co-taught-billing-by-lead-tutor.md) | Co-taught lessons are billed by the lead tutor; splits happen outside Penny | Accepted |
| [019](019-clashes-warn-never-block.md) | Clashes warn, never block | Accepted |
| [020](020-ink-and-copper-plex-phosphor.md) | Ink and copper, IBM Plex Sans, Phosphor icons | Accepted; icon package superseded by 021 |
| [021](021-bundle-phosphor-icon-fonts.md) | Bundle the Phosphor icon fonts in penny_ui (supersedes ADR 020's package choice) | Accepted |
| [022](022-space-gen-for-the-dart-client.md) | Generate the Dart client with space_gen | Accepted |
| [023](023-stay-on-the-sdk-material-library.md) | Stay on the SDK's Material library until the catalogue can move | Accepted |
| [024](024-payment-requests-close-on-mutual-confirmation.md) | Payment requests close on mutual confirmation; teachers bill their own lessons | Accepted |
