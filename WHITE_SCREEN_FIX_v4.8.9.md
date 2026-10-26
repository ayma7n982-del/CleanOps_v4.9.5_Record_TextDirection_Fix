# CleanOps v4.8.9 — White Screen Recovery

- Added a visible, dark error fallback for Flutter widget build exceptions so route-level build errors do not appear as an unexplained blank/white screen.
- Hardened Cycle stream handling for errors, loading, and missing data.
- Removed `orderBy(startDate)` from the cycle stream to tolerate legacy cycle documents missing that field; limited stream to 50 records.
- Limited dumpsite streams to 100 and active workforce stream to 200 records.
- Made dumpsite fill percentage parsing tolerant of null, numeric, and string values.
- No Firestore rules or RBAC logic changed.

Flutter/Dart SDK was not available in the build environment; run `flutter analyze` and test the cycles/dumpsites screens on device before production deployment.
