# Programme 1 — safety and persistence contracts

**Status:** executable plan under the maintainer’s explicit delegation to choose project details. Product scope follows approved cahier and Programme 0 baseline.

**Goal:** make every destructive operation fail closed without a durable approval record, preserve truthful and privacy-safe operation history, and remove user-facing claims that a move to Trash freed storage.

**Architecture:** keep `SafetyCore` storage-agnostic. `SafetyAuditSink` reports whether each event was persisted. `SafetyCenter` refuses to issue an executable approval when the sink is absent or cannot persist the approval event. Terminal event failure after an already-completed filesystem move remains visible through the existing unrecorded-event counter; never report it as durable success. Store keeps existing SQLite tables/columns; new refusal stage fits current text field. Rename presentation properties while retaining stored historical rows without destructive migration.

**Approved defaults under delegated product choice:** arm64/macOS 14+ remains starting platform; no scheduled destructive work, App Store edition, new locale, or installing updater in this reconstruction; local activity remains until explicit user clear; safety and persistence contracts precede engine/UI rebuild; show recorded logical item size moved to Trash, never “space freed/reclaimed”. Public release truth stays UNKNOWN pending independent evidence. Performance budgets wait for corpus/hardware measurements.

## Non-goals and preservation

- No database reset, schema history rewrite, historical row deletion, permanent file deletion, release/tag/push/deploy, or dependency download.
- No claim that a file’s logical size equals physical storage freed. Existing cleanup `activity.bytes` values remain intact and are rendered as recorded item size moved to Trash.
- No broad reorganization of Swift targets or source files.
- No website visual redesign in this programme; update safety copy that is in the app and authoritative safety/architecture docs. Site-wide copy reconciliation belongs to Programme 4.

## Work sequence

### 1. Fail-first proof for safety event persistence

- Add `SafetyAuditSink` result contract and a `SafetyError.auditUnavailable` case.
- Add tests showing `SafetyCenter.approve` refuses with no sink and with a sink that reports write failure; assert no filesystem mutation occurred.
- Add a durable in-memory test sink for successful `SafetyCore` tests. Keep test APIs explicit; do not allow product initialization to silently choose a no-op sink.
- For approval failures in all destructive screens, count refusals separately from executed and execution-time skipped operations. Never turn a rejected selection or unavailable audit store into a zero-item “success” screen; explain that items stayed in place.
- Implement only after both failure cases fail against current behavior.

### 2. Stable, redacted refusal events

- Add `.refused` audit stage for invalid/unsafe approval attempts; keep `.error` for filesystem or persistence faults, `.skipped` for execution-time revalidation refusals.
- Add stable `SafetyError.auditCode` values that omit associated path strings. Persist only code in `result`; continue path redaction through `Store.redactPath`.
- Test protected-root and symlink errors do not place original path in event result, and refused/executed/skipped/error records round-trip through `Store`.
- Update Safety Log count, badge, accessibility label and EN/FR stage copy. Preserve old stored `error` rows exactly; no migration required because `stage` is unconstrained text.

### 3. Correct size semantics and bilingual UI copy

- Rename `ExecutionOutcome.freedBytes` to `bytesMovedToTrash` and `ActivityImpactSummary.freedBytes` to `bytesMovedToTrash`; use wording “size moved to Trash” in success, Overview and Record.
- Keep `ActivityRecord.bytes` storage shape and existing data. Confirm every cleanup writer passes only successfully executed operations. Do not reinterpret scan-size records as Trash actions.
- Replace misleading `dashboard.reclaimed`, `activity.freed_real`, `cleanup.review.found`, `spacelens.delete.confirm_message`, duplicate-summary, cloud local-size identifier/comment, and sidebar group wording in English and French. Keep true object recovery language only when explicitly about items in Trash, never storage space.
- Correct current `SAFETY_MODEL.md`, `ARCHITECTURE_OVERVIEW.md`, `INSTRUMENT_REDESIGN.md` and affected test names/comments. Leave `Documentation/Archive/` untouched.

### 4. Add a copy-honesty regression gate

- Add dependency-free `Scripts/check-copy-honesty.py` that reads the UTF-16 Base/French string tables and enforces exact critical key presence, accurate wording, and rejection of freed/reclaimed-space claims for the audited keys.
- Run the new gate before copy changes and retain failing output as test-first evidence; then make it pass.
- Wire the gate into `Scripts/repository-doctor.sh` and `.github/workflows/ci.yml`.
- Do not edit `Documentation/REQUIREMENTS_TRACEABILITY_MATRIX.md` or generated feature artifacts by hand.

### 5. Verify and report

- Run focused Swift tests for SafetyCore, Store, execution outcome, activity grouping, cloud labels; then `HOME=/private/tmp/coretend-baseline-test-home bash Scripts/test.sh`, release build, localization parity, copy-honesty gate and repository doctor.
- Record exact UTC run bounds, exit codes, summary counts, warnings and paths in Programme 0 baseline; ensure real home/store remains isolated as the project test script requires.
- Run `git diff --check`, inspect all final changed paths for data deletion, stale forbidden copy, privacy leaks, generated-file edits, and migration implications.
- Commit in one coherent feature commit after review; no publication or remote mutation.

## Acceptance

1. Approval cannot yield an executable operation unless its approval event was durably recorded.
2. Unsafe paths are refused; audit result contains stable error code and no raw path or user identity.
3. Existing `activity` and `safety_log` rows remain readable; no schema/data migration is necessary.
4. Executed size is described only as item size moved to Trash; no EN/FR app surface calls it freed/reclaimed space.
5. Refusal is distinct from filesystem error in new audit rows and readable/accessibility-labelled in both locales.
6. Copy-honesty gate is invoked by both project CI and repository doctor and fails on the old false claims.
7. Focused and full project gates pass, or any environment failure is preserved as a clear blocker without dependency/network workaround.

### Follow-up safety regression — 2026-09-26

Final source review found an old test convenience fallback in `SafetyCenter`:
failed Trash requests under temporary roots were followed by permanent removal.
The fallback is removed; `trashFailed` leaves the source untouched. The internal
injected Trash seam keeps success/failure tests inside temporary fixture roots.
Focused SafetyCenter suite passes 14/14; full suite passes 444 tests across 12
runs with native XCTest UI excluded. No real user Trash was used.
