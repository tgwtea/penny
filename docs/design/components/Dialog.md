# Dialog

A floating panel that asks one question or holds one short task. Flutter: `PennyDialog`; for yes-or-no questions, `showPennyConfirmation(context, title:, body:, confirmLabel:, destructive:)`, which resolves to `true` only when the person confirms.

- Use it to confirm destructive actions (cancel lesson, void receipt, delete account) and say exactly what will happen in the body. Prefer Undo in a snackbar for anything that can be undone.
- The title is the question ("Delete your account?"); the confirm button repeats its verb ("Delete account"); the other button is "Cancel" or names what is kept ("Keep lesson").
- `surface-float` panel, `radius-xl`, `shadow-overlay`, above the `scrim`. At most 440px wide; `space-6` padding. Actions sit at the bottom right, main action last; `danger` variant for destructive confirmations.
- Fades in over 200ms (`PennyMotion.standard`). Tapping the scrim or pressing Escape cancels.
