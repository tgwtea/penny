# LessonRow

One lesson in a list, used on Today and in agenda views. Flutter: `LessonRow` with the lesson view model, `onTap`, `onMarkDone` (null when the viewer may not mark it).

- The left column is the time spine: start in `time-lg`, end in `caption`, both tabular. Past lessons fade the start time to `text-tertiary`.
- The middle column: student names (`body-strong`), one meta line (`small`, `text-secondary`) with an icon: location, "Online", or the other tutors. Then badges for anything not scheduled.
- The right column: a quiet Mark done icon button for the lesson's tutors and the owner. Marking done collapses the row's action, shows the Done badge and a snackbar with Undo.
- On today's list, the **now line** sits between the last started lesson and the next: a 2px `copper` line with a dot, and the current time in `copper-text`. It moves every minute. It is the only copper on the screen.
- Rows are separated by `hairline` dividers on one `surface`; no cards.
