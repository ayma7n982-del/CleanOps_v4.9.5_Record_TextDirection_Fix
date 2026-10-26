# CleanOps 4.7.0 — Smart Container Management

## Roles
- Level 3 / JSC: create and edit containers with fixed GPS coordinates; view all containers.
- Level 2 / Municipality: view municipality containers, receive alerts, start corrective action, confirm resolution.
- Level 1 / Group Supervisor: view containers assigned to the group, update daily status offline/online, report issues, confirm resolved issues.

## Lifecycle
- empty → partial → full
- issue: none → reported → resolving → verified_resolved
- full sends a red/emergency container alert to Level 2 and Level 3.
- empty after full sends an info notification to Level 2 and Level 3.

## Offline
Level 1 changes are written to the local queue through the existing offline-first DataService and synchronized to the `containers` Firestore collection when connectivity returns.

## UX
- Level 1: four-action field interface: Attendance, Log Load, Container Status, SOS/Emergency.
- Level 2/3: three tabs: Dashboard, Management, Reports & Messaging.

## Localization
The root MaterialApp remains bound to LocaleController. AppText now defaults its text direction to the active locale and both Arabic/English labels in the refactored flows use the existing I18n map.
