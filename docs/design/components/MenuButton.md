# MenuButton

An icon button that opens a short menu of actions on one thing. Flutter: `PennyMenuButton(tooltip:, items: [PennyMenuItem(label:, icon:, destructive:, onSelected:)])`.

- The tooltip names the thing: "Actions for Mei Lin Tan".
- Items are verbs that say what happens: "Make owner", "Remove from team". Destructive items are shown in `danger` and still confirm with a Dialog before acting.
- The menu floats on `surface-float` with a `hairline` edge, `radius-lg`. Keep it to a handful of items; more means the thing needs its own detail view.
