# Remaining Musts execution plan

## Global constraints

- Implement only behavior supported by `Documentation/Project/Cahier-des-charges.md` and current product safety rules.
- Tests use temporary fixtures only; never read or mutate the real user store, HOME or Trash.
- App update inspection is local metadata inspection. Never fetch a feed, compare versions, download or install anything.
- Keep traceability partial unless implementation and its acceptance evidence are both present.
- Do not push, merge, publish, tag, sign or notarize.

## Task 1 — FR-25 declared update source contract

- Add fixture tests for absent, valid declared HTTPS, and invalid update feed metadata in `ApplicationDiscoveryService`.
- Assert valid source exposes its declared URL while update availability remains unknown because no version check occurred.
- Assert invalid or absent source never becomes an actionable URL.
- Cover malformed, non-HTTPS, credential-bearing, whitespace/control-containing, and oversized declarations.
- Update UserGuide and Traceability with the local-only behavior and test evidence. Keep FR-25 `PARTIEL` if the UI opening behavior lacks direct automated or recorded qualification.
- Run focused tests and `make qualify`; inspect `git diff --check`.

## Task 2 — FR-20 legacy import rollback and retry

- Add a synthetic SQLite fixture test that forces the legacy-import marker insert to fail after preference/event writes have begun.
- Assert the transaction leaves no imported preference, exclusion, event, or import marker; the selected JSON source remains byte-for-byte unchanged.
- Remove the fixture failure and retry the same preview; assert exactly one complete import and one migration event.
- Change persistence code only if the test exposes a rollback or retry defect. Update migration documentation and Traceability evidence; retain `PARTIEL` until remaining migration acceptance is proven.
- Run focused PersistenceTests, `make qualify`, and `git diff --check`.

## Task 3 — FR-21 diagnostic export allowlist

- Extend synthetic diagnostic-export tests to assert the exact top-level JSON key allowlist (`product`, `version`, `schemaVersion`, `eventCounts`, `createdAt`) and that event IDs, timestamps, details, paths and filenames are absent.
- Use multiple synthetic events containing distinct private marker values; do not use real user paths or data.
- Update Traceability with the test evidence; retain `PARTIEL` until the native preview/export path is qualified.
- Change production export code only if the new assertion exposes an unintended field.
- Run focused PersistenceTests, `make qualify`, and `git diff --check`.

## Task 4 — FR-08 show local and logical file sizes

- In Explore results, display observed allocated local bytes and observed logical file size as separate labeled values for each result.
- Preserve unknown values as localized unknown text; never substitute zero or one measurement for the other.
- Give the combined measurement a VoiceOver-readable label in French and English.
- Update UserGuide and Traceability to explain the distinction. Keep FR-08 `PARTIEL` pending native visual/accessibility qualification and sparse/hard-link/cloud coverage.
- Add or adapt focused tests for any extracted presentation logic; run `make qualify` and `git diff --check`.

## Task 5 — FR-06 / FR-26 failed Trash audit path

- Add a synthetic Domain fixture where the Trash adapter fails after explicit review and confirmation.
- Assert original item remains, action result is failed, and persisted event sequence distinguishes proposal, approval, and failure.
- Keep all files and SQLite store under a unique temporary fixture root; never invoke macOS Trash.
- Update Traceability evidence for FR-06/FR-26; keep both partial pending native UI and attribution qualification.
- Change production code only if this integration test exposes missing or incorrect failure audit behavior.
- Run focused DomainTests, `make qualify`, and `git diff --check`.

## Task 6 — FR-11 migration rollback and retry

- Extend synthetic schema-v3 SQLite migration fixtures with an index-name collision that fails after the v4 migration creates `saved_files` inside its transaction.
- Assert failure leaves schema version 3 and preserves existing v3 event/preference rows; rollback removes the newly created table while preserving the fixture collision.
- Remove only the synthetic collision, retry migration, and assert schema v4 and prior rows are intact.
- Update Migration docs and Traceability; retain `EN_COURS` until all FR-11 data criteria are proven.
- Change migration implementation only if fixture exposes partial state or failed retry.
- Run focused PersistenceTests, `make qualify`, and `git diff --check`.

## Task 7 — align capability priorities with approved MoSCoW

- In `Traceability.csv`, classify `shell.menubar`, `settings.menubar`, `quicklook.extended`, `favrec.module`, `ui.commandpalette`, and `clutter.largeold` as Should, matching the explicit list in Cahier §7.
- For `ui.commandpalette` and `clutter.largeold`, replace stale `À_CONSTRUIRE`/empty evidence only where existing code, tests, and guide directly support the behavior; retain partial status for unqualified native interaction.
- Leave unimplemented capability statuses unchanged; do not infer proof from nearby features.
- Record the classification ruling and verify traceability plus full `make qualify`.

## Task 8 — localize durable Trash failure reason in Record

- Preserve event detail and JSON/CSV export shape; add nullable SQLite `failure_code` via additive schema v5 migration.
- Persist `trash_failed` in this separate field only for a failed Trash operation; old rows and unrelated failure events retain null.
- In Record, present known reason in EN/FR using the separate field and preserve the complete event detail/path verbatim. Never infer reason from a path suffix.
- Add migration, persistence, presentation, and export-stability tests.
- Update Traceability for FR-12/FR-06 without closing either requirement before broader localization/accessibility qualification.
- Run focused Persistence/AppShell/Domain tests, `make qualify`, and `git diff --check`.

## Task 9 — cloud placeholder local-byte classification

- Make ScanCore's existing ubiquitous-item metadata check injectable through a small `Sendable` reader with a Foundation-backed production implementation.
- Add fixture tests where the fake reader classifies a selected file as cloud-backed: logical size stays known, local allocated bytes stay unknown, and file contents remain unchanged. Also test local files retain observed allocated bytes.
- Ensure production reader only reads metadata; never starts downloads, hydrates placeholders, or makes network requests.
- Update UserGuide and Traceability; mark `cloud.detect` `PARTIEL`, not complete, because broader File Provider and live cloud behavior remain unqualified.
- Run focused ScanCore tests, `make qualify`, and `git diff --check`.

## Task 10 — read-only launch-agent review

- Follow archived analysis design: login-item inspection is consultative, receives explicit roots, and reports issues instead of treating unreadable/malformed entries as clean.
- Add a bounded Foundation plist scanner for a user-selected LaunchAgents folder. Do not inspect HOME or standard locations implicitly; skip symlinks and non-plist files; cap entry count and plist byte size.
- Extract only launch label and configured executable (`Program`, or first `ProgramArguments` item); report configuration candidates, never claim they are loaded/running or safe.
- Add an explicit folder picker and read-only result list to Integrity. No enable/disable/remove controls. Keep `integrity.loginitems` `PARTIEL` pending native UI and system service coverage.
- Add synthetic plist fixtures for valid, malformed, oversized, symlink and count-bound cases. Update UserGuide/Traceability; focused Domain/AppShell tests, `make qualify`, `git diff --check`.

## Task 11 — Full Disk Access settings guidance

- Extract current folder-access/FDA policy copy from `SettingsView` into bilingual `ProductCopy` keys so policy claims have parity tests.
- Preserve honest scope: the app requests no Full Disk Access, cannot infer system-wide FDA state, and does not open Privacy settings. Do not add entitlements, permission prompts, or OS deep links.
- Test EN/FR copy presence and ensure both say folder access is user-selected and Full Disk Access is not requested. Keep `settings.fulldiskaccess` `PARTIEL` until native settings flow and supported OS behavior are qualified.
- Update Traceability to map existing help, copy keys/tests, and remaining qualification gap. Run focused AppShell tests, `make qualify`, `git diff --check`.

## Task 12 — reviewed SpaceLens file-to-Trash action

- Add explicit selection controls to Explore's file results/SpaceLens map; default selection stays empty. Only regular file scan results under the currently chosen folder can be selected.
- Route the action through the existing `FileActionService`/`SafetyCore` flow with `ScanRule.explore`, the selected root, a named review, explicit confirmation, expiring identity revalidation, and the existing local audit sequence. Trash only; never permanently delete.
- No action if proposal logging fails. Journal cancel, success, and failure. On success remove moved items from current results; retain failed items and show a safe status.
- Add synthetic Domain integration coverage using an injected fixture Trash adapter for explore rule, event sequence, original preservation on failure, and no mutation before confirmation. Add bilingual copy tests for selection/review/cancel/status.
- Update UserGuide/Traceability, keep `spacelens.delete` `PARTIEL` pending native interaction and real Trash qualification. Run focused Domain/AppShell tests, `make qualify`, `git diff --check`.

## Task 13 — strengthen FR-02 read-only scan boundary

- Remove unnecessary `SafetyCore` dependency from `ScanCore`; keep only read-only scan dependencies.
- Extend `Scripts/audit_safety.py` to reject mutation APIs and SafetyCore/Persistence dependencies/imports in ScanCore.
- Snapshot fixture tree contents, types, sizes and modification dates before/after scan; assert no changes.
- Keep FR-02 `PARTIEL` until deterministic cancellation behavior and native UI cancellation are verified; do not infer proof from source checks alone.
- Update traceability and Progress; run focused ScanCore tests, `make qualify`, and `git diff --check`.

## Task 14 — FR-01 route restoration contract

- Give all eight `Destination` values an exhaustive route mapping used by the SwiftUI destination view.
- Restore persisted navigation only for known destination IDs; missing or stale values fall back to Overview.
- Add AppShell tests for all eight mappings, successful restoration and fallback; update UserGuide, Traceability and Progress.
- Keep FR-01 `PARTIEL` pending native window launch, state traversal and accessibility qualification.
- Run focused AppShell tests, app build, `make qualify`, and `git diff --check`.

## Task 15 — FR-11 fixture backup and recovery path

- Extend the synthetic v3 migration failure fixture with SQLite Online Backup to a separate temporary file and restore to another new temporary file before migration.
- Assert integrity, schema version, representative event/preference/performance data, and rejection of a corrupt source without installing a partial destination.
- Document manual offline local recovery: quit app, preserve current database, restore a private copy, and retain rollback path. Never inspect or mutate the real user store.
- Update Traceability and Progress. Keep FR-11 `PARTIEL` because real macOS store recovery remains unqualified.
- Run focused PersistenceTests, `make qualify`, and `git diff --check`.

## Task 16 — FR-02 deterministic scan cancellation

- Use a two-file temporary fixture and a blocking metadata reader to pause scan at first file.
- Cancel stream consumer, release reader, and assert worker does not inspect second file or report completion; compare fixture tree before/after.
- Keep public scan behavior unchanged; use an internal worker-finished hook only to join the worker deterministically in the test. Keep FR-02 `PARTIEL` pending native UI cancellation qualification.
- Update Traceability and Progress; run focused ScanCoreTests, `make qualify`, and `git diff --check`.

## Task 17 — FR-03 measurement provenance and claim limits

- Show bilingual provenance for each Performance metric and the `/` volume source on Overview; explain that observations do not diagnose system health or estimate recoverable space.
- Keep measured timestamp visible and unknown values explicit, including unknown volume capacity; do not change measurement semantics.
- Add EN/FR source assertions and a deny-list for affirmative health/recovered-space claims; document UserGuide and Traceability evidence; keep FR-03 `PARTIEL` pending native UI qualification.
- Run focused AppShell tests, app build, `make qualify`, and `git diff --check`.

## Task 18 — FR-04 exclusion persistence across store reopen

- Extend the synthetic SQLite exclusions test to release the first store, reopen the same temporary database URL, and assert normalized unique paths persist.
- Retain scan fixture proof that excluded roots/subtrees are absent from results; no target path becomes implicit.
- Update Traceability and Progress; keep FR-04 `PARTIEL` pending native Settings/launch qualification.
- Run focused PersistenceTests, `make qualify`, and `git diff --check`.

## Task 19 — NFR-01 reject symlink operation roots

- Add a synthetic target under a real directory and pass a symlink to that directory as the allowed root; approval must refuse.
- Enforce real-directory root check in the shared path containment validator so approval and execution both fail closed.
- Update ThreatModel, Traceability and Progress; keep safety path capability/NFR-01 `PARTIEL` because narrow TOCTOU and native action qualification remain open.
- Run focused SafetyCoreTests, `make qualify`, and `git diff --check`.

## Task 20 — FR-07 keeper cannot enter duplicate action review

- Add Domain fixture with one protected keeper and two identical selected copies.
- Assert review rejects the whole selection, all fixture bytes remain, fixture Trash stays empty.
- Keep FR-07 partial: concurrent external keeper removal and native UI flow remain unqualified.
- Run focused Domain test, `make qualify`, and `git diff --check`.

## Task 21 — FR-07 revalidate keeper during duplicate batch

- Pass the suggested keeper for each selected exact-duplicate group into the action review.
- Capture keeper identity, then revalidate before every file-to-Trash action; stop remaining batch items when any keeper is missing or changed.
- Add a fixture Trash adapter that simulates concurrent keeper removal after first move; assert one duplicate remains, no second Trash call, and failure is audited.
- Keep FR-07 partial for the narrow check-to-Trash race and native UI qualification; document threat control.
- Run focused Domain test, `make qualify`, and `git diff --check`.

## Task 22 — NFR-09 initial synthetic scan baseline

- Add a deterministic, temporary 10,000-file workload and repeatable Release CLI benchmark command.
- Record host, file/byte distribution, samples, wall/CPU/RSS, and limitations in Evidence.
- Keep NFR-09 partial: representative real corpus, app startup-to-window, UI/idle behavior and budgets remain open.
- Run `make benchmark-scan`, traceability validation, `make qualify`, and `git diff --check`.
