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

286 tests / 57 suites across the SwiftPM package (`DesignSystemTests`,
`IntegrityCoreTests`, `AppDiscoveryTests`, `PersistenceTests`,
`SystemMetricsTests`, `ScanCoreTests`, `SafetyCoreTests`, `FileRulesTests`,
`CoreTendAppTests`, plus `CoreTendIntegrationTests`,
`CoreTendAccessibilityTests`, `CoreTendPerformanceTests`,
`DemoFixturesValidatorTests`). One test is skipped — the Developer-ID
signature test, gated on a real codesigning identity. See
[Documentation/TESTING.md](Documentation/TESTING.md).

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
SystemMetrics, AppDiscovery, IntegrityCore, CoreTendApp) and
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

## Working rules for AI agents

This file, `CONTRIBUTING.md`, and `DESIGN.md` are the conventions. The rules
below are how an agent operates in this repo. (`.claude/` is git-ignored here
by choice — this section is the tracked source of truth; anything under
`.claude/rules/` is a local convenience mirror and defers to this.)

### Definition of done

A change is not done until all of these pass locally:

```sh
Scripts/build.sh release       # 0 warnings — required before committing
Scripts/test.sh                # 0 failures — the ONLY correct test command
Scripts/repository-doctor.sh   # private-data / placeholder / license checks
```

Never report tests as passing from a plain `swift test` — it omits the
CommandLineTools framework flags this project needs and behaves differently
(`Documentation/DECISIONS.md` D2). `Scripts/test.sh`'s `--no-parallel` is
deliberate, not a speed oversight.

### Release, signing, notarization — do not "fix" the unsigned state

- Every release so far ships **unsigned**, by explicit documented decision
  (`Documentation/HUMAN_BLOCKERS.md`, `Documentation/PUBLIC_RELEASE_READINESS.md`).
  It is blocked on a Developer ID Application identity being installed, which
  is a human action, not a code change. Do not add ad-hoc signing, self-signed
  certs, or workarounds to make it "signed".
- **Never regenerate** the CSR or private key in `Configuration/DeveloperID/`.
  They were created this project's way; regenerating breaks the pairing with
  the certificate that will eventually be issued against that exact CSR.
- `Scripts/sign-and-notarize.sh` is already written and correct — it needs an
  identity, not edits.
- Notarization credentials, when configured, are a `notarytool
  store-credentials` keychain profile referenced by name — never an API key or
  app-specific password in a script, env file, or commit.

### Public repository

This repo is public. No secret, API token, absolute personal path, private
data, or unreleased-media reference in any diff — `Scripts/check-private-data.sh`
gates it and is part of `repository-doctor.sh`. Localizable strings: add `en`
and `fr` together (`Documentation/LOCALIZATION.md`).

### The site in `Website/`

This repo also contains the CoreTend marketing site source under `Website/`
(not the workspace root — see the naming-collision note in the workspace
`DIRECTORY_MAP.md`). `DESIGN.md` governs it: system font stack only (no remote
fonts), functional color, Core Bloom as the single ambient animation, motion
tokens 150 / 300 / 550 ms, and full parity under `prefers-reduced-motion:
reduce`. The app's own `MC*` design tokens (`Documentation/DESIGN_SYSTEM.md`)
are a separate system — don't conflate them.

### Workspace context

This repo lives in the `~/Developer/Website` workspace (itself not a git
repo). `../../../CLAUDE.md` and `../../../_workspace/docs/CLAUDE_ONBOARDING_MAP.md`
describe the wider project family. One live cross-repo contract: this repo's
release workflow dispatches a `coretend-release` event that the portfolio's
`.github/workflows/sync-coretend.yml` consumes to refresh its case-study
metadata — a published release version must be real before anything downstream
states it. No build here may read `../../../shared/…`.

### Review

For a non-trivial change, get an independent review pass (a fresh context, not
the implementing one) before a PR — with extra weight on anything touching
`SafetyCore` / deletion paths, migrations, or the release pipeline.
