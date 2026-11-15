# ADR 016: Penny's own design system

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The client must look simple, intuitive and deliberately designed, not like a stock template or a generated app.

## Decision

Design tokens and components first, then key screens, before coding UI. Implement them in `packages/penny_ui` on Material 3, with a Widgetbook catalogue and golden-image tests. Feature code may not use raw colours or literal spacing.

## Consequences

Slower start to UI work, consistent result. Visual regressions fail CI.
