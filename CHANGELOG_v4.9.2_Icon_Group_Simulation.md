# CleanOps v4.9.2 — Launcher Icon, Group Controls, Simulation Shortcut

- Updated Android legacy launcher icons and adaptive foreground artwork using the supplied CleanOps bin/truck logo.
- Added a prominent animated “تشغيل محاكاة الدورة 11” shortcut near the top of the Level 4 dashboard. It calls the existing `runCycle11Simulation` Firebase Callable Function and shows success/error feedback.
- Made Edit and Delete controls visible on each group row for the municipality coordinator role; existing Firestore rules are unchanged and remain the authority for write permissions.
- Added a short entrance animation to the simulation shortcut banner.
- Kept the small developer credit on the AI bot screen.

Validation: archive/file integrity and targeted static checks only. Flutter/Dart SDK is not installed in the authoring environment, so `flutter analyze`, `flutter test`, and APK rebuild could not be run here. The simulation shortcut still depends on the existing deployed Firebase Callable Function.
