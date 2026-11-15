# Snackbar

A brief confirmation after an action, with Undo when the action changed data. Flutter: `PennySnackbar` shown through a single app-level messenger.

- The text repeats the action's verb in the past tense ("Lesson marked done", "Moved to Saturday 15:00", "Payment link sent").
- Undo appears for 6 seconds after anything that changes or removes data. No snackbar for actions whose result is already visible and reversible in place.
- `ink` fill, `on-ink` text, `radius-lg`, `shadow-float`. Bottom of the screen above the BottomNav on phone, bottom left of the content on laptop. One at a time.
