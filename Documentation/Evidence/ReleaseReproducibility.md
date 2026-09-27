# Reproducible Release build evidence

**Date:** 2026-09-27
**Host:** arm64, macOS 27.0, Xcode 27.0 SDK
**Source:** `feat/reconstruction-open-musts` local working tree after FR-16 and optional menu-bar implementation, based on `0f29b90`; local changes are not represented by a remote commit.

`python3 Scripts/test_clean_release_builds.py` built `CoreTendApp` and `CoreTendCLI` twice from two independent, initially empty temporary roots and SwiftPM scratch directories. A symlink at the stable workspace path `.build/qualify-clean-release-scratch` pointed to each temporary scratch directory in turn. This keeps embedded OSO debug-map paths stable while the physical scratch directories remain separate. All four Release builds completed without compiler warnings; physical outputs were under the temporary roots, and the workspace symlink was removed after each build. The gate fails if either pair of output hashes differs.

| Product | Scratch build 1 SHA-256 | Scratch build 2 SHA-256 | Result |
|---|---|---|---|
| `CoreTendApp` | `1ec7693ebaf94e07efa1bf8fd503290c99940a698fc261267dfd231aaf0c773a` | `1ec7693ebaf94e07efa1bf8fd503290c99940a698fc261267dfd231aaf0c773a` | Byte-identical |
| `CoreTendCLI` | `0062ec3abc2d3dbbbdbe2eeb8537d14bdea4f07614993f90bf7f7c5bbd59d02a` | `0062ec3abc2d3dbbbdbe2eeb8537d14bdea4f07614993f90bf7f7c5bbd59d02a` | Byte-identical |

Using distinct logical scratch paths embeds those paths in Mach-O OSO debug-map records and changes the code signature. Using one stable workspace path over independent empty scratch directories yields identical artifacts on the observed source, host, toolchain, and checkout root. NFR-13 is verified for these inputs; this does not claim identity across different checkout roots, hosts, or toolchains. Supported-host compatibility remains tracked by NFR-08.
