# CleanOps v4.9.5 — User Fixes

## Implemented in this source package
- Replaced launcher/icon source assets and Android launcher density/adaptive foreground artwork with the user-approved attached icon. Transparent pixels outside the rounded icon are preserved rather than showing the checkerboard as image content.
- Made offline queue serialization recursively convert Firestore `Timestamp`, `DateTime`, `GeoPoint`, document references, maps, and iterables into JSON-safe values before `jsonEncode`.
- Improved coordinator/muncipality scope matching for groups by normalizing common Arabic letter variants, whitespace, and a leading municipality prefix.
- Added real satellite imagery tiles (Esri World Imagery) to the live operations map when live-map settings are enabled, with group and dumpsite markers and map attribution. Tile delivery requires network access and the provider's service availability/terms.
- Added short staggered entrance motion to shortcut cards.
- Improved the user-facing Excel import message for Timestamp/JSON serialization failures while retaining diagnostic logging.

## Verification status
- Archive integrity, asset presence, XML parsing, YAML parsing, and static source checks are performed on the generated package.
- Flutter/Dart SDK is not installed in the execution environment. `flutter analyze`, unit tests, Android Gradle build, and on-device behavior therefore have **not** been run. This package must not be represented as proven error-free or production-build-verified until those tests are run in a Flutter environment.
- Firebase rules, Firestore schema/rules, and service signatures were not intentionally changed.
