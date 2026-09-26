# CoreTend greenfield — source baseline

**Observed:** 2026-09-26 14:30 UTC. **Purpose:** record source-worktree facts for the greenfield rebuild; not a release attestation and not product acceptance. **Cahier:** `docs/superpowers/specs/2026-09-26-coretend-greenfield-cahier.md` (review pending).

> This report describes this worktree only. Branch names, configuration manifests and README badges do not prove what is publicly downloadable.

## 1. Repository snapshot

| Fact | Observed value |
|---|---|
| Worktree branch | `claude/keen-gates-6dtpoi` |
| HEAD | `4306566892af86a400fcfbd8f96a84c3d8afc05b`, 2026-09-26, `docs: pin greenfield workspace boundary` |
| Branch relation | 2 local commits ahead of its configured upstream at time of observation |
| Named remotes | `origin`, `archive` (URLs intentionally omitted) |
| Local branches | `claude/keen-gates-6dtpoi`, `develop/v2`, `feature/app-store-migration`, `main`, `maintenance/1.x`, `reconstruction/baseline` (the last is a linked worktree) |
| Tracked worktree changes | None at snapshot |
| Pre-existing untracked paths | `.claude-flow/`, `Documentation/Captures/`, `Xcode/`, `docs/superpowers/plans/`, `docs/superpowers/specs/2026-09-25-coretend-reconstruction-design.md`, `graphify-out/` |
| User data / real Trash accessed | No |
| Build, tests, browser, signing or release gates in this baseline pass | Not run |

Untracked paths are listed for preservation only. Their contents were not inspected except the earlier reconstruction design/plan documents needed to locate context. Do not clean, reset, replace or move them.

## 2. Build and source shape

- `Package.swift` declares Swift tools 6.0 and minimum macOS 14.
- SwiftPM products include `CoreTend` executable, read-only `coretend-cli`, and libraries `ScanCore`, `SafetyCore`, `FileRules`, `DesignSystem`, `Persistence`, `SystemMetrics`, `AppDiscovery`, `IntegrityCore`.
- SwiftPM declares `swift-testing` as dependency and has a separate `CoreTendUITests` target. This manifest alone does not prove the full build/test workflow passes.
- Source snapshot: 62 files under `Sources/`; test snapshot: 48 files under `Tests/`; documentation snapshot: 335 files under `Documentation/`. These counts describe tree size only.
- Localization resources include `Base.lproj` and `fr.lproj`; SwiftPM default localization is English.
- README describes eight primary product destinations. `ModuleID` also contains grouped/transverse identities; it is not treated as a conflicting feature count without reviewing the information architecture.
- The repository README specifies SwiftPM as app build system. An untracked `Xcode/` path exists and remains user-owned/uninspected; it is not used to infer the tracked build architecture.

## 3. Release and state claims

| Claim | Local source evidence | Baseline status |
|---|---|---|
| Active product line | README describes shipping 1.x plus 2.0 pre-alpha; current branch name is a feature branch; `docs/CORETEND_V2_PROGRAM.md` describes v2 | **Observed: v2 is active direction on this branch.** No claim that it is published. |
| Version | `Configuration/published-release.json` says 1.0.2; `Documentation/PROJECT_STATE.md` says current version 1.0.2 but its release section identifies v1.0.0; `Documentation/CURRENT_PROJECT_STATE.json` identifies 0.9.1-rc.5; README reports 1.0.2 fixes | **CONTRADICTED across state files.** Do not choose a public version from these documents alone. |
| Historical published artifact | `PROJECT_STATE.md` records v1.0.0, signature/notarization claims and a known launch defect; no downloaded artifact was checked in this pass | **DOCUMENTED, not independently verified here.** |
| Signed/notarized current artifact | `published-release.json` has `signed=true` and `notarized=true`; README shows signed/notarized badge | **CONFIGURED/CLAIMED, artifact UNKNOWN.** No artifact bytes or stapling ticket verified. |
| Trash-only behavior | `Sources/SafetyCore/SafetyCore.swift:266-285` calls `removeItem` after Trash fails for temporary paths, then records `executed`; `Tests/SafetyCoreTests/PathValidatorTests.swift:200-208,249-264` expects original fixture files to disappear | **CONTRADICTED by current source.** This is permanent deletion under temp roots, not a Trash move. Greenfield requirement rejects it; no test was run here. |
| Test count | Historical documents report different counts (including 687); this pass ran no tests | **UNKNOWN for current branch.** Do not reuse historic counts. |
| Direct distribution / App Store | README describes direct release and cask; v2 program identifies a constrained App Store build and unresolved product choice | **CONTRADICTED / decision required.** Greenfield cahier defaults to direct local packaging; no App Store scope. |
| Public website state | Website sources exist; no browser gate run in this pass | **Implementation exists; current rendered/released state UNKNOWN.** |

No version, checksum, signature, notarization, test count, release channel or public deployment is asserted as verified by this baseline.

## 4. Safety and privacy facts to preserve

- Greenfield cahier requires scans to be read-only and all eligible file moves to pass through a typed SafetyCore contract, confirmation and execution-time revalidation.
- Production removal must use macOS Trash only. Trash failure must preserve the source and report an error; no permanent-delete fallback.
- Automated tests use temporary synthetic roots and a fixture Trash adapter. They must not inspect the maintainer's home, real user store or real Trash.
- No telemetry, account, cloud sync or analytics. Network, if update-check behavior remains, must be explicit, user-initiated and download no app binary.
- None of these invariants was re-executed in this baseline pass; they are requirements, not newly verified results.
- Static source review found the active SafetyCore fallback described above. Do not treat the source suite's current temporary-path execution tests as proof of Trash-only behavior; greenfield acceptance must inject a fixture Trash adapter, force a Trash failure, and prove source preservation plus an error event.

## 5. Open baseline work

1. Review and approve the greenfield cahier before an implementation plan or code.
2. After approval, capture a full requirement-to-source/test evidence matrix without treating inventory/docs as behavioral proof.
3. Re-run safe local build and approved test gates only after the greenfield workspace exists; fixture-only tests remain mandatory.
4. Resolve version/channel claims only from maintainer decision plus artifact-level evidence. This goal does not authorize publishing, pushing or tagging.
5. Choose numeric performance budgets only after reproducible measurements on declared hardware.
