# TODO — CoreTend 1.x maintenance

> **1.x maintenance line.** Product development happens on CoreTend Next
> (`feat/reconstruction-open-musts` → `next`; local folder `../coretend-next`).
> This branch only carries fixes for the published 1.x release.

Priority source for in-place recovery, 2026-09-27. See [PASSATION](PASSATION.md)
and [milestones](../Documentation/Reconstruction/RECOVERY_PLAN.md).
Historical release counts and greenfield task lists are not current acceptance.

## P0 — Blocking / broken

- No unresolved P0 reproduced in the reviewed safety/persistence scope. This is
  not a complete-product security certification.

## P1 — Required for current milestone

- [x] Approval refusals now contribute to the visible not-moved outcome in Cleanup,
  Applications, Leftovers, Duplicates and PrivacyCleaner. SpaceLens already surfaced
  its single-operation refusal. `OperationApprovalBatch` retains rejected selections;
  a fixture regression removes a selected file before approval and asserts a visible
  non-success outcome. Native UI acceptance is still required.
- [x] Persistence availability is explicit (`persistent`, `temporary`, `unavailable`,
  `degraded`), with a global warning banner. Failed Store reads/writes mark the app
  degraded; failed database opening no longer falls back to memory. Fixture tests
  cover durable open, temporary fallback, fail-closed open and warning localization.
  Native UI acceptance is still required; audit-sink failures remain non-throwing.
- Run native CoreTendUITests separately with an isolated app/store/preferences.
  Scripts/test.sh disables XCTest. The untracked `Xcode/CoreTend.xcodeproj` currently
  points to an absent absolute package path and its scheme declares no UI-test target;
  preserve those user-owned files and repair this in a separate lot. Validate all eight destinations, onboarding,
  settings, confirmations and failure outcomes in EN/FR with keyboard and VoiceOver.
- Verify distribution/package compatibility independently from source tests before
  any release-readiness claim. Do not alter published-release.json from doc dates.

## P2 — Important improvements

- Review Swift 6.4 warnings from the explicit swift-testing dependency while
  preserving Swift 6.0/macOS 14 support; choose toolchain/dependency strategy with
  a compatibility run, not a blind package removal.
- Re-run website Playwright/Axe/visual gates using existing pinned tooling; static
  Python checks cannot establish rendered accessibility or interaction.
- Reconcile remaining historical state JSON/feature assertions through their
  generators and evidence inputs. Never rewrite release provenance as source state.
- [x] Store activity/settings reads distinguish failures from empty history and
  show localized failure states or the global degraded-storage warning.
- Localize persisted activity summaries using message keys/arguments (currently
  English sentences); migration/compatibility design required before schema edits.

## P3 — Nice to have

- Additional locales after EN/FR acceptance.
- Shortcuts/read-only automation beyond existing CLI rule/path inspection.

## Technical debt

- Filesystem path validation is not an atomic identity-bound OS move; document and
  evaluate TOCTOU limits before promising swap-proof operations.
- Audit sink counts failed writes and remains non-throwing by design. AppEnvironment
  now turns that count into a visible degraded state after operations; native UI
  acceptance of the warning remains open. This does not guarantee durable logging.
- PlaceholderView appears unreferenced; leave it until UI contract review confirms
  removal scope. No broad dead-code deletion during safety repair.
- Safety failures remain in ExecutionResult.skipped for caller compatibility;
  distinct error case/audit stage retains cause without changing six UI flows.

## Completed / verified

- Revalidated on 2026-10-02: full Swift Testing suite, 15 focused approval/storage
  tests, Release builds for CoreTend and coretend-cli, SPDX headers and 247 internal
  documentation links all pass. Native UI/VoiceOver remains a separate acceptance.
- Independently revalidated existing Trash-only and SQLite read-error repairs:
  69 focused tests and 390 full Swift Testing tests pass on 2026-09-27.
- SQLite binding errors now prevent execution and finalize the statement; excess
  parameter regression reproduced before fix and passes after it.
- Repository doctor, SPDX, site build, first-paint/redirect contracts and 14 release
  metadata tests pass. Native UI and release artifact acceptance remain separate.

- Inventory of SwiftPM modules, six mutation entry points, SQLite migration path,
  CLI, static site and CI; recovery architecture/plan written.
- Initial repository-doctor executed; private-path failure identified in an old
  tracked greenfield plan. Personal workspace prefix removed without changing scope.

## Deliberately deferred product scope

No blind Simulator/Trash/Mail/LaunchAgent cleanup, browser history/cookie deletion,
privileged helper, automatic destructive CLI, malware engine, telemetry or accounts.
Mac App Store is a separate product/distribution decision. Existing app-update
handoffs are not a promise to download/install third-party applications.
