# ADR 013: GitOps deployment with ArgoCD

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The cluster is on a home network with no inbound access, and every production change should be reviewed and revertible.

## Decision

ArgoCD pulls manifests from `deploy/`. CI builds images and commits new digests to the dev overlay; promotion to prod is a pull request.

## Consequences

CI never needs credentials for the cluster. Image digest bumps appear as commits in history.
