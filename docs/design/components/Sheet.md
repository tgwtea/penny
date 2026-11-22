# Sheet

How phones create and edit: content rising from the bottom. Flutter: `showPennySheet(context, title:, builder:)`, which wraps the content in `PennySheet` (a heading and a close button).

- Phone only. On laptop the same content opens in a panel beside or above the list (`PennySheet` works there too, with `onClose`).
- `surface-float` with `radius-xl` top corners and a drag handle, above the `scrim`. Rises over 250ms; moves above the keyboard.
- One task per sheet, with its main button last and full width. Closing it discards nothing silently: ask before throwing away typed input.
- Opening a sheet puts away any snackbar still showing, so it never covers the sheet's main button.
