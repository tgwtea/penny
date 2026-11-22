# Chips

A row of chips for picking tutors: one at a time on the phone timetable, several in the laptop timetable's filter. Flutter: `PennyChips<T>` with `chips` (value, label, optional `person` for an avatar), `selected` and `onTap`; the caller decides whether a tap selects one chip or toggles it.

- Use for picking people to show, where a segmented control would have too many options. For two to four views of one thing, use SegmentedControl.
- Unselected chips are `surface` with a `border-control` edge and `text`; selected chips are `ink` with `on-ink` text, like a selected segment.
- `control-height-sm` (36px) inside a 48px hit area, `radius-md`, a small avatar before the label when the chip is a person. Labels are first names, or "Everyone".
- `scrollable` keeps the chips on one line: the row scrolls sideways, never the page (phone). Otherwise they wrap (laptop).
- Every chip is a button with a selected state, so assistive technology says which tutors are shown.
