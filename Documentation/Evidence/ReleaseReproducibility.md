# Reproducible Release build evidence

**Date:** 2026-09-27
**Host:** arm64, macOS 27.0, Xcode 27.0 SDK (local); GitHub Actions `macos-26-arm64` runner previously compared
**Source:** app sources from `db5d52f`; local tree includes CI reproducibility-smoke changes after `de5ef65`. Product-source bytes were unchanged by the smoke harness edit.

`python3 Scripts/test_clean_release_builds.py` builds each product twice from empty SwiftPM scratch directories under one unique temporary root inside `.build`. Each product reuses same physical scratch path for second build after safely removing and recreating only owned scratch directory. The script pins `MACOSX_DEPLOYMENT_TARGET=14.0` and passes `-Xlinker -no_uuid`: Apple linker emits random `LC_UUID` on each link, duplicating UUID into code signature and shifting later bytes. Disabling optional UUID load command makes raw Mach-O reproducible; all four Release builds completed without warnings. Unique root removed after run. Gate requires exact SHA-256 equality. Unit fixtures prove reset scope and symlink/out-of-root rejection.

| Product | Scratch build 1 SHA-256 | Scratch build 2 SHA-256 | Result |
|---|---|---|---|
| `CoreTendApp` | `c015259275ba3f47973023a0352b2fa5a46e233635e961201462cc4207a365c7` | `c015259275ba3f47973023a0352b2fa5a46e233635e961201462cc4207a365c7` | Byte-identical |
| `CoreTendCLI` | `4b41dffdfb5e36c0d1c86bc3235937da905683e654b380afbfebfac153e9d8ca` | `4b41dffdfb5e36c0d1c86bc3235937da905683e654b380afbfebfac153e9d8ca` | Byte-identical |

Using distinct physical scratch paths can embed those paths in Mach-O OSO debug-map records. The observed CI mismatch was `LC_UUID` randomization (first differing byte 3449, UUID field in Mach-O load commands), not source or linker inputs. Local arm64/macOS 27/Xcode 27.0 passes after disabling UUID and pinning minimum deployment target. Corrected GitHub run is pending; NFR-13 stays PARTIEL until it passes. No identity across checkout roots, hosts, or toolchains claimed; supported-host compatibility remains NFR-08.
