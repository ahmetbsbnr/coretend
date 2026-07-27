# TEST PLAN
Runner: Swift Testing via Scripts/test.sh (see DECISIONS D2).

Current coverage (24 tests):
- PathValidator: valid path, empty, "/", /System, /bin,/sbin,/usr/*, home itself,
  outside allowlist, "..", prefix boundary, symlink escape, symlink inside, unicode,
  very long path.
- SafetyCenter: dry-run non-destructive, vanished file skipped, symlink swapped
  between approve and execute rejected.
- ScanEngine: finds files + sizes, min-age filter, missing root, symlinked dir not
  descended, cancellation mid-stream.
- FileRules: unique stable ids, no rule targets user content roots, deletion
  allowlist covers every rule root.

Planned: SQLite migration tests, APFS test-image fixtures (create-test-volume.sh),
locked-db/permission-denied/disk-full simulations, helper attack tests.
