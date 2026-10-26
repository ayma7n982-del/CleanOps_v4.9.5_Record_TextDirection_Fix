# CleanOps Smart Excel Import

- Detects the header row automatically instead of requiring row 1.
- Detects supported columns by header meaning, not column order.
- Municipality and group are not trusted from Excel; they are assigned from the selected municipality coordinator and one of that coordinator's groups.
- Level 2 is locked to its own municipality coordinator.
- Level 4 can choose an active municipality coordinator, then only that coordinator's groups are shown.
- Municipality is read from `municipalityName` (preferred), then municipality-related profile fields/scope, with backward-compatible parsing for names explicitly containing "بلدية ..." or "منسق ...".
- New municipality coordinator accounts can store `municipalityName` during creation.
- Valid imported workers are queued for offline/online synchronization and audited.
