# Development

Entry point for contributors. See [CONTRIBUTING.md](CONTRIBUTING.md) for
process (DCO, PR flow); this file is the technical how-to.

## Prerequisites

macOS 14+, Apple Silicon, Swift command-line tools (Xcode not required).

```sh
git clone https://github.com/ahmetbsbnr/coretend.git
cd coretend
Scripts/doctor.sh        # verifies prerequisites, fails loudly if something's missing
Scripts/bootstrap.sh     # one-time setup
```

## Build

```sh
Scripts/build.sh          # debug
Scripts/build.sh release  # release, must build with 0 warnings before committing
```

## Test

```sh
Scripts/test.sh   # do NOT use plain `swift test` — see Documentation/DECISIONS.md D2
```

83+ tests across the SwiftPM package (`DesignSystemTests`,
`MalwareEngineTests`, `AppDiscoveryTests`, `PersistenceTests`,
`SystemMetricsTests`, `ScanCoreTests`, `SafetyCoreTests`, `FileRulesTests`,
`CoreTendAppTests`). See [Documentation/TESTING.md](Documentation/TESTING.md).

## Package and run locally

```sh
Scripts/package-local.sh   # → build/CoreTend.app (ad-hoc signed)
```

## Repository hygiene before committing

```sh
Scripts/repository-doctor.sh   # private-data/placeholder/license checks
Scripts/check-licenses.sh
Scripts/check-private-data.sh
Scripts/check-placeholders.sh
```

## Where things live

See [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md) for the
module graph (SafetyCore, ScanCore, FileRules, DesignSystem, Persistence,
SystemMetrics, AppDiscovery, MalwareEngine, CoreTendApp) and
[Documentation/ARCHITECTURE_OVERVIEW.md](Documentation/ARCHITECTURE_OVERVIEW.md)
for a narrative walkthrough of one end-to-end flow.

## Constraints (non-negotiable)

- SwiftUI/native macOS only for app code — no React, Electron, WebView,
  Tauri, or JS runtime inside the app itself.
- Destructive engines only ever go through `SafetyCore.PathValidator` —
  never raw `FileManager` calls on user-supplied paths.
- No new dependency without checking `Documentation/DEPENDENCIES.md`.
- No telemetry, no network calls from app code.

## Cleaning up a dev machine

```sh
Scripts/clean.sh             # build artifacts
Scripts/uninstall-local.sh   # this app's local data, original two-path version (see Documentation/UNINSTALL.md)
Scripts/uninstall.sh         # public-facing uninstaller: --dry-run (default) / --keep-quarantine / --remove-all
Scripts/test-uninstall.sh    # shell tests for uninstall.sh (dry-run no-ops, allowlist, symlink refusal)
```

`Scripts/uninstall.sh` supersedes `uninstall-local.sh` for anyone following
the public docs: same two owned paths (Application Support dir + prefs
plist) plus the app bundle, but with explicit modes, a strict allowlist of
canonicalized paths, and refusal to follow symlinks. `uninstall-local.sh` is
kept working as-is rather than deleted.
