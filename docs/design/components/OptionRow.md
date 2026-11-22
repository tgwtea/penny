# OptionRow

One answer in a single-choice question. Flutter: `PennyOptionRow(title:, body:, selected:, onSelected:)`.

- Use it when the choice needs a sentence of explanation, such as onboarding's "Do you teach on your own, or run a team?". For two or three short words side by side, use SegmentedControl.
- The whole row is the target (at least 48px tall). Exactly one row in a group is selected.
- Unselected: `surface` with a `border-control` edge and the empty option mark in `text-secondary`. Selected: `ink-subtle` with an `ink-subtle-edge` edge and the filled mark in `ink`. `radius-md`, `space-4` padding.
- The title is `body-strong`, the body `small` in `text-secondary`. Announced as one choice in a group, checked or not.
