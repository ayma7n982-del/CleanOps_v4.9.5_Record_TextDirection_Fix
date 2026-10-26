# CleanOps v4.9.5 — Group & Excel Recovery

## Fixes
- Added defensive XLSX worksheet decoding fallback for workbooks that trigger the Excel package internal `Null check operator used on a null value` error.
- Hardened coordinator group discovery by normalizing current and legacy group fields.
- Recovered missing group options from imported worker operation records when a group registry record does not exist.
- Updated group center to show registered groups and legacy groups inferred from worker records.
- Added group number/name editing and consistent aliases (`number`, `groupNumber`, `groupId`, `name`, `groupName`).
- Added group import from `.xlsx` / `.csv` and export to `.xlsx` / `.csv`. Existing duplicates and blank rows are skipped with a summary.
- Group deletion confirms the action and explicitly preserves worker records.
- Scoped group visibility/export for municipality coordinators and kept role checks for management actions.

## Validation
- Project static verification passed (`verify_project.sh`).
- Flutter analyze/build was not run in this environment because the Flutter SDK is not installed here.
