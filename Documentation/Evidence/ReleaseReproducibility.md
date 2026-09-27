# Reproducible Release build evidence

**Date:** 2026-09-27
**Host:** arm64, macOS 27.0, Xcode 27.0 SDK (local); GitHub Actions `macos-26-arm64` runner for pending CI rerun
**Source:** app sources from `db5d52f`; local tree includes CI reproducibility-smoke changes after `de5ef65`. Product-source bytes were unchanged by the smoke harness edit.

`python3 Scripts/test_clean_release_builds.py` built `CoreTendApp` and `CoreTendCLI` twice from empty SwiftPM scratch directories under one unique temporary root inside `.build`. Each product reused the same physical scratch path for its second build after safely removing and recreating only that owned scratch directory. The script pins `MACOSX_DEPLOYMENT_TARGET=14.0`, matching the declared minimum and avoiding host OS defaults changing Mach-O load commands. All four Release builds completed without compiler warnings; the unique root was removed after the run. The gate fails if either pair of output hashes differs. Unit fixtures prove reset preserves neighboring files and rejects symlink/out-of-root targets.

| Product | Scratch build 1 SHA-256 | Scratch build 2 SHA-256 | Result |
|---|---|---|---|
| `CoreTendApp` | `9709b88ad58bc8cfdee7a35b199c3718284eb7d7c21f22f87ada655289d28adf` | `9709b88ad58bc8cfdee7a35b199c3718284eb7d7c21f22f87ada655289d28adf` | Byte-identical |
| `CoreTendCLI` | `3c58c269ece42ecba6219558093a20f0f5b496d9297a6634b59c7862e2861118` | `3c58c269ece42ecba6219558093a20f0f5b496d9297a6634b59c7862e2861118` | Byte-identical |

Using distinct physical scratch paths embeds those paths in Mach-O OSO debug-map records and changes the code signature. An earlier CI run on `macos-26-arm64` still differed with same-path resets; local macOS 27 builds are stable after pinning deployment target, but corrected CI run is pending. NFR-13 remains `PARTIEL` until CI confirms. No identity across checkout roots, hosts, or toolchains is claimed. Supported-host compatibility remains tracked by NFR-08.
