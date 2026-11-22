# StatusBadge

The status of a lesson or payment, as icon plus word. Flutter: `StatusBadge` with a `status` enum; the icon, word and colours come from the enum, never from the caller.

- Lesson statuses: Done, Cancelled, No-show, Clash. Lesson tags: Make-up, Shared. Payment statuses: Paid, Open, Overdue. Member status: Invited (someone added to a team who has not signed in yet).
- Scheduled lessons show no badge: scheduled is the default and needs no label.
- Never show a colour without its word and icon. Never invent a new status colour; add to the enum and to the README's status table.
- 24px tall, `radius-xs`, `small-strong` text, 14px icon.
