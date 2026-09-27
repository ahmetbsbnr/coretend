# TODO — CoreTend current worktree

Priority source for in-place recovery, 2026-09-27. See [PASSATION](PASSATION.md)
and [milestones](../Documentation/Reconstruction/RECOVERY_PLAN.md).
Historical release counts and greenfield task lists are not current acceptance.

## P0 — Blocking / broken

- No unresolved P0 reproduced in the reviewed safety/persistence scope. This is
  not a complete-product security certification.

## P1 — Required for current milestone

- Include approval refusals in cleanup outcome counts across Cleanup, Applications,
  Leftovers, Duplicates and PrivacyCleaner; handle SpaceLens refusal explicitly.
  Current `try? await center.approve` drops them before ExecutionOutcome. Add a
  regression where a selected path disappears before approval; show a failure,
  not an apparently successful empty batch.
- Make unavailable/volatile persistence visible from AppEnvironment through
  Settings/SafetyLog and mutation screens. Current optional Store / :memory:
  fallback and try? reads can hide degraded audit availability. Requires fixture
  tests for failed open/read/write, then native UI acceptance; do not silently
  change audit-sink failure policy.
- Run native CoreTendUITests separately with an isolated app/store/preferences:
  Scripts/test.sh disables XCTest. Validate all eight destinations, onboarding,
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
- Review error presentation for Store activity/settings reads after database errors
  are propagated; distinguish empty history from failed reads.
- Localize persisted activity summaries using message keys/arguments (currently
  English sentences); migration/compatibility design required before schema edits.

## P3 — Nice to have

- Additional locales after EN/FR acceptance.
- Shortcuts/read-only automation beyond existing CLI rule/path inspection.

## Technical debt

- Filesystem path validation is not an atomic identity-bound OS move; document and
  evaluate TOCTOU limits before promising swap-proof operations.
- Audit sink counts failed writes but remains non-throwing; optional store can
  remove even that visibility. Track as P1, not as guaranteed durability.
- PlaceholderView appears unreferenced; leave it until UI contract review confirms
  removal scope. No broad dead-code deletion during safety repair.
- Safety failures remain in ExecutionResult.skipped for caller compatibility;
  distinct error case/audit stage retains cause without changing six UI flows.

## Completed / verified

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
