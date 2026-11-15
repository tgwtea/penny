# Design principles

Penny should look simple, feel obvious, and never look generated. These principles turn that goal into rules that can be checked in review. The design system (tokens and components) will live in `packages/penny_ui`; until it exists, these rules are the reference.

> **Status:** first version of the design system and key screens is done. Build from [`docs/design/`](docs/design/README.md): tokens, the full brand book, component guidelines and the screen inventory. This page is the short version.

## Rules

| Avoid | Penny's rule |
| --- | --- |
| Stock Material colours, purple gradients, glowing accents; cream backgrounds with a clay accent | Ink and copper: cool white surfaces, deep `ink` for text and primary actions, and `copper` only for now and today (the current-time line, today's date). Other colour only means a status, always with a word and an icon |
| Every element in its own card with a shadow | Flat surfaces separated by spacing and hairline dividers. Elevation only for things that float: menus, sheets, dialogs |
| Inconsistent spacing and sizes | A 4 px grid, a fixed spacing scale and one radius scale, all from tokens. No literal numbers in feature code |
| Many fonts, weights and sizes | One typeface family, a six-step type scale, two weights, tabular numerals for times and money |
| Emoji and mixed icon sets | One icon set at one stroke weight |
| Decorative animation | Motion only for continuity (a sheet rising, a lesson being moved), 150 to 250 ms |
| Screens that only cover the happy path | Every screen designed in five states: empty, loading, populated, error, no permission |
| Marketing layouts in a work tool | Dense, scannable layouts. The timetable should feel like a good calendar, not a landing page |

## Brand

The app icon is pixel art of a hand flipping a penny. Pixel art appears only at brand moments: app icon, splash, sign-in and empty states. The working UI is clean vector. Scale pixel art only by whole-number factors with nearest-neighbour sampling.

## Usability

- The three most frequent jobs (see today's lessons, mark a lesson done, find a free slot) each take one tap or click from Home.
- Touch targets at least 48 px. WCAG 2.2 AA contrast in light and dark themes. Layouts survive 200% text size.
- Times are always shown in the team's timezone, in the device's 12-hour or 24-hour convention.
- Destructive actions say what will happen before confirming; lesson changes offer undo.
- Lessons can have several tutors and several students. Show first names and a "+N" count when space runs out; never truncate silently.
