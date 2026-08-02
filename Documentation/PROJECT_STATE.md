<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Project state

## Current checkpoint — 2026-08-02

- Working branch: `release/v0.9.1-rc.5`
- Candidate version/build: `0.9.1-rc.5` / `915`
- Current public release: `v0.9.1-rc.4` until rc.5 is published and its
  downloaded asset is independently verified
- Platform: arm64, macOS 14.0+
- Distribution posture: ad-hoc signed, unsigned identity, not notarized
- Product safety: reviewed selection, explicit confirmation, execution-time
  path validation and macOS Trash
- Integrity: native read-only provenance, code-signature and login-item facts;
  no external scanner or malware-detection claim
- Public site: bilingual shared shell with canonical `/en` and `/fr` routes;
  rc.5 metadata is not exposed before release publication

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

The remaining future work after rc.5 is limited to Developer ID signing,
notarization and a later Mac App Store feasibility study.
