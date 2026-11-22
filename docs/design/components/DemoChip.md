# DemoChip

The look of every demo-only control. Flutter: `PennyDemoChip(label:, onPressed:)`.

- Dashed `warning` border on `warning-subtle`, the flask icon and the words "Demo data", then `label`. It must never look like part of the product.
- With `onPressed` it shows a caret and opens the demo control (the persona list); without, it labels a demo-only section.
- Used by the persona switcher (see DemoPersonaSwitcher). Nothing outside demo builds shows it.
