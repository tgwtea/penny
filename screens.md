# Screen inventory

Each row is one artboard in the [Penny key screens](https://claude.ai/artifact/V1uvDiMuTjJ9YCapXr2vZZ) canvas. Routes are suggestions for go_router; capabilities refer to the `authz` matrix in `docs/architecture.md`.

| Artboard | Width | Route | Who sees it | State shown | Components used |
| --- | --- | --- | --- | --- | --- |
| Sign in | 390 | `/sign-in` | Signed out | Populated | Button, TextField |
| Onboarding: solo or team | 390 | `/onboarding/team` | New user | "I run a team" selected | Button, TextField, option rows (radio) |
| Today, owner (`Main`) | 390 | `/today` | Everyone | Populated, with now line, clash and overdue notices | LessonRow, StatusBadge, SegmentedControl, Notice, BottomNav |
| Today, empty (solo tutor) | 390 | `/today` | Solo tutor | Empty | EmptyState, BottomNav (4 items) |
| Today, loading and error | 390 | `/today` | Everyone | Loading skeleton, then refresh-failed notice | Skeleton rows, Notice |
| No permission (teacher) | 390 | `/team` | Teacher typing an owner URL | No permission | Button, BottomNav (4 items) |
| Calendar: team day, one tutor at a time | 390 | `/calendar?view=day&tutor=…` | Owner | Populated, clash, ghost slot, now line | DateNavigator, SegmentedControl, tutor chips, Timetable |
| Lesson details: shared group lesson | 390 | `/lessons/:id` | Owner, tutors on the lesson | Populated, co-taught billing notice | Notice, StatusBadge, Avatar, checklist, Button |
| Students | 390 | `/students` | Owner (all), teacher (own) | Populated, overdue badges | TextField (search), SegmentedControl, Avatar, StatusBadge |
| Payment request | 390 | `/payments/:id` | Owner, the payee | Open, link sent, no payments yet | StatusBadge, Button |
| Public payment page (parent) | 390 | `/pay/:token` (public) | Anyone with the link | Open | Button, QR |
| Team timetable, day (owner) | 1440 | `/calendar?view=day&scope=team` | Owner | 8 tutors, a free day, cancelled, no-show, clash, shared lesson, now line | Sidebar, DateNavigator, SegmentedControl, Timetable, StatusBadge |
| Week, teacher's own lessons | 1440 | `/calendar?view=week` | Teacher (shown via the demo persona switcher) | Week with today highlighted | Sidebar (no Team), DemoPersonaSwitcher, Timetable |
| Team list and add teacher | 1440 | `/team` | Owner | Populated, add form open | Sidebar, table, TextField, Notice, Button |
| Payments | 1440 | `/payments` | Owner (all), teacher (as payee) | Populated, open, overdue, paid | Sidebar, SegmentedControl, table, StatusBadge |

## Still to design

The design track's definition of done is every key screen in all five states at both widths. This first pass covers each screen once, plus the empty, loading, error and no-permission states on Today and Team. Still to draw, before or during Phase 2:

- Laptop versions of Today, Students, Lesson details (as a side panel) and Payment request.
- Phone versions of Team list and Payments.
- Empty, loading and error states for Calendar, Students and Payments.
- Create and edit flows: add lesson (sheet on phone, panel on laptop), reschedule, cancel with make-up, record payment, add student.
- Month view.
