# First-Run Wizard — State Machine

This documents the actual first-run wizard as implemented in
`Sources/CoreTendApp/OnboardingView.swift` (UI) and
`Sources/CoreTendApp/OnboardingLogic.swift` (pure, unit-tested logic).

## Trigger and persistence
- Shown on launch when the `onboardingDone` setting is `false`.
- Current step is persisted in `onboardingStep` so the wizard resumes where it
  left off.
- Re-launchable from Settings ("Run setup assistant again"), which posts
  `.mcShowOnboarding`, observed by the main window.

## Steps (linear, index-driven)
Step index maps directly to a view (`OnboardingView` `switch step`):

| # | Step | What it does | Side effects |
|---|------|--------------|--------------|
| 0 | Welcome | Shows local/no-account/no-telemetry/open-source facts, app version, unsigned badge, and a move-to-Applications banner when `LaunchLocation.canOfferMove` | Optional user-space move to Applications |
| 1 | Security profile | Pick Recommended / Cautious / Custom. Only `dryRun` is a live knob; other safety fields are shown read-only | Sets in-memory `SecurityConfig` |
| 2 | File access | Explains Full Disk Access; opens System Settings and re-checks. "The app can't grant this itself" | Opens Settings; live FDA recheck |
| 3 | Optional protection | Best-effort ClamAV probe (availability + version + signatures, redacted path) and FSEvents availability. No auto-install | Read-only probes |
| 4 | Menu bar & notifications | Opt-in toggles. Enabling notifications requests real macOS authorization; never claims a grant it didn't get | Sets `menuBarEnabled`; requests notif auth |
| 5 | Folders & exclusions | Choose scannable folders (default: Downloads), add exclusions | In-memory folder/exclusion lists |
| 6 | System check | Runs the non-destructive self-diagnostic (`SystemCheck`) | Reads system inputs only |
| 7 (default) | Summary | Shows exactly the enabled options + privacy/restore facts + docs link. "Start" persists settings | Persists `dryRunDefault`, `securityProfile`, `exclusions`; sets `onboardingDone` |

## Security profile → config
`SecurityConfig.forProfile` returns the same **safe baseline** for every profile
(`dryRun: true`, `useTrash: true`, `mediumRiskRules: false`, `emptyTrash: false`,
`autoQuarantine: false`). Recommended vs Cautious differ only in intent/messaging;
Custom is that baseline the user then edits. No profile can ship an unsafe
default — enforced by `OnboardingLogicTests`.

## Launch-location classification
`LaunchLocation.detect(bundlePath:home:)` (order matters): App Translocation and
`/tmp` → `temporary`; `/Volumes/` → `diskImage`; `/Applications` or
`~/Applications` → `applications`; `~/Downloads` → `downloads`; else `other`.
The move-to-Applications offer appears whenever the location is not
`applications` (`canOfferMove`).

## System check
`SystemCheck.items` derives a status per capability from explicit inputs.
Required items (arch, macOS ≥ 14, SQLite) are `unavailable` when unmet; bundle,
resources, and SafetyCore are `actionRequired`; optional capabilities (FDA,
ClamAV, free space, configured location) degrade to `limited`, never block.
`SystemCheck.overall` is worst-wins: unavailable > actionRequired > limited > ok.
