# ADR 008: CloudNativePG for PostgreSQL

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The database needs failover, backups and point-in-time recovery on a three-node homelab without shared storage.

## Decision

Run PostgreSQL 18 with the CloudNativePG operator: three instances, one per node, on local storage, with continuous WAL archiving and base backups to off-site S3-compatible storage.

## Consequences

Failover and backups come from the operator. A monthly restore drill is mandatory, since an untested backup is not a backup.
