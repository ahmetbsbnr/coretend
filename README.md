# CoreTend

<p align="center"><img src="Resources/Brand/Generated/Logo-Horizontal-light@2x.png" width="420" alt="CoreTend"></p>

<p align="center">Local, transparent and reversible care for macOS.</p>

CoreTend is an open-source macOS utility that explains storage findings before
an approved action. Scans run locally, dry run is the default, and supported
removals go to the Trash.

## Current product

The maintained branch contains the real Dashboard, Storage, Space Lens,
Duplicates, Applications, Integrity and Activity workflows, plus Settings,
onboarding, command palette and menu-bar status. Integrity reports native macOS
signals; it is not malware detection. Example media uses the versioned,
privacy-safe fixtures in `Resources/DemoFixtures/`.

The current public release candidate is
[`v0.9.1-rc.4`](https://github.com/ahmetbsbnr/coretend/releases/tag/v0.9.1-rc.4),
built from the tagged `main` commit that introduced the current Paper / Ink /
Cobalt app and site. rc.3 remains available only as historical evidence and is
not the recommended download.

[Product site](https://coretend.ahmetbsbnr.com) ·
[Portfolio case study](https://ahmetbsbnr.com/en/projets/coretend/) ·
[Documentation index](Documentation/README.md)

## Distribution status

The `v0.9.1-rc.4` direct-distribution build is ad-hoc signed, not Developer ID
signed, and not notarized. Gatekeeper may block the first launch. Verify the
published SHA-256, then use **System Settings → Privacy & Security → Open
Anyway**. Never disable Gatekeeper globally or remove quarantine recursively.

Developer ID and notarization are planned for a later release update. CoreTend
is not advertised as a Mac App Store product; see
[`Documentation/Release/APP_STORE_FEASIBILITY.md`](Documentation/Release/APP_STORE_FEASIBILITY.md).

## Build and test

```sh
swift build -c release
swift test
python3 Scripts/check-demo-fixtures.py
python3 Scripts/test-public-release-gate.py
python3 Website/build.py --output /tmp/coretend-site-dist
```

The app requires macOS 14 or later and Apple silicon (`arm64`). The website
build is self-contained: fonts, release facts, `latest.json` and `SHA256SUMS`
are generated from reviewed repository inputs.

## Privacy and safety

There is no account, advertising telemetry or analytics SDK. Scan data and
activity stay in the local app store. The only product network request is a
user-initiated update check for the public `latest.json` manifest. Read
[`PRIVACY.md`](PRIVACY.md) and [`SECURITY.md`](SECURITY.md) for the boundaries.

## Repository guide

- [`Documentation/README.md`](Documentation/README.md) — maintained index
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — development and review expectations
- [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE) — licensing
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — bundled font notices
- [`SUPPORT.md`](SUPPORT.md) — support route

## License

Source code is Apache-2.0. Documentation and original media retain the terms
listed in the repository notices.
