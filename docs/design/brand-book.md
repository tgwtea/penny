Penny is the admin side of tutoring, kept in order: who teaches whom, when and where, and who has paid. People open it between lessons, often on a phone, to answer one question and leave. Every rule below serves that: answer fast, never surprise, never look like a template.

The look is **ink and copper**. Cool white surfaces and deep ink do the work; copper, the colour of the penny, appears only where something is happening now. Spend no other colour unless it means a status.

## Voice and copy

- Plain verbs, sentence case, no exclamation marks, no emoji. "Mark done", not "Complete lesson!".
- Name things the way tutors do: lesson, student, parent, tutor, team, payment request, receipt. Never "event", "resource", "workspace" or "entity". The UI says "Team" for what the code calls a workspace.
- Buttons say exactly what happens, and the result uses the same verb: "Mark done" produces "Lesson marked done".
- Address the user as "you". Penny does not speak as "I" or "we".
- Errors say what happened and what to do, without apology: "This lesson overlaps Ravi's 16:00 lesson. Save anyway or pick another time."
- Empty states invite the next action: "No lessons today. Your next one is Friday at 15:30."
- Times are 24-hour or 12-hour per the device setting, always in the team's timezone. Dates read "Thu 19 Nov" in tight spaces, "Thursday 19 November" in titles. Money reads "S$ 240.00".
- No ALL-CAPS labels, no eyebrow labels above headings, no "→" after link text, no middle-dot chains of metadata. Use a line break or a comma.

## Colour

- Page background is `canvas`; content sits on `surface`. On phone most screens are a single `surface` list on `canvas`.
- Text is `text`; supporting text `text-secondary`; timestamps, hour labels and placeholders `text-tertiary`. Each meets 4.5:1 on the grounds its token note names, in both themes.
- `ink` is the working colour: the one primary button per screen, the active navigation item, selected segments. Text on it is `on-ink`.
- `copper` means now and today, nothing else: the current-time line, today's date marker, today's column header (`copper-subtle` behind `copper-text`), and the brand mark. Never use copper for a button, a link, a status or decoration.
- Status colours (`success`, `warning`, `danger` and their `-subtle` grounds) appear only on statuses, and every status also carries an icon and a word, so colour is never the only signal.
- Lesson blocks are coloured by status, never by tutor or student. Columns and names identify people; colour stays meaningful.
- Dark theme is a full theme, not an inversion: use the same token names; the values change.

## Type

- One family, IBM Plex Sans, at two weights: 400 and 600. Load Regular, Italic and SemiBold. No other weights, no second family.
- Use the text styles by name: `display` (at most one per screen), `title`, `heading`, `body`, `body-strong`, `small`, `small-strong`, `caption`.
- Every time and amount uses tabular figures: `time`, `time-lg`, `amount`, or `tnum` on any other style that shows digits in a column.
- Left-align everything except numerals in tables, which right-align. Never centre body text; centre only an empty state's illustration.
- Keep lines under 72 characters in notes and long text.

## Space, size and radius

- Lay out on the 4px grid with `space-*` tokens only. Phone screens have `space-4` side margins; laptop content has `space-8`.
- Every interactive element has at least a `touch-target` (48px) hit area, even when it draws smaller.
- Inputs and buttons are `control-height` (44px); `control-height-sm` only on laptop toolbars.
- Radius follows hierarchy: `radius-xs` for badges, `radius-sm` for lesson blocks, `radius-md` for controls, `radius-lg` for panels and snackbars, `radius-xl` for dialogs and sheet tops, `radius-full` for avatars only.

## Surfaces and elevation

- Flat by default. Separate content with spacing first, then a `hairline` divider. Do not put each item in its own card.
- Only floating layers get shadows: `shadow-float` for menus, popovers and snackbars on `surface-float`; `shadow-overlay` for sheets and dialogs above `scrim`.
- No gradients, no glass, no coloured left borders on cards.

## Status

| Status | Ground | Mark | Word |
| --- | --- | --- | --- |
| Scheduled | `ink-subtle` with `ink-subtle-edge` | none | none (default) |
| Completed | `success-subtle` | check in `success` | "Done" |
| Cancelled | `surface-sunken`, names struck through in `text-tertiary` | x | "Cancelled" |
| No-show | `warning-subtle` | user-minus in `warning` | "No-show" |
| Clash | 2px `danger` outline on the block | warning in `danger` | "Clash" |
| Make-up | as its status | arrow-counter-clockwise | "Make-up" tag |
| Shared (several tutors) | as its status | users | "Shared" tag, all tutor names in the detail |
| Paid / Open / Overdue | `success-subtle` / `surface-sunken` / `danger-subtle` | check / clock / warning | "Paid" / "Open" / "Overdue" |

A clash warns; it never blocks saving.

## Motion

- Motion only answers an action: a sheet rising, a lesson moving to its new slot, a row collapsing after "Mark done". 150ms for small changes, 200ms standard, 250ms for sheets; ease out on enter, ease in on exit.
- No entrance animations on screen load, no looping motion. Respect the system's reduce-motion setting by cutting to the end state.
- Changes that remove or move something offer Undo in a snackbar for 6 seconds.

## Iconography

- Phosphor Icons, Regular weight, 20px in rows and buttons, 24px in navigation. Active navigation items switch to the Fill weight. Flutter: the `phosphor_flutter` package.
- Icons sit beside a word except in the bottom navigation (which has labels) and icon buttons (which have tooltips and semantic labels).
- Icons take `text-secondary` by default, the status colour inside a status, `on-ink` on ink.

## Brand mark

- The app icon is pixel art of a hand flipping a penny. It is not in this system yet; until it is supplied, the name is set in type: "Penny" in `display` weight 600.
- Pixel art appears only at brand moments: the app icon, splash, sign-in and empty states. Scale it by whole-number factors with nearest-neighbour sampling. The working UI is clean vector throughout.

## Layout

- **Phone (under 600px):** top bar with the screen title and the account avatar; bottom navigation with Today, Calendar, Students, Payments, and Team for owners. One column. Sheets for creating and editing.
- **Tablet and laptop (600px and up):** `sidebar-width` sidebar with the team switcher at the top, navigation, and the account at the bottom. Content is capped at `content-max` except the timetable, which uses the full width. Detail opens in a side panel beside the list, not a new page.
- The team timetable shows every tutor side by side on wide screens. On phone it shows one tutor at a time with a switcher. Never scroll the page horizontally.
- A team of one hides every team feature: no Team tab, no tutor columns, no tutor names on lessons.

## States

Design and build every screen in five states:

- **Empty:** says why it is empty and offers the next action.
- **Loading:** skeleton rows shaped like the content, in `surface-sunken`, no spinners for lists. Show cached content immediately when there is any.
- **Populated:** the normal case, tested with long names, several tutors and several students per lesson.
- **Error:** what failed and a retry, in place; never a blank screen.
- **No permission:** "Only the team owner can see this." with a way back. The server refuses too; the client message is for clarity.

## Accessibility

- Text 4.5:1, large text and control boundaries 3:1, in both themes. The tokens are tuned for it; do not tint them.
- Keyboard focus is a solid 2px `focus-ring` (copper), offset 2px, on every focusable element.
- Layouts survive 200% text size: rows grow taller, nothing truncates mid-word without an ellipsis and a way to see the full text.
- Every icon-only control has a semantic label. Every status has a word.

## Building it in Flutter

- Implement this system in `packages/penny_ui`. Feature code uses only its widgets, `Theme.of(context)` and the `PennyTokens` theme extension; raw `Color(...)`, literal paddings and literal font sizes outside `penny_ui` fail lint.
- Map tokens to Flutter like this: colours into a `PennyColors` `ThemeExtension` (light and dark instances) and the `ColorScheme` (`primary` = `ink`, `onPrimary` = `on-ink`, `surface` = `surface`, `error` = `danger`); text styles into `TextTheme` plus a `PennyText` extension for `time`, `time-lg` and `amount` with `FontFeature.tabularFigures()`; spacing, radius and size as `const double` values in `PennySpace`, `PennyRadius` and `PennySize`.
- Bundle the IBM Plex Sans font files as assets (OFL licence). Do not fetch fonts at runtime.
- Components in this system name their Flutter widget in their guidelines (`PennyButton`, `LessonBlock`, ...). Build each with a Widgetbook entry per state and a golden test per state, light and dark.
