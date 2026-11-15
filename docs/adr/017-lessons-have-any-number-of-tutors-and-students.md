# ADR 017: Lessons have any number of tutors and students

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

Group lessons and co-taught lessons are real cases; a hard limit would reject real schedules.

## Decision

Lessons carry no tutor or student columns. `lesson_tutors` (with a lead or assisting role) and `lesson_participants` link any number of each. No limit is enforced.

## Consequences

Queries for a tutor's schedule join through `lesson_tutors`. The UI designs for one tutor with one or a few students and degrades to first names plus a "+N" count.
