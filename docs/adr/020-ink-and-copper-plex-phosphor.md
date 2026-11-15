# ADR 020: Ink and copper, IBM Plex Sans, Phosphor icons

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

ADR 016 commits Penny to its own design system. The first draft of the principles called for a muted copper accent on warm neutrals. Cream grounds with a clay or copper accent are among the most common looks of generated interfaces, which the product owner explicitly wants to avoid. A timetable also needs status colours (done, no-show, clash) that an orange accent would compete with.

## Decision

- Cool white and grey surfaces; deep `ink` (#1C2B3A light, #E6EBF1 dark) for text, the primary button and selection.
- `copper` (#B4532A light, #E07A4A dark) only for now and today: the current-time line, today's date and the brand mark. Never for buttons, links or status.
- Status colours only on statuses, each with a word and an icon. Lesson blocks are coloured by status, never by person.
- IBM Plex Sans at weights 400 and 600, tabular figures for times and money, bundled with the app.
- Phosphor icons, Regular weight, Fill for the active navigation item (`phosphor_flutter`).
- Every text and control pairing meets WCAG AA in light and dark; values were checked when the tokens were set.

## Consequences

The UI reads as calm and distinct, with copper acting as a "you are here" marker. Tokens live in `docs/design/tokens.json` and generate the Flutter theme, so a change of direction is a token change. Changing the accent's role (for example using copper for buttons) needs a new ADR.
