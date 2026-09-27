# Documentation reconciliation — 2026-09-27

Scope: current checked-out source, not all branch histories or published artifacts.
No literal TODO/FIXME/HACK/XXX/WIP/NOT IMPLEMENTED markers were found in Sources
or Tests with word-boundary search. Shell template names and mktemp XXXXXX are
not tasks. Absence of markers does not imply feature completion.

## Claims checked against source

| Claim / source | Classification | Evidence and disposition |
|---|---|---|
| README: temporary paths are always Trash-only | BROKEN → corrected | SafetyCenter had removeItem fallback; fixture failure regression reproduced it; fallback removed |
| Old product debt: audit log only in memory | OBSOLETE | Store migration 2 creates safety_log; non-throwing sink persists events but AppEnvironment can lack a durable Store |
| Audit always durable | PARTIALLY DONE | failed inserts counted; optional/in-memory app store and UI try? reads remain P1 |
| Architecture: CoreTendApp executable, one product | OBSOLETE | Package has wrapper CoreTend executable, CoreTendApp target and separate CLI; architecture updated |
| Method: Scripts/dev.sh, docs/architecture, VNEXT_TASKS | NO LONGER RELEVANT here | None in current tree; replaced current method, preserved historical engineering notes |
| Product debt: no automated website accessibility | OBSOLETE | Scripts/site/test-site.mjs uses Axe; CI invokes it; runtime result not inferred |
| App Updates does not install apps | DONE as handoff scope | AppUpdatesView + AppDiscovery.UpdateMechanism use external update destinations; not an incomplete auto-updater |
| Four cleanup categories, browser history/cookies, privileged helper | NOT STARTED / deliberately deferred | UserCleanupRules scope and no helper target; no automatic implementation of unsafe proposals |
| CLI destructive workflows | NO LONGER RELEVANT to milestone | CoreTendCLI implements read-only --list-rules/--paths/--help |
| Repeated counts 86/215/286/342/687 | OBSOLETE as baseline | Must use current test output; inventory counts cannot prove execution |
| Tests include native UI coverage | PARTIALLY DONE | XCTest UI source exists, test.sh --disable-xctest does not execute it |
| 0.8/0.9/1.0/1.0.2 current release claims | UNCLEAR as public evidence | Local metadata differs from snapshots; no downloaded artifact verified in recovery |
| Greenfield outside repository | NO LONGER RELEVANT to current instruction | Separate-repo plan never describes current source; retain as historical proposal |
| 2026-09-25 baseline/reconstruction | PARTIALLY DONE / DUPLICATE | Baseline and plan exist; current recovery consolidates operational priorities, not all aspirational requirements |
| Complete/gold-master/scorecard claims | UNCLEAR for current build | Historical acceptance cannot substitute current native UI/compatibility/release validation |
| PlaceholderView | UNCLEAR / likely dead code | Declaration found, no call sites found; no screen replaced based on its name alone |

## Source-of-truth policy

Current: docs/PASSATION.md (state), docs/TODO.md (queue),
Documentation/ARCHITECTURE.md (source architecture), RECOVERY_PLAN.md (milestones).
Historical reports retain useful evidence and dates. Do not silently regenerate
release-state JSON or feature inventories to make their claims match aspirations.
Full requirement-by-requirement acceptance remains open; this is not a claim that
every historical feature was exercised.

## Inventory of planning / handoff candidates

The list below records files by name. Historical means its contents need fresh
source/behavior evidence before becoming a current task; it does not discard them.

- `Documentation/ARCHITECTURE.md` — CURRENT.
- `Documentation/ARCHITECTURE_INVENTORY.md` — HISTORICAL / REFERENCE.
- `Documentation/ARCHITECTURE_OVERVIEW.md` — HISTORICAL / REFERENCE.
- `Documentation/Archive/TODO_2026-08-08_pre-integritycore-cleanup.md` — HISTORICAL / REFERENCE.
- `Documentation/CONTINUATION.md` — HISTORICAL / REFERENCE.
- `Documentation/FIRST_RUN_STATE_MACHINE.md` — HISTORICAL / REFERENCE.
- `Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md` — HISTORICAL / REFERENCE.
- `Documentation/LOGO_MIGRATION_PLAN.md` — HISTORICAL / REFERENCE.
- `Documentation/MANUAL_ACCEPTANCE_TEST_PLAN.md` — HISTORICAL / REFERENCE.
- `Documentation/NEXT_PHASE_RECOMMENDATIONS.md` — HISTORICAL / REFERENCE.
- `Documentation/NEXT_SESSION_PROMPT.md` — HISTORICAL / REFERENCE.
- `Documentation/PRODUCT_DEBT.md` — HISTORICAL / REFERENCE.
- `Documentation/PRODUCT_RENAME_PLAN.md` — HISTORICAL / REFERENCE.
- `Documentation/PROJECT_COMPLETE_AUDIT.md` — HISTORICAL / REFERENCE.
- `Documentation/PROJECT_STATE.md` — HISTORICAL / REFERENCE.
- `Documentation/PUBLIC_READINESS_SCORECARD.md` — HISTORICAL / REFERENCE.
- `Documentation/PUBLIC_RELEASE_READINESS.md` — HISTORICAL / REFERENCE.
- `Documentation/REBRAND_MIGRATION_TEST_PLAN.md` — HISTORICAL / REFERENCE.
- `Documentation/RELEASE_STATE.md` — HISTORICAL / REFERENCE.
- `Documentation/ROADMAP.md` — HISTORICAL / REFERENCE.
- `Documentation/RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_TEST_PLAN.md` — HISTORICAL / REFERENCE.
- `Documentation/Reconstruction/RECOVERY_PLAN.md` — CURRENT.
- `Documentation/TECHNICAL_DEBT.md` — HISTORICAL / REFERENCE.
- `Documentation/TEST_PLAN.md` — HISTORICAL / REFERENCE.
- `Documentation/WEBSITE_ARCHITECTURE.md` — HISTORICAL / REFERENCE.
- `Documentation/WORKSPACE_MIGRATION_PLAN.md` — HISTORICAL / REFERENCE.
- `Documentation/WORKSPACE_ROLLBACK_PLAN.md` — HISTORICAL / REFERENCE.
- `docs/CORETEND_V2_AUDIT_AND_PLAN.md` — HISTORICAL / REFERENCE.
- `docs/TODO.md` — CURRENT.
- `docs/superpowers/plans/2026-09-25-coretend-baseline-reconciliation.md` — HISTORICAL / REFERENCE.
- `docs/superpowers/plans/2026-09-25-coretend-reconstruction-roadmap.md` — HISTORICAL / REFERENCE.
- `docs/superpowers/plans/2026-09-26-coretend-greenfield.md` — HISTORICAL / REFERENCE.
- `docs/superpowers/specs/2026-09-25-coretend-reconstruction-design.md` — HISTORICAL / REFERENCE.
- `docs/superpowers/specs/2026-09-26-coretend-greenfield-cahier.md` — HISTORICAL / REFERENCE.

## Independent follow-up evidence

On 2026-09-27, existing recovery edits were present at session start and preserved.
Revalidation ran 390 Swift Testing tests successfully (including 69 focused safety/
persistence tests). Prior ephemeral logs were absent; previous RED-run claims are
not independently re-established. A new excess-binding regression failed before
its fix and passed afterward. SafetyLogView already surfaces unavailable stores,
read errors and dropped-event counts; broad statements that *all* log reads are
silent are inaccurate. Its purge still suppresses errors. Approval refusals in
cleanup screens are discarded before outcome counts and remain P1.
