# MonthGrid

A month of lessons, Monday to Sunday, one cell a day. Flutter: `MonthGrid` with `month`, `today`, `lessonsOn` (the day's `LessonView`s) and `onTapDay`; `compact` for phone widths.

- Whole weeks from Monday to Sunday, so the grid is five or six rows. Days outside the month are `text-tertiary`.
- Today's number sits on `copper-subtle` in `copper-text`, weight 600: the only copper in the grid.
- Laptop: each day lists its first three lessons as "16:00 Arjun" in `caption`, tabular, on the lesson's status ground (as LessonBlock: `ink-subtle`, `success-subtle`, `surface-sunken` struck through, `warning-subtle`; a clash adds a `danger` edge), then "+2 more".
- Phone: a day shows how many lessons it has (cancelled ones are not counted) and a warning icon in `danger` when one clashes.
- Each day is one button whose label says the date, how many lessons and how many clashes ("Thursday 19 November, 5 lessons, 1 clash"). Tapping opens the day.
- The grid sits on `surface` with `hairline` cell lines; no shadows.
