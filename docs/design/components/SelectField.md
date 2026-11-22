# SelectField

A labelled field whose value is chosen, not typed: a date, a time, a tutor, a place, a lesson's length. Flutter: `PennySelectField(label:, value:, placeholder:, hint:, error:, onTap:, icon:)`.

- Looks like TextField: the label is always above, the field is `control-height` with `radius-md`, `border-control` and `surface`; an error gives it a 2px `danger` edge and replaces the hint, with the warning icon.
- The mark at the end says what opens: a caret for a list (`showPennyChoice`), the calendar for a date, the clock for a time.
- `showPennyChoice` shows the choices as OptionRows in a sheet and resolves to the one picked.
- Times and amounts set `tabularFigures`.
