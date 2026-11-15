# Button

One action, named by its verb. Flutter: `PennyButton` with `variant` (`primary`, `secondary`, `quiet`, `danger`), `size` (`standard` 44px, `large` 48px), optional leading `icon`, and `onPressed` (null = disabled).

- **Primary** (`ink` fill, `on-ink` text): at most one per screen, for the thing the screen is for ("Add lesson", "Send payment link").
- **Secondary** (`surface`, `border-control` edge): alternatives beside a primary ("Reschedule").
- **Quiet** (no fill): row-level and toolbar actions ("Mark done"). Icon plus word.
- **Danger** (`danger` text and edge): destructive actions, always followed by a confirmation that says what will happen.
- **Icon-only**: square, `text-secondary` icon, a tooltip and a semantic label are required.

Labels are verbs in sentence case, never "OK" or "Submit". Full width only inside sheets on phone. Hit area is at least `touch-target`. Focus shows the 2px `focus-ring`, offset 2px. Hover and pressed states are an 8% and 12% overlay of the label colour; no colour change.
