# Sidebar

Main navigation from 600px wide. Flutter: `PennySidebar` with the active team, the destinations the capabilities allow, and the signed-in person.

- The team switcher sits at the top: team name, the person's role in it, and a chevron. It only opens a menu when the person belongs to more than one team.
- Destinations match the BottomNav. A destination may carry one short count in `text-tertiary` ("3 overdue"), never a coloured dot.
- The active item has an `ink-subtle` background, `text` at weight 600 and the Fill icon.
- `sidebar-width`, `surface`, `hairline` right border. The signed-in person sits at the bottom and opens account settings.
