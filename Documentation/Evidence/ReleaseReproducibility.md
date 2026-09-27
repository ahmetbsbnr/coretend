# Reproducible Release build evidence

**Date:** 2026-09-27
**Host:** arm64, macOS 27.0, Xcode 27.0 SDK (local); GitHub Actions `macos-26-arm64` runner previously compared
**Source:** reconstruction tree including deterministic Release linker settings in `Package.swift`.

`python3 Scripts/test_clean_release_builds.py` builds each product twice from empty SwiftPM scratch directories under one unique temporary root inside `.build`. Each product reuses same physical scratch path for second build after safely removing and recreating only owned scratch directory. It pins `MACOSX_DEPLOYMENT_TARGET=14.0`; Release linker settings in `Package.swift` pass Apple ld's `-reproducible`. GitHub macOS 26 diagnostics showed random `LC_UUID`, then `N_OSO` records whose `n_value` reflected each object file's mtime (40-second difference). `-reproducible` uses stable link algorithms/input handling while retaining deterministic `LC_UUID` required by dyld. Standard SwiftPM Release builds and app packaging share this policy. Four local cold builds completed without warnings. Unique root removed after run. Gate requires exact SHA-256 equality; unit fixtures prove reset scope and symlink/out-of-root rejection.

| Product | Scratch build 1 SHA-256 | Scratch build 2 SHA-256 | Result |
|---|---|---|---|
| `CoreTendApp` | `3d63e32c93363def121038419b10bafb9ffaac0ce30f81c0e379ec5742390cd3` | `3d63e32c93363def121038419b10bafb9ffaac0ce30f81c0e379ec5742390cd3` | Byte-identical |
| `CoreTendCLI` | `0d6630bf1600cc87f07bf1e2020980bf7d2b85382433860dd85c7eb53466d37f` | `0d6630bf1600cc87f07bf1e2020980bf7d2b85382433860dd85c7eb53466d37f` | Byte-identical |

Using distinct physical scratch paths can embed those paths in Mach-O OSO debug-map records. Exact GitHub diagnosis separated random `LC_UUID` at byte 3449 and object-file mtimes in `N_OSO` symbol records. Package-level `-reproducible` addresses both while retaining `LC_UUID`; local package runtime launches in isolated HOME/store fixture. GitHub rerun after this setting is pending; NFR-13 stays PARTIEL until it passes. No identity across checkout roots, hosts, or toolchains claimed; supported-host compatibility remains NFR-08.
