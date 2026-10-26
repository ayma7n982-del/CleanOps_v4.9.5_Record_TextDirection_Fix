# CleanOps v4.8.5

Targeted UI/UX and field-operation completion update.

- Global Arabic typography upgraded to Google Fonts Cairo.
- Reports Center shortcut layout redesigned with responsive ChoiceChips and red selected state.
- Attendance worker icons made explicit/high contrast.
- Primary scrollable screens receive bottom breathing room to prevent last-item cut-off.
- Worker safety approval opens a named-worker compliance BottomSheet with مطابق / غير مطابق.
- Image picking offers Camera / Gallery source selection.
- Container Management gets a prominent L3 add-container FAB.
- User management adds a high-level delete/deactivate action without changing Firebase rules.
- Cycle deletion remains available under existing permission checks.
- L2 group management adds Edit/Delete actions with confirmation for deletion.
- L3/L4 shortcut cards are enlarged and visually emphasized.
- Shortcut naming is clearer and more descriptive.
- Global search aliases are expanded for Arabic spelling variants and operational synonyms.
- Reports PDF header strengthened with CleanOps branding, UNICEF name, municipality names, report title and report ID.
- CleanOps launcher icon redesigned with a centered, larger Samsung-style rounded icon composition.
- Firebase Firestore rules were not changed in this release.


# CleanOps v4.8.6

Stability and simulation visibility repair.

- Fixed permanent user deletion through a secured Firebase Callable Function; Firebase Authentication and Firestore profile are removed together.
- Fixed Cycle 11 simulation visibility and added municipality/cycle index records to the existing operations stream.
- Simulation automatically binds to an existing Bani Suheila L2 coordinator when one exists, so groups, workers, supervisors, containers and dumpsites appear under the current municipality read scope.
- Reports now read real active workers and group supervisors from the users collection and include dumpsite counts.
- Reports default to a 30-day window so the full 10-day Cycle 11 simulation is visible.
- Fixed search result actions so tapping a result opens the real corresponding screen instead of doing nothing.
- Improved Arabic fuzzy-search aliases and operational entity labeling.
- Fixed the L4 dumpsite shortcut to open the working dumpsites overview instead of a role-incompatible management tab.
- Enlarged and organized CleanOps AI text/chat controls.
- Enlarged and centered the Android launcher logo across adaptive and legacy launcher assets.
- Firestore rules were not modified.
