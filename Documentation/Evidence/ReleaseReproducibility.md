# Reproducible Release build evidence

**Date:** 2026-09-27
**Host:** arm64, macOS 27.0, Xcode 27.0 SDK
**Source:** app sources from `db5d52f`; local tree includes CI reproducibility-smoke changes after `de5ef65`. Product-source bytes were unchanged by the smoke harness edit.

`python3 Scripts/test_clean_release_builds.py` built `CoreTendApp` and `CoreTendCLI` twice from empty SwiftPM scratch directories under one unique temporary root inside `.build`. Each product reused the same physical scratch path for its second build after the script safely removed and recreated only that owned scratch directory. Keeping the physical path stable avoids toolchain-dependent symlink canonicalization in Mach-O debug maps. All four Release builds completed without compiler warnings; the unique root was removed after the run. The gate fails if either pair of output hashes differs. Unit fixtures prove reset preserves neighboring files and rejects symlink/out-of-root targets.

| Product | Scratch build 1 SHA-256 | Scratch build 2 SHA-256 | Result |
|---|---|---|---|
| `CoreTendApp` | `b3fb6719a2c5e9302cd3b89525806600a204675cc9fa96364534123974c3b8a8` | `b3fb6719a2c5e9302cd3b89525806600a204675cc9fa96364534123974c3b8a8` | Byte-identical |
| `CoreTendCLI` | `f0233f8be8c6e275d4287355705829e15e47c9f241f9637fda2baa624e5a0844` | `f0233f8be8c6e275d4287355705829e15e47c9f241f9637fda2baa624e5a0844` | Byte-identical |

Using distinct physical scratch paths embeds those paths in Mach-O OSO debug-map records and changes the code signature. Reusing one physical path after a cold reset yields identical artifacts on the observed source, host, toolchain, and checkout root. NFR-13 is verified for these inputs; this does not claim identity across different checkout roots, hosts, or toolchains. Supported-host compatibility remains tracked by NFR-08.
