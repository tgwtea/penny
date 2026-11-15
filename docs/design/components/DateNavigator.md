# DateNavigator

Moves a schedule view by one day, week or month. Flutter: `DateNavigator` with `date`, `unit` (day, week, month), `onChanged`.

- The title is the visible period: "Thursday 19 November", "16 to 22 November", "November 2026". When the period contains today, the title is `copper-text`; that is the only copper in the header.
- "Today" appears only when the period does not contain today.
- Tapping the title opens a date picker. Swiping the schedule left or right on phone does the same as the arrows.
