# ListRow

A row in a list of people or things: team members, students, contacts. Flutter: `PennyListRow(leading:, title:, tag:, subtitle:, trailing:, onTap:)`.

- Rows sit on one surface separated by `PennyDivider`, never each in a card.
- `leading` is an Avatar for people. `tag` is one short word after the title in `text-secondary`, such as "You". `subtitle` is one line (an email, a phone number) and ends with an ellipsis rather than wrapping.
- `trailing` holds a role word, a StatusBadge (for example Invited) and at most one MenuButton of actions.
- With `onTap` the whole row opens the detail; at least 48px tall either way.
