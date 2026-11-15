# EmptyState

What a screen says when it has nothing to show. Flutter: `PennyEmptyState` with `title`, `body`, optional `action`, optional `art`.

- The title says what is empty in plain words ("No lessons today", "No students yet"). The body points to what is next or why ("Your next lesson is Friday at 15:30."). The action is the obvious next step.
- Left-aligned in lists and panels, starting `space-12` from the top. The art slot is the one place pixel art appears inside the working UI: 64 by 64, scaled by whole numbers. Until the pixel art exists, leave the slot out rather than using a stock illustration.
- Filtered-empty is different from empty: "No lessons match these filters" with a Clear filters action.
