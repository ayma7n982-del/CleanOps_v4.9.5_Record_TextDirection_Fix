# CleanOps v4.9.4 — Local Simulation Viewer

## Fix
The Cycle 11 demo was generated in memory only, so the generated groups and workers were not visible in production Groups/Workers screens (by design). Added a dedicated `SimulationPreviewScreen` and a `عرض المجموعات والعمال` button to view the local-only data.

## Demo contents
- Municipality: بلدية بني سهيلا
- Cycle: 11, October 2026
- 5 groups
- Per group: 1 field supervisor, 7 primary collection workers, 2 animal-cart workers
- 2 demo containers, 20-ton capacity each
- 900 demo trips over 20 days, 10 tons per trip

## Isolation
The demo data remains in process memory only. No Firestore, Firebase Functions, Authentication, or production collections are read/written. The viewer explicitly says that the data does not appear in real operations screens and disappears when the app process exits.

## Validation
ZIP integrity and static source checks were run. Flutter/Dart SDK is unavailable in this environment, so `flutter analyze` and APK build could not be run.
