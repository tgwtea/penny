# SegmentedControl

Switches between two to four views of the same content. Flutter: `PennySegmented<T>` with `segments` (value and label) and `selected`.

- Use for views of one thing (Day, Week, Month; Mine, Whole team). For navigation between different things, use navigation instead.
- Labels are one or two words. No icons unless every segment has one.
- The track is `surface-sunken`; the selected segment is `surface` with a `hairline` ring and `text`; others are `text-secondary`.
- 40px segments on phone inside a 48px hit area; `control-height-sm` on laptop toolbars.
- "Whole team" only appears for owners in a team with more than one member.
