# ADR 010: PostGIS for locations

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Lessons happen at studios, students' homes or online. Travel-time and distance features are likely later.

## Decision

Enable PostGIS from the first migration and store in-person locations with a geography point alongside the structured address.

## Consequences

Distance queries need no data migration later. The local and production images must include PostGIS.
