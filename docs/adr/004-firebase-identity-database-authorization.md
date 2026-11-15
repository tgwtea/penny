# ADR 004: Firebase Auth proves identity; Penny's database owns authorization

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Penny needs email/password and Google sign-in without storing passwords, and roles that differ per team.

## Decision

Firebase Auth handles both sign-in methods and issues ID tokens. The API verifies tokens behind an `identity.Verifier` interface. Users, memberships, roles and capabilities live in Postgres. Roles are not stored in Firebase custom claims, which are cached in tokens for up to an hour and cannot express per-team roles.

## Consequences

No password storage, reset or breach handling to build. Firebase is a dependency, contained behind one interface on each side, so a self-hosted OIDC provider can replace it later.
