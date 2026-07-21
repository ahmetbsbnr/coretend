# MacCare Local

MacCare Local est un utilitaire macOS open source conçu pour analyser,
nettoyer, organiser et optimiser les Mac Apple Silicon. Il fonctionne
entièrement en local, sans compte, sans abonnement et sans télémétrie.
Chaque élément détecté est expliqué avant toute action, et les
suppressions utilisent par défaut la Corbeille afin de rester
réversibles.

> **Status: pre-1.0, not yet publicly released.** No signed build, no
> notarized binary, and no GitHub Release exists yet. This repository is
> under active development. Build from source if you want to try it —
> see [Build from source](#build-from-source) below.

MacCare Local is not affiliated with, endorsed by, or a product of Apple
Inc. or MacPaw Inc. It is an independent project. See
[TRADEMARKS.md](TRADEMARKS.md).

## Why

Mac cleanup utilities are common, but most are closed-source, subscription
gated, or vague about what they actually touch on disk. MacCare Local
aims to be transparent instead: every module explains what it looked at
and why an item was flagged, dry-run is the default, and deletions go to
the Trash unless you explicitly choose otherwise.

## Key features

- **Cleanup** — cache/log/leftover rules, grouped by rule, exclusions honored
- **Smart Care** — orchestrated low-risk cleanup with a dry-run-first flow
- **Duplicate Finder** — size → partial hash → SHA-256, hard-link aware
- **Space Lens** — visual treemap of disk usage
- **Similar Images** — on-device Vision feature-print clustering
- **Applications & Leftovers** — inventory, associated data, uninstall via Trash
- **Performance** — CPU/memory/pressure/disk/thermal metrics, login items
- **Privacy Cleaner** — browser cache profiling (Chrome/Firefox/Safari), cache-only
- **App Updates** — App Store/Sparkle-feed update detection, no silent downloads
- **Protection** — optional integration with a separately-installed ClamAV; honest "unavailable" state when ClamAV isn't present (see [Documentation/CLAMAV.md](Documentation/CLAMAV.md))
- **My Activity** — local history of what ran and what changed

## Compatibility

- Apple Silicon Macs (arm64)
- macOS 14 (Sonoma) or later
- No Intel build is currently produced

## Security & privacy

- No accounts, no network calls for core features, no telemetry, no analytics, no ads.
- Deletions default to the Trash — recoverable until you empty it.
- Every action is explained before it runs; dry-run is the default mode.
- Full detail: [PRIVACY.md](PRIVACY.md), [SECURITY.md](SECURITY.md), [Documentation/SAFETY_MODEL.md](Documentation/SAFETY_MODEL.md), [Documentation/THREAT_MODEL.md](Documentation/THREAT_MODEL.md).

## Install

No signed release build exists yet (see status banner above). For now,
build from source.

## Build from source

Requirements: macOS 14+, Apple Silicon, Swift 6 toolchain (Xcode or
Command Line Tools).

```sh
git clone <this-repo>
cd MacCare-Local
Scripts/doctor.sh      # checks your toolchain
Scripts/test.sh        # runs the test suite
Scripts/build.sh        # debug build
Scripts/package-local.sh  # assembles a local, unsigned .app bundle
```

See [DEVELOPMENT.md](DEVELOPMENT.md) and
[Documentation/BUILD_AND_INSTALL.md](Documentation/BUILD_AND_INSTALL.md)
for details, and [Documentation/BUILD_SYSTEM.md](Documentation/BUILD_SYSTEM.md)
for how the build is structured.

## ClamAV is optional

MacCare Local never bundles, embeds, or links ClamAV. If you install it
yourself (e.g. `brew install clamav`), the Protection module can use it.
Without it, Protection is honestly shown as unavailable rather than
faked. See [Documentation/CLAMAV.md](Documentation/CLAMAV.md) and
[Documentation/PROTECTION_LIMITATIONS.md](Documentation/PROTECTION_LIMITATIONS.md).

## Permissions

MacCare Local requests Full Disk Access to scan more of your Mac
accurately. It works with reduced coverage without it, and always
explains what each permission unlocks. See
[Documentation/FULL_DISK_ACCESS.md](Documentation/FULL_DISK_ACCESS.md).

## Known limitations

See [KNOWN_LIMITATIONS.md](Documentation/KNOWN_LIMITATIONS.md) for the current,
honest list (e.g. no code signing/notarization yet, ClamAV is an
optional external dependency, no privileged helper yet).

## Contributing

Contributions are welcome. Start with
[CONTRIBUTING.md](CONTRIBUTING.md) and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Good first issues will be
tracked in [Documentation/GOOD_FIRST_ISSUES.md](Documentation/GOOD_FIRST_ISSUES.md).

## Roadmap

See [ROADMAP.md](Documentation/ROADMAP.md) and [CHANGELOG.md](Documentation/CHANGELOG.md).

## Security

Please read [SECURITY.md](SECURITY.md) before reporting a vulnerability.
Do not open a public issue for security-sensitive reports.

## License

Code is licensed under [Apache-2.0](LICENSES/Apache-2.0.txt). Original
documentation and illustrations are licensed under
[CC-BY-4.0](LICENSES/CC-BY-4.0.txt). The "MacCare Local" name/logo are
covered separately — see [TRADEMARKS.md](TRADEMARKS.md). Third-party
components keep their own licenses — see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Full breakdown:
[Documentation/LEGAL_AND_LICENSE_STATUS.md](Documentation/LEGAL_AND_LICENSE_STATUS.md).
