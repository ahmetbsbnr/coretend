# Project Handoff — 1.x maintenance

> **1.x maintenance line.** Product development happens on CoreTend Next
> (`feat/reconstruction-open-musts` → `next`; local folder `../coretend-next`).
> This branch only carries fixes for the published 1.x release.

Observed 2026-10-02 in the current worktree. This document and [TODO](TODO.md)
are the active handoff/queue. Historical counts and release assertions are not
current test or artifact evidence. No commit, publication or deployment performed.

## Project purpose

CoreTend is a native macOS storage inspection/cleanup utility: scan locally,
review findings, explicitly confirm eligible moves to Trash. It also provides
read-only integrity metadata, application discovery, metrics, a small CLI and
static EN/FR product website. No server/account/telemetry or privileged helper.

## Current state

Substantial implementation exists, not an empty scaffold. SwiftPM declares Swift
6, macOS 14+, CoreTend and coretend-cli executables, eight engine/UI libraries and
CoreTendApp. UI files are in a flat CoreTendApp directory; old v2 nested-module
instructions and generated architecture tooling do not describe this tree.
Several generations of release/reconstruction documents coexist. This handoff
covers 1.x maintenance only; the rebuild continues on CoreTend Next.

Existing user changes were preserved: deleted .impeccable/live/config.json;
untracked local configs, Xcode, captures, graph outputs, AGENTS.md and three
2026-09-25 planning files. Do not stage or clean them with recovery changes.

## Architecture overview

[Architecture](../Documentation/ARCHITECTURE.md) maps modules, interfaces, data
ownership, tests and transition risks. Read-only engines stream findings to
MainActor view models. Six cleanup surfaces use SafetyCenter; Persistence.Store
owns SQLite/WAL with four migrations. UserDefaults holds some UI preferences.
CoreTendCLI lists rules/paths. Website/build.py produces static output from reviewed
release metadata; CI/package/release scripts are separate from application runtime.

## What is working

- Source includes scanning, staged duplicate hashing, image similarity, treemap,
  app discovery, provenance/signature/login-item inspection and system metrics.
- Path validation rejects protected roots, out-of-scope paths and escaping symlinks.
- Safety execution tests now use fixture Trash, preserve bytes on adapter failure,
  and distinguish trashFailed from fileVanished with error vs skipped audit events.
- SQLite query failure after an initial row now throws rather than returning partial
  history. Migrations and Store tests exercise temporary/in-memory databases.
- Static site build and focused source gates have run; see verification below.

These are implementation/test statements, not native UI or released-app acceptance.

## What is partially implemented

- Persistence availability: Store bootstrap now distinguishes durable, temporary,
  unavailable and degraded states. Failed database opening is visible and fails closed;
  database reads/writes mark a global warning. Safety audit remains deliberately
  non-throwing, with its failure tally reflected after executions.
- UI acceptance: native XCTest source exists, excluded by Scripts/test.sh.
  Source accessibility contracts do not replace keyboard/VoiceOver checks.
- Approval refusals from Cleanup, Applications, Leftovers, Duplicates and
  PrivacyCleaner now appear in the outcome count; SpaceLens already showed its
  single-item refusal. A fixture regression was added for a selected path that
  vanishes before approval. The focused `ExecutionOutcomeTests` suite passes
  (10 tests; 15 combined with `PersistenceAvailabilityTests`) using a fresh `/tmp` scratch path and module cache with SwiftPM's
  subprocess sandbox disabled. Native UI acceptance remains open.
- External application updates are links to update mechanisms, not installation.
- Historical completeness/feature inventories need requirement-level revalidation.

## What is broken

Existing repairs present before this session and independently tested:
1. Failed Trash under temporary roots permanently removed the file and logged
   executed. No permanent-delete fallback remains in SafetyCore.
2. Database.query stopped on any non-row SQLite status, silently returning partial
   results on step errors. Only SQLITE_DONE now completes successfully.

Initial repository doctor failed on a personal absolute workspace path in a tracked
historical plan. That prefix was sanitized; no secret values were printed here.
Other outstanding problems and verification limitations remain in TODO, not hidden
behind a claim that the entire repository is complete.

New repair in this session: SQLite binding errors now throw before execution
instead of silently accepting excess parameters. No Store call-site defect was
observed; this closes a failure-policy gap in the shared database wrapper.

Review also found approval errors discarded with `try?` in mutation screens.
Those failures are absent from ExecutionOutcome counts; track separately in TODO.

## Important architectural decisions

- Keep SwiftPM/native SwiftUI, existing dependency graph and no new dependency.
- Keep public SafetyCenter initializer unchanged; internal synchronous adapter only
  for tests. No await between execution-time validation and the mutation call.
- Keep ExecutionResult.skipped compatible with six UI consumers; trashFailed carries
  failure cause, audit error stage distinguishes it from a validation refusal.
- No schema migration for SQLite error propagation. Existing throwing APIs retained.
- Keep dated history, add current entry points; never rewrite published provenance
  or treat another branch's intended architecture as current implementation.

## Known technical debt

Non-throwing audit sink, English persisted activity summaries, path-based TOCTOU
limits and old toolchain/test dependency warnings.
See [document reconciliation](../Documentation/Reconstruction/DOCUMENT_AUDIT.md)
for DONE/PARTIAL/OBSOLETE/UNCLEAR distinctions and historical planning inventory.

## Current milestone

M1 safety, M2 SQLite repairs and M3 source verification/handoff are complete
within the recorded scope. M4 approval-refusal reporting and storage-failure
presentation are implemented with fixture regressions. Native UI acceptance
remains open. [Recovery plan](../Documentation/Reconstruction/RECOVERY_PLAN.md)
contains exact scopes, dependencies, acceptance criteria and later milestones.

## Next priorities

1. Restore/fix a project-local Xcode scheme with a UI test target (the existing untracked
   `Xcode/CoreTend.xcodeproj` points to a missing absolute package path and declares no UI test
   target), then run isolated native UI/VoiceOver acceptance of storage and failure states.
2. Run website browser checks and compatibility on macOS 14; release evidence refresh remains
   separate from source recovery.

## Risks / blockers

No missing credential blocks these source repairs. Real Trash OS behavior was not
exercised on user files. Fixture adapter tests prove orchestration/failure policy,
not every filesystem's Trash implementation. Current public artifact signatures,
notarization, website deployment and cross-macOS compatibility remain unverified.

## Verification status

Independent revalidation on 2026-09-27: the earlier
`/tmp/coretend-recovery-audit/` directory was absent. Earlier RED claims are
historical notes, not reproduced evidence from this session.

- PASS: 69 focused tests (31 safety, 38 persistence/migration).
- PASS: full `bash Scripts/test.sh`, 390 Swift Testing tests, exit 0.
  XCTest/native UI remains excluded by this command.
- PASS: new excess-binding regression reproduced 3 failed assertions before the
  binding fix; passes afterward. The rejected INSERT leaves the table empty and
  the connection accepts a subsequent valid INSERT.
- PASS: repository doctor, SPDX headers, first-paint/redirect contracts,
  14 public-release metadata tests and static website build.
- PASS: `zsh Scripts/build.sh release`, exit 0, no warning in this run.
  Swift compilation provides type checking; no separate typecheck command ran.
- PASS: final `git diff --check` and internal Markdown link check.
  Dedicated formatting/lint tooling: NOT RUN.
- Code/security review: focused review of SQLite statement lifetime, SafetyCenter
  validation/mutation and its six UI callers. Not a complete product security audit.
- Native UI/E2E, VoiceOver, browser/Axe, actual release artifacts: NOT RUN.
- Local ephemeral logs: `/tmp/coretend-focused-green.log`,
  `/tmp/coretend-bindings-red.log`, `/tmp/coretend-full.log`,
  `/tmp/coretend-release.log`, `/tmp/coretend-doctor.log`.

Revalidation on 2026-10-02 for the approval-refusal and persistence-availability changes:

- PASS: `swiftc -frontend -parse` on all changed Swift source and test files.
- PASS: focused `ExecutionOutcomeTests` and `PersistenceAvailabilityTests`; 15 tests
  passed, including temporary fixture database open/fallback/fail-closed and unavailable-
  warning precedence cases.
- PASS: full `bash Scripts/test.sh` using `/tmp/coretend-approval-refusal-build`;
  all Swift Testing suites passed (including 188 app tests and 1 accessibility
  contract test). XCTest/native UI remains excluded by this command.
- LIMITATION: one Developer ID code-signing case is skipped because no signing
  identity is installed. Native UI and VoiceOver remain unverified.
- PASS: `git diff --check`. Native UI and VoiceOver remain unverified.
- The legacy `.build` cache was incompatible with the current checkout; tests
  therefore used `/tmp/coretend-approval-refusal-build` and
  `/tmp/coretend-clang-module-cache`, with SwiftPM subprocess sandbox disabled. The first
  Release attempt named the internal target as a product and failed; rerunning with the
  declared products `CoreTend` and `coretend-cli` succeeded.
- PASS: current `git diff --check`, `bash Scripts/check-spdx-headers.sh` (109 Swift files),
  and Release builds for products `CoreTend` and `coretend-cli` using scratch path
  `/tmp/coretend-1x-release-build-20261002`.
- PASS: `python3 Scripts/check-markdown-links.py` checked 247 internal links across
  255 tracked Markdown files; zero broken internal links.
- FIXED: Base/FR localization catalogues contained a stray diff3 ancestor marker.
  Foundation stopped parsing each `.strings` plist at that line, so newer dashboard
  and sidebar keys rendered raw. Removed the markers, added a plist-parse/key-presence
  regression contract, confirmed both packaged catalogues parse, and visually reviewed
  an isolated French dashboard capture with the expected localized labels.
- PASS: complete `Scripts/test.sh` rerun in isolated HOME and fresh scratch path
  `/tmp/coretend-full-qualify-20261002`; all reported Swift Testing suites passed,
  including 188 app, 60 persistence, 48 safety and the localization/accessibility
  contract. Both packaged catalogues pass `plutil -lint` and contain the newly parsed keys.
- NOT RUN: native UI/VoiceOver. `xcodebuild -list -project Xcode/CoreTend.xcodeproj` fails because
  the untracked local project references the absent `/Users/ahmetbasbunar/Developer/Website/…`
  package path; its only scheme has no XCTest UI test target. The user-owned `Xcode/` files
  were left untouched. The native capture is a visual smoke only; it does not exercise
  navigation, cleanup confirmations, keyboard flows, or VoiceOver.

## Important commands

```sh
bash Scripts/test.sh --filter 'SafetyCenter|PathValidator|TrashFailure'
bash Scripts/test.sh --filter 'DatabaseTests|StoreTests|StoreStressTests|LegacyDataMigration'
bash Scripts/test.sh
zsh Scripts/build.sh release
bash Scripts/repository-doctor.sh
bash Scripts/check-spdx-headers.sh
python3 Website/build.py --output /tmp/coretend-site
python3 Scripts/check-first-paint.py
python3 Scripts/check-retired-pages.py
python3 Scripts/test-public-release-gate.py
git diff --check
```

## Notes for the next agent

Start with Git status and this handoff. Never use old greenfield workspace paths,
run cleanup against user data, or count XCTest UI tests as executed by test.sh.
No credentials or .env reads are needed. Maintain current docs as implementation
changes. Old reports remain historical even where they say COMPLETE or current.
User-owned untracked files are not an invitation to incorporate or delete them.
