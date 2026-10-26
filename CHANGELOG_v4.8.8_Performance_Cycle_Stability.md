# CleanOps v4.8.8 — Performance & Cycle Stability

- Added explicit error and empty states to the cycles stream screen so Firestore/query failures are visible instead of rendering a blank content area.
- Made cycle display parsing tolerant of missing names and date values represented as Timestamp, DateTime, ISO strings, or epoch milliseconds.
- Limited the cycle stream to the latest 50 documents.
- Replaced uneven report shortcut chips with a uniform two-column GridView and accessible tap targets.
- Increased global-search debounce from 280ms to 500ms and retained cancellation of stale scheduled searches.
- Cycle 11 trigger remains routed through the existing authenticated callable function to preserve Firestore Rules and avoid exposing privileged seeding writes from the client.

Validation: static source review only. Flutter/Dart SDK unavailable in this environment; `flutter analyze` and tests were not run.
