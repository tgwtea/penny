# Screen inventory

Each row is one artboard in the [Penny key screens](https://claude.ai/artifact/V1uvDiMuTjJ9YCapXr2vZZ) canvas. Routes are suggestions for go_router; capabilities refer to the `authz` matrix in `docs/architecture.md`.

| Artboard | Width | Route | Who sees it | State shown | Components used |
| --- | --- | --- | --- | --- | --- |
| Sign in | 390 | `/sign-in` | Signed out | Populated | Button, TextField |
| Onboarding: solo or team | 390 | `/onboarding` | New user | "I run a team" selected | Button, TextField, OptionRow |
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

## Designed while building Phase 5

These have no artboard; they were designed in code from the components above and reviewed as screenshots at both widths. Screens with a list have their empty, loading and error states.

| Screen | Route or opener | Who sees it | Notes | Components used |
| --- | --- | --- | --- | --- |
| Today, everyone's lessons | `/today`, "Everyone" | Owner of a team | Each lesson's meta line names its tutor ("Mei, Studio room 2"); one clash notice for the day | LessonRow, SegmentedControl, Notice, NowLine |
| Add lesson, reschedule | Sheet from Today ("Add lesson") and Lesson details ("Reschedule") | Owner | Date, start, length, lead and assisting tutors (hidden for a team of one), students (multi-pick with search), place, title, fee, regular or trial. A clash after saving turns the sheet into "Keep it" or "Change the time" | Sheet, SelectField, TextField, OptionRow, Notice |
| Cancel lesson, with make-up | Sheet from Lesson details | Owner | Who cancelled; whether it is late and charged under the lead tutor's policy, before confirming; the reason; "Book a make-up lesson" with its date and time | Sheet, OptionRow, Notice, ToggleRow, SelectField |
| Lesson details, all states | `/lessons/:id` | Owner, tutors on the lesson | Clash with "Open that lesson"; cancelled with its make-up; done with ticked tasks; history; the lead's policy. On laptop it is a page with Back, not yet a side panel | Notice, StatusBadge, SectionHeader, CheckRow, Avatar, Menu |
| Task, goal or note | Sheet from Lesson details ("Add") | Owner, tutors on the lesson | One field and the kind | Sheet, SegmentedControl, TextField |
| Add student | Sheet from Students ("Add student") | Owner | Name, usually taught by (hidden for a team of one), first contact and relationship | Sheet, TextField, SelectField |
| Student details | `/students/:id` | Owner, the student's teachers | Contacts and goals with menus, next lessons, archive and restore | SectionHeader, ListRow, Avatar, Menu, Notice |
| Students, empty, loading, error, archived | `/students` | Owner (all), teacher (own) | Search with no match, archived list | EmptyState, Skeleton rows, Notice, SegmentedControl |
| Places | `/places`, from Account | Owner | Rooms, homes and online links; in person needs a six-digit postal code, online a meeting link | ListRow, Menu, Sheet, SegmentedControl, TextField |
| Cancellation policy | Sheet from Account ("Change policy") and Team (member menu) | Owner for anyone, a teacher for their own | Notice period, whether late cancellations and no-shows are charged, the summary parents see | Sheet, SelectField, ToggleRow, TextField |

## Designed while building Phase 6

| Screen | Route or opener | Who sees it | Notes | Components used |
| --- | --- | --- | --- | --- |
| Calendar, team day | `/calendar`, Day and Team | Owner of a team | Every tutor's column on laptop, with a chip filter (Everyone first); one tutor at a time on phone with a scrolling chip switcher, starting with the viewer. Column headers count lessons and clashes. A free time shows "Add lesson at 16:00" on hover and opens Add lesson for that tutor | DateNavigator, SegmentedControl, Chips, Timetable |
| Calendar, week | `/calendar?view=week` | Everyone (Team or Mine for owners) | A column per day on laptop, today in copper, other tutors' lessons named; a list per day on phone, so nothing scrolls sideways | Timetable, LessonRow |
| Calendar, month | `/calendar?view=month` | Everyone | Each day's first three lessons and "+N more" on laptop, counts and a clash mark on phone; tapping a day opens it. The team's month has the chip filter on laptop | MonthGrid, Chips |
| Calendar, empty, loading, error | `/calendar` | Everyone | Empty keeps the grid (free time is the point) with one line above it: "No lessons on this day. Tap a free time to add one."; loading is skeleton rows; errors offer Retry in place | Notice, Skeleton rows |
| Add lesson, repeating | Sheet from Add lesson | Owner | "Repeats" (does not repeat, or every week on the lesson's day) and "Ends" (when stopped, or after a date); trial lessons do not repeat | Sheet, SelectField, OptionRow |
| Change which lessons? | Choice from Reschedule on a repeating lesson | Owner | This lesson, this and following lessons, or all lessons from today. The last two open "Change the weekly lesson", whose date is fixed, with a note that done and cancelled lessons stay | Sheet, OptionRow, Notice |
| Lesson details, repeating | `/lessons/:id` | Owner, tutors on the lesson | A Repeats section ("Every Thursday, 16:30 to 17:15.") with Stop repeating, which confirms and removes later lessons that never happened | SectionHeader, ListRow, Dialog |
| Calendar link | Account | Owners and teachers | Make a link, shown once with a warning to treat it like a password; Copy link; Stop the link | Notice, Button, Dialog |

## Still to design

The design track's definition of done is every key screen in all five states at both widths. This first pass covers each screen once, plus the empty, loading, error and no-permission states on Today and Team. Still to draw, before or during Phase 2:

- Lesson details and Student details as a side panel beside the list on laptop (today they are pages with Back), and Payment request on laptop.
- Phone version of Payments. (Team list at phone width, onboarding's single-choice question and the add-teacher sheet were designed while building Phase 4, from PennyListRow, PennyOptionRow and PennySheet.)
- Empty, loading and error states for Payments (Calendar's were designed while building Phase 6).
- Record payment. Add lesson as a panel on laptop (it is a sheet at both widths today).
- Swiping between tutors and days on phone, and dragging a lesson to move it (Timetable and LessonBlock guidelines).
