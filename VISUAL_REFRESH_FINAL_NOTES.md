# CleanOps v4.9.5 — Visual Refresh

## Visual-only changes
- Standardized the Material color scheme to a light emerald/teal palette.
- Added short native page transitions and adaptive visual density.
- Updated global navigation, drawer, form focus, and button interaction styling.
- Refined the AI bot screen to use the same light surface palette while retaining the existing orbit/glow animations, chat actions, AI service integration, and developer credit (`Developed by @Eman Al-Qahwaji`).
- Kept the existing app icon assets unchanged.

## Scope protection
No intentional edits were made to Firebase configuration, Firestore data models/rules, authentication, RBAC logic, data services, or business operations.

## Validation
Flutter SDK was not available in the editing environment, so `flutter analyze` and an Android build could not be run here. Run `flutter pub get`, `flutter analyze`, and a device build before production release.
