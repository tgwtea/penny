# ADR 014: Transactional email provider behind a Mailer interface

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Reminders and receipts must reach inboxes. Residential IP ranges are widely blocklisted.

## Decision

Send through a transactional email provider over HTTPS, behind `notify.Mailer`. Mailpit catches all mail locally and in CI. SPF, DKIM and DMARC are configured before the first real email.

## Consequences

Small monthly cost; provider can change by swapping one adapter.
