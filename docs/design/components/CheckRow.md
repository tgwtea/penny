# CheckRow

A row that can be ticked. Flutter: `PennyCheckRow(title:, subtitle:, checked:, onChanged:, trailing:)`.

- Tasks on a lesson ("Practise the tremolo"), and picking several items from a list (the students of a lesson).
- The box is Phosphor square / check-square in `text-secondary`, `ink` once ticked. The text stays as it is: a ticked task is still readable, and the state is in the mark and the semantics, never colour alone.
- The whole row is the target, at least 48px tall. `trailing` holds a menu for editing or removing.
- Without `onChanged` the row is read-only, for people who may see but not change the item.
