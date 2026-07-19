# CONTINUATION

## Where we are
Phase 1 (foundation) complete and green:
- `swift build` compiles clean, `Scripts/test.sh` runs 24 passing Swift Testing tests.
- Cleanup module is end-to-end real: streaming scan of ~/Library/Caches, ~/Library/Logs,
  DiagnosticReports, DerivedData → review list with per-item toggles → SafetyCenter
  approve/execute → dry-run (default) or move-to-Trash.

## Toolchain constraints (read first)
- **No Xcode installed** — CommandLineTools only. `xcodebuild` unusable.
- Build: `swift build` / `Scripts/build.sh [release]`.
- Tests: **must** use `Scripts/test.sh` (passes framework/rpath flags for Swift Testing;
  plain `swift test` fails with "no such module 'Testing'"). XCTest does not exist here.
- App bundle: `Scripts/package-local.sh` (release build + Info.plist + ad-hoc codesign).

## Next step (in order)
1. `Persistence` module: SQLite (system libsqlite3) behind an actor, schema_migrations table,
   tables: scans, scan_items, operations, operation_items, exclusions, settings.
2. Cleanup UI: group findings by rule (DisclosureGroup per category), per-rule select-all.
3. Smart Care orchestrator (dry-run): runs Cleanup rules per module with independent progress.
4. Verify `package-local.sh` produces a launchable app.

## Gotchas
- FileManager.DirectoryEnumerator can't be iterated in async context → sync helper
  `ScanEngine.scanRoot` called from detached task.
- PathValidator is Sendable struct; uses FileManager.default internally (no stored FM).
- SafetyCenter defaults to dryRun=true; UI toggle controls it.
