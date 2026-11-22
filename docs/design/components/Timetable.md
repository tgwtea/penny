# Timetable

A day or week of lessons on a time grid, one column per tutor (team day view) or per day (week view). Flutter: `Timetable` with `columns` (tutors or days), `lessons`, `range` (start and end hour), `now`, and callbacks for tapping a lesson or an empty slot.

- Time runs down the `timetable-gutter` on the left in `caption`, tabular. One hour is `timetable-hour` (64px); a `hairline` marks each hour.
- **Free time is empty `surface`.** Nothing is drawn in a free slot, so "who is free on Thursday at 5pm?" is answered by looking for white. For people who may add lessons, hovering a free slot shows a dashed "Add lesson at 16:00" ghost, half an hour tall, on the 15-minute slot under the pointer; tapping (or, on touch, tapping straight away) opens Add lesson at that time for that column's tutor.
- Column headers show the tutor's avatar, name and a count ("4 lessons, 1 clash"). In week view the header is the day, and today's header is `copper-subtle` with `copper-text`.
- The **now line** crosses all columns at the current time: 2px `copper`, a dot at the left, the time in `copper-text` in the gutter. Shown only when the visible range contains now.
- Lessons are `LessonBlock`s. A shared lesson appears in each of its tutors' columns. Overlaps in one column sit side by side and show Clash.
- Laptop: every tutor side by side, columns share the width equally with a 120px minimum; beyond that the grid (not the page) scrolls horizontally with the gutter pinned. Phone: one tutor at a time with a tutor switcher above the grid; swipe changes tutor.
- Default range is the team's earliest to latest lesson that week, padded by an hour, scrolled to now on open.
