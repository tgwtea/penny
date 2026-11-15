# TextField

A labelled single-line input. Flutter: `PennyTextField` with `label` (required, always visible above the field), `hint`, `error`, `placeholder`, `keyboardType`, and the usual controller and callbacks.

- The label is always shown above the input; never use the placeholder as the label.
- `hint` explains why the value is needed or where it goes. `error` replaces the hint, starts with what to do, and adds a warning icon so the colour is not the only signal.
- Validate on blur and on submit, never while the person is still typing.
- 44px tall (`control-height`), `radius-md`, `border-control` edge, `surface` fill. Focus: 2px `focus-ring`. Error: 2px `danger` edge.
- Phone numbers, amounts and times use numeric keyboards and tabular figures.
