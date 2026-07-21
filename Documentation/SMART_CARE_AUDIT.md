# Smart Care Audit (Step 2)

Audit of the Smart Care orchestrator (`Sources/MacCareApp/SmartCareView.swift`,
`SmartCareViewModel`) against the functional-completion safety matrix. Each row
states the verified behavior, where it lives, and the test backing it. "Honest
unavailable" means the module is shown as such in the UI, never faked.

## Module availability

| Module | State | Backing |
|---|---|---|
| Cleanup | implemented, enabled | `initialModules()`; drives `ScanEngine(rules: UserCleanupRules.all)` |
| Protection | unavailable (honest) | `.unavailable(smartcare.protection_unavailable)` — never claims to scan without ClamAV |
| Performance | unavailable (honest) | `.unavailable(smartcare.performance_unavailable)` |
| Applications | unavailable (honest) | `.unavailable(smartcare.applications_unavailable)` |

## Safety matrix

| Property | Guarantee | Where | Test |
|---|---|---|---|
| Default selection | Only reversible, low-risk, preselected findings are auto-executable | `SmartCareViewModel.autoExecutableFindings` | `SmartCareAutoExecuteTests` |
| Risky rules unchecked | No preselected rule is medium/high risk; new installer/archive/Xcode rules ship `preselect:false` + `risk:.medium` | `UserCleanupRules.all` | `CleanupRuleCatalogTests` |
| Dry-run default | Honors persisted `dryRunDefault`; absent/any-non-`"false"` value stays dry-run ON | `loadDryRunDefault` → `AppEnvironment.dryRunEnabled` | `DryRunDefaultTests` |
| Reversibility | Execution routes through `SafetyCenter` (Trash-based, path-validated) | `runCare()` → `SafetyCenter.approve/execute` | `SafetyCore` suite |
| Path validation | Only paths under `UserCleanupRules.allowedRoots(home:)` are approvable | `PathValidator` in `runCare()` | `PathValidatorTests` |
| Exclusions honored | User-excluded paths are filtered before scanning | `start()` reads `store.exclusions()` into `ScanConfiguration` | `PersistenceTests` exclusions |
| Real totals | found/bytes are the uncapped stream totals, not derived from the 5000-capped display list | `start()` `totalFindingCount/totalFoundBytes` | `Totals beyond display cap` |
| Bounded parallelism | Rules run under bounded concurrency, identical results across levels | `ScanEngine` | `ScanEngine bounded concurrency` |
| Cancellation | `cancel()` stops the stream and returns to idle; partial results kept | `cancel()` / `.cancelled` | `ScanEngine` cancellation |
| Partial errors | A failing rule never poisons the run | `ScanEngine` | `failingRuleDoesNotPoisonRun` |
| No auto-delete post-scan | Scan ends in `.review`; execution requires explicit `runCare()` | `start()` sets `phase = .review` | (state machine) |
| Summary honesty | Activity summary distinguishes dry run vs real Trash move; freed bytes from executed ops only | `runCare()` `ActivityRecord` | reviewed |
| History | Scan and care both record `ActivityRecord` | `AppEnvironment.record` | `MyActivity` suite |

## Deferred / not claimed

- Protection, Performance, Applications remain unavailable modules — not
  simulated. Their real implementations are tracked under Steps 3/5.
- Smart Care never empties Trash automatically and never immediately deletes
  after a scan; both are structurally impossible in the current state machine.
