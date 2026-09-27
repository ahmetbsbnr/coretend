# Reproducible Release build evidence

**Date:** 2026-09-27
**Host:** arm64, macOS 27.0, Xcode 27.0 SDK
**Source:** `feat/reconstruction-open-musts` local working tree after FR-16, optional menu-bar access and FR-22 live menu measurements, based on `0f29b90`; local changes are not represented by a remote commit.

`python3 Scripts/test_clean_release_builds.py` built `CoreTendApp` and `CoreTendCLI` twice from two independent, initially empty temporary roots and SwiftPM scratch directories. A symlink at the stable workspace path `.build/qualify-clean-release-scratch` pointed to each temporary scratch directory in turn. This keeps embedded OSO debug-map paths stable while the physical scratch directories remain separate. All four Release builds completed without compiler warnings; physical outputs were under the temporary roots, and the workspace symlink was removed after each build. The gate fails if either pair of output hashes differs.

| Product | Scratch build 1 SHA-256 | Scratch build 2 SHA-256 | Result |
|---|---|---|---|
| `CoreTendApp` | `c96e5a32739ef31b1b580419724942eb62fa416dfc5bbe9cfa26d19be59d4c22` | `c96e5a32739ef31b1b580419724942eb62fa416dfc5bbe9cfa26d19be59d4c22` | Byte-identical |
| `CoreTendCLI` | `9800f0d19f839ef82a57ebee7616966672195871b7510f7a6a11193b228af2ba` | `9800f0d19f839ef82a57ebee7616966672195871b7510f7a6a11193b228af2ba` | Byte-identical |

Using distinct logical scratch paths embeds those paths in Mach-O OSO debug-map records and changes the code signature. Using one stable workspace path over independent empty scratch directories yields identical artifacts on the observed source, host, toolchain, and checkout root. NFR-13 is verified for these inputs; this does not claim identity across different checkout roots, hosts, or toolchains. Supported-host compatibility remains tracked by NFR-08.
