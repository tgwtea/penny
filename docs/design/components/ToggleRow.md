# ToggleRow

A setting that is on or off. Flutter: `PennyToggleRow(title:, body:, value:, onChanged:)`.

- For settings that apply straight away or on Save, such as a cancellation policy's "Charge for no-shows". For choosing one of several answers, use OptionRow.
- Title in `body-strong`, what it means in `small` `text-secondary`. The switch sits at the end: `ink` track with an `on-ink` thumb when on, `surface-sunken` track with a `border-control` edge when off; the thumb moves over 150ms.
- The whole row is the target and announces itself as a toggle with its state.
