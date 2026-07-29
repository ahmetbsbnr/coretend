# CoreTend

<p align="center">
  <img src="Resources/Brand/Generated/Logo-Horizontal-light@2x.png" width="420" alt="CoreTend">
</p>

<p align="center">Local, transparent and reversible care for macOS.</p>

<p align="center">
  <img alt="Version 0.9.0 public beta" src="https://img.shields.io/badge/version-0.9.0%20beta-135f4a">
  <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14%2B-5c54cc">
  <img alt="Apple Silicon arm64" src="https://img.shields.io/badge/architecture-arm64-94600a">
  <img alt="Apache 2.0 code license" src="https://img.shields.io/badge/code-Apache--2.0-135f4a">
</p>

CoreTend is an open-source macOS utility for reviewing storage, finding
clutter, understanding disk usage, inspecting applications and monitoring
system health. Scans explain what they found before an action runs. Dry run is
the default, and supported removals go to the Trash.

<p align="center">
  <picture>
    <source srcset="Website/assets/app/smart-care.webp" type="image/webp">
    <img src="Website/assets/app/smart-care.png" width="720"
      alt="CoreTend Smart Care window with module navigation and scan controls">
  </picture>
</p>

[Download 0.9.0 public beta](https://github.com/ahmetbsbnr/coretend/releases/tag/v0.9.0)
· [Product site](https://coretend.ahmetbsbnr.com)
· [Visual tour](https://coretend.ahmetbsbnr.com/en/demos.html)
· [Documentation](Documentation/DOCUMENT_INDEX.md)

## What CoreTend does

- **Smart Care** — orchestrates the low-risk cleanup rules and presents one
  review before execution.
- **Cleanup** — reviews caches, logs, diagnostic reports, build artifacts,
  incomplete downloads and opt-in higher-risk categories.
- **My Clutter** — finds large and old files, content-identical duplicates and
  visually similar images.
- **Space Lens** — builds a navigable, read-only map of disk usage.
- **Applications** — inventories installed apps, associated data and
  conservative leftovers; removals use the Trash.
- **Performance** — displays live CPU, memory, disk and thermal readings and
  inspects login agents without changing them.
- **Protection** — can invoke a separately installed ClamAV engine and keeps
  quarantine actions explicit.
- **Cloud Cleanup** — measures local versus logical cloud-file footprint
  without downloading files or deleting cloud content.
- **My Activity** — records actions locally, separates simulations from
  executed work and supports CSV export.
- **Settings and menu bar** — control dry run, exclusions, permissions and
  quick system status.

## Compatibility

- Apple Silicon (`arm64`)
- macOS 14 or later
- Swift 6 toolchain to build from source
- No Intel binary is published

## Download and verify

CoreTend 0.9.0 is a public beta. Its binaries are **unsigned** and
**not notarized**.

| Asset | Size | SHA-256 |
|---|---:|---|
| `CoreTend-0.9.0-arm64-unsigned.zip` | 2,833,085 bytes | `1d224b7655cfbcb15b5f9a37302c454775fae34d17d7f010f8c9ab026999b7d8` |
| `CoreTend-0.9.0-arm64-unsigned.dmg` | 5,192,666 bytes | `f2fbc7840ac4a5509836a495c51e72e6cfd52ef24e6cbdd792fa8404bd3f6c8d` |

```sh
shasum -a 256 CoreTend-0.9.0-arm64-unsigned.zip
shasum -a 256 CoreTend-0.9.0-arm64-unsigned.dmg
shasum -a 256 -c SHA256SUMS
```

### First launch

CoreTend is unsigned and not notarized, so macOS blocks the first launch. That
warning is accurate — no Apple Developer identity is attached to this build.

After copying CoreTend to `/Applications`:

- **macOS 15 Sequoia and later (including macOS 26):** double-click CoreTend
  once so macOS registers the block, then open **System Settings → Privacy &
  Security**, scroll to **Security**, and choose **Open Anyway**. Confirm with
  Touch ID or your admin password. Once per copy is enough.
- **macOS 14 and earlier:** Control-click the app and choose **Open**, then
  confirm. Apple removed this shortcut in macOS 15, so it has no effect on
  newer systems.

Do not disable Gatekeeper globally, and do not run a blanket quarantine-removal
command — the per-app step above is enough.

See [BUILD_AND_INSTALL.md](Documentation/BUILD_AND_INSTALL.md) for complete
installation and source-build instructions.

## Build and test

```sh
git clone https://github.com/ahmetbsbnr/coretend.git
cd coretend
bash Scripts/doctor.sh
bash Scripts/test.sh
bash Scripts/build.sh
bash Scripts/package-local.sh
```

The current full local validation is 296 tests in 58 suites, with Debug and
Release builds passing. This records a local result; it is not a CI badge.
The screenshot and website improvements on this branch are post-release work
and are not represented as changes to the 0.9.0 binary.

- [Architecture](Documentation/ARCHITECTURE.md)
- [Development setup](DEVELOPMENT.md)
- [Build system](Documentation/BUILD_SYSTEM.md)
- [Testing](Documentation/TESTING.md)
- [Feature inventory](Documentation/FEATURE_INVENTORY.md)

## Privacy and safety

Core features run locally. CoreTend has no account system, analytics,
advertising or telemetry. Optional malware-signature updates belong to the
separately installed scanning engine.

Path validation blocks protected roots and symlink escapes. Files are checked
again immediately before an approved action, and dry run remains enabled
unless the user explicitly disables it.

- [Privacy](PRIVACY.md)
- [Security policy](SECURITY.md)
- [Safety model](Documentation/SAFETY_MODEL.md)
- [Threat model](Documentation/THREAT_MODEL.md)

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md) and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening a change. For usage
questions, see [SUPPORT.md](SUPPORT.md). Report security issues through the
private process in [SECURITY.md](SECURITY.md), not a public issue.

The maintained direction is in [ROADMAP.md](Documentation/ROADMAP.md), and
released changes are recorded in [CHANGELOG.md](Documentation/CHANGELOG.md).

## Licenses and marks

Code is Apache-2.0. Original documentation and media are CC-BY-4.0.
Third-party material remains under its own terms. The name and visual identity
are covered separately.

- [License map](Documentation/LICENSING.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
- [Trademark policy](TRADEMARKS.md)
