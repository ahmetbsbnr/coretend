<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Project state

## Current checkpoint — 2026-09-04

- Working branch: `main`
- Published version/build: `1.0.0` / `1000`
- Current public release: stable `v1.0.0`, built from
  `0ecddeaef0cc0f79d2185632f9c4ff49d1b9230a`
- Public DMG: 4,938,110 bytes; SHA-256
  `0969ea2565b98fc950a589855ebafa2b811474fd1383092c3567e192f404534d`
- Platform: arm64, macOS 14.0+
- Distribution posture: Developer ID signed, Apple-notarized, stapled,
  SHA-256 and Minisign verified
- Product safety: reviewed selection, explicit confirmation, execution-time
  path validation and macOS Trash
- Integrity: native read-only provenance, code-signature and login-item facts;
  no external scanner or malware-detection claim
- Public site: bilingual shared shell with canonical `/en` and `/fr` routes;
  download route, updater, portfolio, and GitHub release agree on 1.0.0

The machine-readable checkpoint is
[`PROJECT_STATE.json`](PROJECT_STATE.json). Release provenance and checksums
are authoritative only in the final GitHub release assets and generated
public-release manifest.

## Current architecture

SwiftPM provides one `CoreTend` executable, the `CoreTendApp` UI library and
first-party ScanCore, SafetyCore, FileRules, DesignSystem, Persistence,
SystemMetrics, AppDiscovery and IntegrityCore modules. `swift-testing` is a
test-only dependency and has no release-bundle footprint.

## Release gates

The candidate must pass Debug/Release builds, the complete Swift and Xcode
test surfaces, localization/resource checks, repository doctor, security and
secret gates, visual/accessibility site tests, DMG mount/copy/launch checks,
signature verification and local-versus-public checksum equality.

Quality follow-up complete by maintainer attestation: interactive VoiceOver,
keyboard, focus, Dynamic Type, second-Mac/different-supported-macOS testing,
and 44-frame native FR/EN light/dark visual matrix all pass. Exact secondary
hardware and macOS build identifiers were not supplied. Next-release
signed-artifact provenance workflow is integrated; retrospective provenance
for 1.0.0 remains intentionally absent because it would misidentify builder.
