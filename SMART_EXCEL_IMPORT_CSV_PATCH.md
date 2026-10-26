# CleanOps 4.7.1 — Excel/CSV Import Hardening

- Smart worker import now accepts `.xlsx`, `.xls`, and `.csv`.
- CSV parsing supports UTF-8/BOM, comma/semicolon/tab delimiters, quoted fields, and escaped quotes.
- Excel parsing remains supported through the existing `excel` package.
- Header/column detection remains order-independent.
- File name is passed to the parser so `.csv` is routed to the CSV decoder.
- Import errors are surfaced in a floating SnackBar for 8 seconds with the exact parser/platform error, and the same detail remains visible in the card.
- Empty/corrupt/invalid CSV and Excel files produce explicit Arabic diagnostics.
- Added semantic `ExcelImportService` typedef alias without breaking existing `ExcelService` callers.
- Version bumped to 4.7.1+2.

Flutter SDK is not installed in this environment, so `flutter analyze` / `flutter build apk` were not executed here.
