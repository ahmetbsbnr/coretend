# Pre-Rebrand Baseline — MacCare Local 0.8.0

Canonical, verified snapshot of the product exactly as it stands before any
0.8.1A brand-clearance/workspace work begins. Every value below was read
directly from Git/the filesystem/the build this session — nothing copied
from a prior report without re-verification.

## Git state (verified this session)

- Repo: `~/Documents/MACCLEAN`
- Branch: `feat/functional-completion`
- HEAD: `a3fe7f716f80e71e43d7b7ce2f25db6256c3451c`
- `git status --short --untracked-files=all`: empty (clean tree)
- `git remote -v`: none configured
- `git tag --list`: none
- `git worktree list`: single worktree, no others

## Build/test state (verified this session)

- `bash Scripts/test.sh`: **250 tests, 55 suites, 0 failures**
- `swift build`: 0 project warnings
- `swift build -c release`: green

## Product identity (as shipped today — nothing renamed yet)

| Field | Value | Source |
|---|---|---|
| Product name | MacCare Local | `Resources/Info.plist` CFBundleName/CFBundleDisplayName |
| Bundle identifier | `local.maccare.app` | `Resources/Info.plist`, `Configuration/PublicIdentity.example.json` |
| Executable / process name | `MacCareLocal` | `Package.swift`, `Resources/Info.plist` CFBundleExecutable |
| SwiftPM package name | `MacCareLocal` | `Package.swift` |
| Marketing version | 0.8.0 | `Resources/Info.plist`, `Configuration/PublicIdentity.example.json` |
| Repo directory name | `MACCLEAN` | `~/Documents/MACCLEAN` |
| Repo URL (planned, not live) | `https://github.com/ahmetbsbnr/mac-care-local` | `Configuration/PublicIdentity.example.json` |
| Maintainer GitHub handle | `ahmetbsbnr` | `Configuration/PublicIdentity.example.json` |
| Developer domain (planned) | `ahmetbsbnr.com` | `Configuration/PublicIdentity.example.json` |
| Website URL (planned, not live) | `https://maccare.ahmetbsbnr.com` | `Configuration/PublicIdentity.example.json` |
| ZIP/DMG artifact naming | `MacCare-Local-0.8.0-arm64-unsigned.{zip,dmg}` | `Release/latest.json` |

## SwiftPM target/library names (all still "MacCare*"/generic)

`MacCareApp` (executable target), `ScanCore`, `SafetyCore`, `FileRules`,
`DesignSystem`, `Persistence`, `SystemMetrics`, `AppDiscovery`,
`MalwareEngine` (+ matching `*Tests` targets). None of the library names are
brand-coupled except the app target/executable itself.

## Local data paths (current, pre-migration)

- SQLite store: `~/Library/Application Support/MacCareLocal/store.sqlite`
  (`Sources/Persistence/Store.swift`)
- Quarantine directory: `~/Library/Application Support/MacCareLocal/Quarantine`
  (`Sources/MalwareEngine/MalwareEngine.swift`, `Quarantine.defaultDirectory()`)
- FSEvents watch fingerprints: same `Application Support/MacCareLocal/`
  parent directory (`watch-fingerprints.json`, sibling to Quarantine — see
  `Sources/MacCareApp/ProtectionView.swift`)
- `UserDefaults`/`@AppStorage` keys: `menuBarEnabled`, `onboardingDone`,
  `onboardingStep`
- SQLite-backed settings (inside `store.sqlite`'s `settings` table, not
  UserDefaults): `dryRunDefault`, `securityProfile`, plus the `exclusions`
  table (paths) and `activity` table (history)

## Publication state

- **repositoryPushed**: false — no remote configured at all
- **releasePublished**: false — no GitHub release, `Release/latest.json` has
  no `downloadURL`
- **signed**: false, **notarized**: false (`Release/latest.json`)
- **Configuration/PublicIdentity.local.json**: does not exist (gitignored
  override file; legal name/address/security contact remain
  `[..._TO_DEFINE]` placeholders in the committed `.example.json`)

## Trademark/legal files present today

- `LICENSE` — Apache-2.0 (code) / CC-BY-4.0 (docs) / trademark handled
  separately, per its own three-way split declaration
- `TRADEMARKS.md` — exists, keeps "MacCare Local" branding governance
  separate from the code license
- `NOTICE`, `COPYRIGHT` — present, no rebrand-relevant content beyond
  reflecting the current name

## What this document is for

This is the reference point every 0.8.1A brand-clearance and workspace-
migration document measures against. If a later document needs "the state
of MacCare Local before rebrand work started," it is this one — not a
recollection, not the 0.7.1-era `CURRENT_PROJECT_STATE.json` snapshot that
predates it.
