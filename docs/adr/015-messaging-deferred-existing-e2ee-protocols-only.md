# ADR 015: Messaging deferred; existing E2EE protocols only

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

End-to-end encrypted messaging between two people was requested, last in priority.

## Decision

Build nothing until email alerts are insufficient. When built, use an existing protocol and library (Signal protocol, MLS or Matrix), never custom cryptography, and decide the safeguarding policy for conversations with minors first.

## Consequences

No messaging code or tables now; only the package name is reserved.
