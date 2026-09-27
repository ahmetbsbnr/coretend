# Reproducible Release build evidence

**Date:** 2026-09-27
**Host:** arm64, macOS 27.0, Xcode 27.0 SDK (local); GitHub Actions `macos-26-arm64` runner previously compared
**Source:** reconstruction tree including deterministic Release linker settings in `Package.swift`.

`python3 Scripts/test_clean_release_builds.py` builds each product twice from empty SwiftPM scratch directories under one unique temporary root inside `.build`. Each product reuses same physical scratch path for second build after safely removing and recreating only owned scratch directory. It pins `MACOSX_DEPLOYMENT_TARGET=14.0`; Release linker settings in `Package.swift` pass `-no_uuid` and `-x`. Evidence from GitHub macOS 26 showed random `LC_UUID`, then `N_OSO` records whose `n_value` reflected each object file's mtime (40-second difference). `-no_uuid` removes former; `-x` zeroes local OSO timestamp values. Standard SwiftPM Release builds now use same policy as app packaging. All four local builds completed without warnings. Unique root removed after run. Gate requires exact SHA-256 equality; unit fixtures prove reset scope and symlink/out-of-root rejection.

| Product | Scratch build 1 SHA-256 | Scratch build 2 SHA-256 | Result |
|---|---|---|---|
| `CoreTendApp` | `b1929c5e3911a9d008802c457662b3a1fc3d1e43d202ce292b269845a4e3dac3` | `b1929c5e3911a9d008802c457662b3a1fc3d1e43d202ce292b269845a4e3dac3` | Byte-identical |
| `CoreTendCLI` | `4bc4b076975bade9c6f448e03e029e252f3d2174aaabc7d49c445cf8ec8239b1` | `4bc4b076975bade9c6f448e03e029e252f3d2174aaabc7d49c445cf8ec8239b1` | Byte-identical |

Using distinct physical scratch paths can embed those paths in Mach-O OSO debug-map records. Exact GitHub diagnosis separated random `LC_UUID` at byte 3449 and object-file mtimes in `N_OSO` symbol records. Package-level `-no_uuid -x` addresses both; local `make qualify` passes and the same packaged app launches in isolated HOME/store fixture. GitHub rerun after package-level settings is pending; NFR-13 stays PARTIEL until it passes. No identity across checkout roots, hosts, or toolchains claimed; supported-host compatibility remains NFR-08.
