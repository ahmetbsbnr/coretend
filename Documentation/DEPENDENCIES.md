# Dependency audit

Verified against `Package.swift` (single source of truth for build
dependencies) and a repo-wide grep for build/dev tooling. Last checked:
2026-07-20, commit `b248bf3`.

## SwiftPM dependencies (external packages)

**None.** `Package.swift` declares zero `.package(url:...)` entries. Every
target (`ScanCore`, `SafetyCore`, `FileRules`, `DesignSystem`, `Persistence`,
`SystemMetrics`, `AppDiscovery`, `MalwareEngine`, `CoreTendApp`) is first-party
Swift code depending only on Apple's system frameworks (Foundation,
SwiftUI, AppKit, etc.) and, at runtime, an optional user-installed
`clamscan` binary shelled out to as a subprocess — never linked, never
vendored (see `Documentation/CLAMAV.md`).

| Name | Version | Source | License | Usage | Necessity | Risk | Native alternative | Maintenance | Bundled in app |
|---|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — | — | — |

There is nothing to remove: the dependency count is already zero.

## Runtime, non-linked external tool

| Name | Version | Source | License | Usage | Necessity | Risk | Native alternative | Maintenance | Bundled in app |
|---|---|---|---|---|---|---|---|---|---|
| ClamAV (`clamscan`) | user's installed version (not pinned) | Homebrew/MacPorts/manual, user-installed | GPL-2.0 (ClamAV project; not linked or redistributed by us) | Optional malware signature scan in Protection tab | Optional feature, not required for core app function | Low — invoked as a subprocess via `Process` with argument-array (no shell), read-only scan, output parsed defensively | None built into macOS with comparable signature-DB scanning; XProtect exists but is not user-invokable | Maintained upstream by the ClamAV project, outside this repo's control | No — never bundled, downloaded, or embedded |

## Build / developer tooling

Grepped `Scripts/*.sh` and repo root for Brewfile, Cartfile, podspec,
swiftlint/swift-format config: none found. Build tooling is exactly
Xcode/Swift toolchain (`swift build`, `swift test`) plus the shell scripts
in `Scripts/`, which use only POSIX/macOS-standard utilities (`ditto`,
`codesign` where applicable, `hdiutil`, etc. — no third-party CLI
dependency).

## Policy going forward

Any new dependency (SwiftPM package or shelled-out external tool) added in
future work must be added to this matrix in the same PR, with license,
necessity, and risk stated explicitly. Prefer Apple system frameworks and
the standard library first; add nothing "for later."
