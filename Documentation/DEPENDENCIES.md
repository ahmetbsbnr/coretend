# Dependency audit

Verified against `Package.swift` (single source of truth for build
dependencies) and a repo-wide grep for build/dev tooling.

## SwiftPM dependencies (external packages)

**One, test-only.** `Package.swift` declares `swift-testing` as an explicit
dependency, pinned via `Package.resolved`. It exists solely so `swift test`
works on machines with Command Line Tools only (no Xcode.app, which
otherwise ships the `Testing` module built in). It is linked only into
`testTarget`s — never into the `CoreTendApp` executable or any of the
shipped libraries — so it has zero footprint in the release binary.

Every shipping target (`ScanCore`, `SafetyCore`, `FileRules`, `DesignSystem`,
`Persistence`, `SystemMetrics`, `AppDiscovery`, `IntegrityCore`,
`CoreTendApp`) remains first-party Swift code depending only on Apple's
system frameworks (Foundation, SwiftUI, AppKit, etc.). There is no runtime
dependency on ancien scanner externe or any other third-party tool — the prior optional
`ancien-scanner` subprocess integration (`LegacyScanner`) was fully removed; see
`Documentation/LEGACY_SCANNER_DECISION.md`.

| Name | Version | Source | License | Usage | Necessity | Risk | Native alternative | Maintenance | Bundled in app |
|---|---|---|---|---|---|---|---|---|---|
| swift-testing | 0.99.0 (pinned) | github.com/apple/swift-testing | Apache-2.0 | Test target dependency only (`#expect`/`@Test`) | Needed for `swift test` to run outside Xcode.app | Low — Apple first-party, test-only, not in release binary | Xcode's bundled Testing module (requires full Xcode install, not just CLT) | Actively maintained by Apple | No |
| swift-syntax | 600.0.1 (pinned, transitive via swift-testing) | github.com/swiftlang/swift-syntax | Apache-2.0 | Macro expansion backing swift-testing's `@Test`/`#expect` | Transitive requirement of swift-testing | Low — Apple first-party, test-only, not in release binary | n/a | Actively maintained by Apple | No |

## Runtime, non-linked external tool

None. The prior optional runtime dependency on a user-installed `ancien-scanner`
(ancien scanner externe) binary was removed with the `LegacyScanner` module; see
`Documentation/LEGACY_SCANNER_DECISION.md`. Integrity
(`Sources/IntegrityCore`) reads only signals macOS already records and
invokes no external process.

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
