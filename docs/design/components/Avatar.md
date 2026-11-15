# Avatar

Initials in a circle, standing for a person. Flutter: `PennyAvatar` with `name` and `size` (24, 32, 40). A photo is optional later; until then initials only.

- Two initials from the first and last name parts; one initial for a single-word name.
- Every avatar uses `ink-subtle` with `text`. People are not colour-coded: colour in Penny means status, and a rainbow of avatar colours would compete with it.
- Several tutors on one lesson stack with a 2px `surface` ring and 6px overlap, always next to their names in text.
- The avatar is never the only way to identify someone; a name sits beside it or in its semantic label.
