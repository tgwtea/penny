# BottomNav

Main navigation on phone (under 600px). Flutter: `PennyBottomNav`, built from the destinations the session's capabilities allow.

- Destinations, in order: Today, Calendar, Students, Payments, and Team for owners of a team with more than one member. Solo tutors and teachers see four.
- Every destination has an icon and a one-word label. The active one uses the Fill icon weight on an `ink-subtle` pill, `text` label at weight 600; others are Regular weight in `text-secondary`.
- `bottom-nav-height` plus the device safe area. `hairline` top border, no shadow.
- Account and settings are in the top bar avatar, not here.
