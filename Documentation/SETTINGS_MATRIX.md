# Settings Matrix — generated, do not hand-edit

Source of truth: `Documentation/settings-matrix.json`. Regenerate with
`Scripts/generate-settings-matrix.py`. The generator also fails if the
declared settings do not exactly match those present in `Sources/`
(no orphaned or undocumented public setting).

| ID | Label | Default | Storage | Type | Consumer(s) | Effect | Restart | Availability | Test | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| menuBarEnabled | Menu bar item enabled | true | @AppStorage (UserDefaults) | Bool | MacCareApp.swift (MenuBarExtra isInserted), SettingsView.swift toggle | Inserts/removes the Core Bloom menu-bar item live. | no | always | generate-settings-matrix.py --check (repository-doctor gate) | VERIFIED_COMPLETE |
| onboardingDone | Onboarding completed | false | @AppStorage (UserDefaults) | Bool | MacCareApp.swift MainWindow (gates first-run onboarding sheet) | When false, the first-run onboarding is shown on launch; set true on completion. | no | always | generate-settings-matrix.py --check (repository-doctor gate) | VERIFIED_COMPLETE |
| onboardingStep | Onboarding step index | 0 | @AppStorage (UserDefaults) | Int | OnboardingView.swift (current wizard step) | Persists progress through the onboarding wizard so it resumes at the same step. | no | always | generate-settings-matrix.py --check (repository-doctor gate) | VERIFIED_COMPLETE |
| dryRunDefault | Dry run by default | true | Persistence Store settings table (key/value) | Bool (stored as "true"/"false") | CleanupView.swift, SmartCareView.swift (via AppEnvironment.dryRunEnabled), SettingsView.swift toggle | Controls whether Cleanup and Smart Care start in dry-run (preview) mode instead of acting. | no (loaded on view appear) | always | AppEnvironmentDryRunTests, generate-settings-matrix.py --check (repository-doctor gate) | VERIFIED_COMPLETE |
| exclusions | Excluded paths | [] (empty) | Persistence Store exclusions table (path list) | [String] (paths) | CleanupView.swift, SmartCareView.swift (filters findings), SettingsView.swift (add/remove), DiagnosticReport.swift (count) | Paths the user has excluded are never included in cleanup/care findings. | no | always | generate-settings-matrix.py --check (repository-doctor gate) | VERIFIED_COMPLETE |
| securityProfile | Security profile | recommended | Persistence Store settings table (key/value) | String (recommended/cautious/custom) | OnboardingView.swift (persists the first-run wizard profile choice) | Records which security profile the user picked at first run. Informational; the only live knob a profile sets is dryRunDefault. | no | always | OnboardingLogicTests (profile→config mapping), generate-settings-matrix.py --check (repository-doctor gate) | VERIFIED_COMPLETE |

Total settings: 6
