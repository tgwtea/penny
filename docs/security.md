# Security review: OWASP ASVS Level 1

docs/architecture.md makes ASVS 4.0 Level 1 the checklist before the first real user. This is the review of the code as of 22 Nov 2026, chapter by chapter: what meets the requirement, how, and what is left. Re-run it before launch and after any change to authentication, authorization or a public endpoint.

Status: **met**, **partly** (met with a known gap, listed under follow-ups), or **n/a**.

| Chapter | Status | How |
| --- | --- | --- |
| V1 Architecture | met | Threat boundaries are written down: one contract (`api/openapi.yaml`), authorization in one package (`authz`), SQL only in module stores, tenant scoping by `workspace_id` everywhere (docs/architecture.md) |
| V2 Authentication | partly | Delegated to Firebase Authentication (ADR 004): password rules, breached-password checks, rate limits and recovery are Firebase's. The API verifies every ID token's signature, issuer, audience and expiry, and refuses unverified emails. Firebase's own settings are part of [the setup runbook](runbooks/firebase-auth-setup.md) |
| V3 Session management | met | No server sessions or cookies: each request carries a short-lived Firebase ID token as a bearer token. Signing out discards it on the client; deleting an account removes the Firebase user |
| V4 Access control | met | Operations are secured unless the contract marks them public. Every service method checks `authz` before acting; teachers are scoped to their own lessons, students and payments, with 404 for records they may not know exist. Row-level security (migration 00011) refuses another team's rows to the app role even if a query forgets its filter; tests run the API as that role |
| V5 Validation, sanitisation and encoding | met | The generated strict server decodes only the contract's shapes; services validate lengths, formats and states. All SQL is parameterised (sqlc). Emails use `html/template`; receipts are PDFs drawn as text. Request bodies are capped at 1 MiB |
| V6 Cryptography | met | Public tokens (payment links, calendar feeds) are 128 random bits from `crypto/rand`, stored only as SHA-256 hashes. Unsubscribe links are HMAC-SHA256 signed with a secret of at least 32 characters. Receipts carry the SHA-256 of their PDF |
| V7 Errors and logging | met | Errors are RFC 9457 problems without internals; unexpected ones are logged in full server-side only. Logs carry request, team and user IDs, never names, emails or tokens. The audit log is append-only for every role |
| V8 Data protection | met | Responses are `Cache-Control: no-store`. The only secrets in URLs are the public tokens that are the credential by design, and `Referrer-Policy: no-referrer` keeps them from leaking onwards. The public payment page shows a student's first name only. Personal data and its retention: [docs/privacy.md](privacy.md) |
| V9 Communications | met | TLS terminates at the ingress; the API sends `Strict-Transport-Security`. The database is reached inside the cluster over its own network policy |
| V10 Malicious code | partly | Dependencies are pinned with checksums (`go.sum`, `pubspec.lock`); release images are scanned with Trivy. No scheduled vulnerability scan of the Go and Dart dependencies yet |
| V11 Business logic | met | State changes follow explicit lifecycles (lessons, requests, receipts) checked in the service. Payment writes are idempotent by `Idempotency-Key`. A request closes only when both sides confirm (ADR 024). Receipt numbers are gapless and receipts immutable |
| V12 Files and resources | n/a | Nothing is uploaded. Receipts are generated, not stored as files |
| V13 API | met | CORS allows only the configured origins; unknown routes and methods are problems (404, 405). Public operations are rate-limited per client (60 reads and 10 writes a minute, in bursts of 30 and 5) |
| V14 Configuration | met | Settings come from the environment and are validated at start-up; secrets are sealed. Security headers on every response: `X-Content-Type-Options`, `Content-Security-Policy: default-src 'none'`, `Referrer-Policy`, HSTS |

## Follow-ups

- **Rate limits are per replica**, in memory. With several API replicas a client gets that many times the rate. Add an ingress rate limit (Traefik middleware) in the deploy overlay before launch. `PENNY_TRUSTED_PROXIES` must name the ingress, or every request through it counts as one client.
- **Signed-in endpoints have no per-account rate limit.** Firebase limits sign-in itself; add one if abuse shows up.
- **Owners are not required to use multi-factor authentication.** Firebase supports it; requiring it for owners is a product decision.
- **No scheduled dependency scan.** Add `govulncheck` and a Dart advisory check to CI.
- **Local development connects as a superuser,** which row-level security does not bind. The API tests run as the app role, so the policies are still checked on every change.
- **The web client's own headers** (CSP for the Flutter web build) are set by its static host in `deploy/base/web`; review them with the first production deploy.
