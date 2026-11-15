# LessonBlock

One lesson placed on the timetable grid. Flutter: `LessonBlock` with the lesson view model (start, end, status, students, tutors, kind) and `viewerMembershipId`; the timetable positions it.

- Top is the start time, height is the duration at `timetable-hour` per hour. Minimum visual height is 24px; a 15-minute lesson shows only names.
- Content, in order as space allows: time range (`caption`, tabular), student names (`small-strong`), one meta line (`caption`): the other tutors ("Shared with Aisha"), the location, or "Make-up".
- More than two students: the first two first names, then "+3".
- Colour comes from status only (see the README status table): scheduled `ink-subtle` with an `ink-subtle-edge` border; done `success-subtle` with a check; cancelled `surface-sunken` with struck-through names; no-show `warning-subtle`; clash a 2px `danger` outline, a warning icon and the word "Clash".
- Overlapping lessons for one tutor sit side by side, each half the column width, and both show Clash.
- Tapping opens the lesson detail. Owners can drag a block to move it; the move offers Undo.
