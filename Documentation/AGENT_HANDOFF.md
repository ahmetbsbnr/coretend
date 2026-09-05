# CoreTend Agent Handoff

## Git
- Current branch: `feat/restore-center` (from `feat/privacy-lab` HEAD `d729118`)
- Current HEAD: `cf00f20`
- Commits on this branch: `d2ecb8b` (feat), `20ba7f2` (test), `cf00f20` (docs)
- Working tree: clean for tracked files. Pre-existing untracked agent
  scaffolding (`AGENTS.md`, `CLAUDE.md`, `.agents/`, `.codex/`,
  `.agent-setup-backups/`, `Documentation/AGENT_HANDOFF.md`,
  `Documentation/AGENT_OPERATING_CONTRACT.md`) predates this session; not
  created or committed here.
- Not pushed. Not merged. `main` untouched. No history rewrite.
- Checkpoints preserved: `feat/privacy-lab` @ `d729118`, `feat/developer-center` @ `6d5ad2e`.

## Completed — Restore Center (real end-to-end restore)
- `Sources/SafetyCore/RestoreManifest.swift` — `RestoreManifestRecord`,
  `RestoreManifestSink`, `RestoreValidationError`, `RestoreValidator`,
  `FilesystemIdentity` (Foundation + Darwin).
- `Sources/SafetyCore/SafetyCore.swift` — `SafetyCenter` captures the real
  `resultingItemURL` and emits a manifest for every successful `trashItem`
  move (never the permanent `removeItem` fallback). `sink as? RestoreManifest
  Sink` auto-detect + explicit `init(validator:sink:restoreSink:)`.
- `Sources/Persistence/Store.swift` — DB migration **v7** `restore_manifest`
  (`IF NOT EXISTS` DDL, matching v5/v6 style), `RestoreManifestItem`,
  `RestoreManifestState`, `Store: RestoreManifestSink`, query/state/clear/
  prune methods. Retention 90d / 30d-terminal.
- `Sources/CoreTendApp/RestoreService.swift` — `RestoreService` actor,
  `RestoreAvailability`, `RestoreItemView`, `RestoreOperationGroup`,
  `RestoreOutcome`, `RestoreExecutionSummary`, `RestoreReversibility`,
  `RestoreDisplay`.
- `Sources/CoreTendApp/RestoreCenterView.swift` — `RestoreCenterViewModel`
  (generation-token load guard) + `RestoreCenterView`.
- Nav: `ModuleID.restoreCenter` (System sidebar group, after `.myActivity`),
  `MCModuleIdentity.restoreCenter`.
- Localization: 55 keys added to both `Base.lproj` / `fr.lproj` (parity
  933 == 933).
- Tests: 41 new — `RestoreManifestStoreTests` (8), `RestoreCaptureTests` (4,
  SafetyCore), `RestoreServiceTests` (22), `RestoreAdvisorReversibilityTests`
  (4), `RestoreCaptureIntegrationTests` (2), `RestoreLocalizationTests` (3);
  `StoreTests` (v6→v7), `AdvisorServiceTests` (guard renamed/kept),
  `CommandPaletteTests` (+restoreCenter), `DiagnosticReportTests` (+1).
- Docs: `RESTORE.md` (rewritten), `SAFETY_MODEL.md` (+section),
  `PERSISTENCE.md` (+bullet, +migrations summary), `PRIVACY.md` /
  `Documentation/PRIVACY.md`, `FEATURE_MATRIX.md` (+row), `TODO.md`,
  `PROJECT_STATE.json` (tests 603, branch list).

## In progress
- None.

## Not started (out of scope for this vertical)
- Automatic conflict resolution on restore (deliberately not built —
  collisions are refused, not renamed/overwritten).
- Verified real external-volume restore (model uses synthetic volume
  identity in tests).

## Architecture decisions made
- Capture at the chokepoint (`SafetyCenter`), not per call site. The sink is
  auto-detected from the existing `sink:` argument, so no call site changed
  and there is no second execution path. Recovery Plan / Developer Center /
  Applications uninstall get manifests for free (verified by test).
- `safety_log` stays redacted. `restore_manifest` is the single table with
  real paths, correlated to the audit log only by `operation_id`.
- Restore is a guarded `FileManager.moveItem` back to the recorded original
  path only — `RestoreValidator` (a sibling of `PathValidator` for the other
  direction), destination pinned, protected roots rejected, occupied
  destination refused (never overwritten).
- `AdvisorService.advise(...)` UNCHANGED — scan-result findings stay `.trash`
  (no manifest exists yet). `RestoreReversibility.of(_:)` is the only
  producer of `.restorableByCoreTend`, from live availability.
  `RecoveryPlanEligibility` unchanged (no regression).
- Retention 90d, 30d for terminal states — mirrors Timeline's 90d window.

## Contracts that must not change
- See `Documentation/AGENT_OPERATING_CONTRACT.md`,
  `Documentation/SAFETY_MODEL.md` → "Restore Center".
- `safety_log` must remain redacted; `restore_manifest` is local only,
  excluded from `DiagnosticReport` / Timeline / audit exports.
- Restore never overwrites an occupied destination.
- "Forget Restore History" never empties the Trash.
- All prior verticals' contracts unchanged.

## Verification (at HEAD cf00f20)
- Build: `Scripts/build.sh` (debug + release) — `Build complete!`, 0 warnings.
- Tests: `Scripts/test.sh` — 603 passed, 0 failing (was 562).
- Repository doctor: `Scripts/repository-doctor.sh` — all checks passed.

## Known limitations / HUMAN VERIFICATION REQUIRED
- Real external-volume restore (`/Volumes/…/.Trashes/<uid>`, unmount/remount)
  — model exercised with synthetic volume identity only.
- Interactive VoiceOver / full keyboard traversal / focus order on
  `RestoreCenterView` — structural semantics in place, not interactively
  exercised.
- Cross-volume restore `moveItem` is copy+delete and not atomic; same-volume
  (the normal case) is a rename and is atomic.

## Next concrete action
- None for this vertical. macOS-integration readiness (Finder Extension,
  App Intents/Shortcuts, WidgetKit, scheduled scans, notifications) is
  analyzed (not implemented) at the end of the final report.
