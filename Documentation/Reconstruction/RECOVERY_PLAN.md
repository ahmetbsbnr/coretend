# Repository recovery — 2026-09-27

Current instruction: repair this repository incrementally. Earlier proposals for a
separate greenfield repository are historical inputs, not the execution plan.
No commit, release, signing, deployment or user-data cleanup is authorized here.

## Goal and ledger

Restore trustworthy safety behavior, persistence error reporting and maintenance
documentation without replacing the working native application.

- DONE: Git baseline, package/CI/script inventory, primary documentation review,
  mutation call-site review. Existing untracked files and deletion preserved.
- DONE: M1 safety and M2 SQLite read/binding failure checks; 69 focused tests
  and 390 full Swift Testing tests pass.
- DONE: M3 release build (exit 0, no warnings), repository doctor, final diff
  and internal-link checks; handoff synchronized. Native acceptance not claimed.
- NEXT: M4 visible storage failures and accurate approval-refusal outcomes.
- Assumption: existing direct-distribution native product remains the scope.
- Risks: old release claims are not artifact verification; UI acceptance is separate.

## M0 — establish baseline

Scope: Package.swift, Sources, Tests, Scripts, docs, Documentation, CI, Website.
Evidence: repository doctor fails private-path scan; other doctor gates pass.
Swift 6.4 / arm64 host. No runtime dependency added. Existing tests that invoke
SafetyCenter must be isolated before executing them against the real Trash.
Acceptance: document real module boundaries, stale claims, reproducible commands.

## M1 — enforce Trash-only behavior

Files: Sources/SafetyCore/SafetyCore.swift; Tests/SafetyCoreTests/PathValidatorTests.swift.
Reuse PathValidator, ApprovedFileOperation, ExecutionResult and audit events.
Add an internal synchronous throwing Trash adapter seam; public initializer keeps
using FileManager.trashItem. No suspension between validation and adapter call.
Remove permanent-delete fallback. Report trash failure with a distinct SafetyError
in the existing skipped collection, preserving callers and their non-success count.
No schema/UI migration. Test fixture moves preserve bytes; forced failure preserves
source, emits error (never executed), and does not prevent subsequent operations.
Tests: prove failure regression red with old fallback, then focused suite green.
Risk: tests previously depended on destructive fallback or actual macOS Trash.

## M2 — SQLite read failures cannot masquerade as results

Depends on M1 verification. Files: Persistence/Database.swift and focused tests.
Check sqlite3_step terminal result; throw DatabaseError unless SQLITE_DONE.
Also check every sqlite3_bind result before execution and finalize on failure.
Excess-binding INSERT regression demonstrated silent writes before the fix;
a failed bind now leaves the database unchanged and connection reusable.
No schema/API migration; existing throwing callers continue handling errors.
Test SQLite expression overflow after an initial successful row: no partial result.
Check failed queries do not leak statements and subsequent queries still succeed.
Risk: surfaces errors previously hidden by the wrapper; review Store callers.

## M3 — one current handoff and executable backlog

Depends on M1/M2. Maintain docs/PASSATION.md, docs/TODO.md,
Documentation/ARCHITECTURE.md, documentation indexes and development entry points.
Keep historical reports with explicit status, not invented refreshed release evidence.
Acceptance: focused/full tests, release build, doctor, source/diff review recorded
as PASS/FAIL/NOT RUN; outstanding UI/release gaps remain explicit.

## Later milestones

- M4: durable-storage failure presentation and audit availability. Inspect
  AppEnvironment's optional/in-memory fallback and all mutation entry points;
  agree on behavior from existing safety contract before altering it. Exercise
  locked/unwritable storage using fixtures; UI must surface degradation.
- M5: native destination acceptance (eight destinations, settings, onboarding),
  EN/FR, keyboard/VoiceOver, loading/error/empty states, isolated launch and site
  browser gates. Preserve design. No cosmetic rewrite. Requires interactive evidence.
- M6: release readiness after M4/M5. Reconcile metadata against actual downloaded
  artifacts, compatibility and packaging evidence. Publishing remains separate.
