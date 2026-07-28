# Building CoreTend from source

Building it yourself is the strongest check available on this project: it does
not ask you to trust a checksum, an attestation, or the person publishing the
release. Every command below was run end to end in a fresh clone before being
written down, and the outputs quoted are the real ones.

## Requirements

| | Verified with |
|---|---|
| macOS | 26.5.1 (the project targets macOS 14.0 and later) |
| Swift | 6.3.2 (`swift-tools-version: 6.0`, so 6.0+ is required) |
| Toolchain | Command Line Tools are enough — **Xcode.app is not required** |
| External dependencies | none for the app itself |

Check what you have:

```sh
sw_vers -productVersion
swift --version
```

If `swift` is missing, install the Command Line Tools with
`xcode-select --install`.

The only SwiftPM dependency is `swift-testing` (plus its transitive
`swift-syntax`), both Apple first-party and both **test-only** — neither is
linked into the shipped application. They are pinned in `Package.resolved`, so
a clone builds the same versions this project was tested against. See
`Documentation/DEPENDENCIES.md`.

## Get the source

```sh
git clone https://github.com/ahmetbsbnr/coretend.git
cd coretend
```

To build a specific published release rather than the tip of `main`, check out
its tag and confirm you are where you think you are:

```sh
git checkout v0.9.1-rc.1
git rev-parse HEAD          # compare with sourceCommit in the release manifest
```

The `sourceCommit` field in a release's `latest.json` names the exact commit
that produced its artifacts, so this comparison is meaningful.

## Build and test

```sh
swift build                 # debug
swift test                  # full suite
swift build -c release      # release, expected to emit zero warnings
```

Observed in a clean clone on the configuration above:

```
Build complete! (52.77s)
✔ Test run with 296 tests passed after 5.919 seconds.
Build complete! (60.93s)
```

The release build is expected to produce **no warnings at all**; CI fails the
release if any appear. The test suite includes load tests (10 000+ files, deep
and wide directory trees) and runs entirely against temporary directories — no
test reads or writes your real CoreTend data, and
`Scripts/check-test-isolation.sh` enforces that.

## Where the binary lands

```sh
swift build -c release --show-bin-path
# /path/to/coretend/.build/arm64-apple-macosx/release
```

That directory contains the `CoreTend` executable (~6.5 MB). It is a bare
executable, not an application bundle: run it directly for a quick check, but
use the bundle below for normal use, since resources and the Info.plist live
there.

## Build the application bundle

```sh
bash Scripts/package-local.sh
# Built: build/CoreTend.app
```

`build/CoreTend.app` is a complete, working bundle. It is **ad-hoc signed**
(`codesign --sign -`): that satisfies macOS's requirement that arm64 binaries
carry *a* signature, and asserts no developer identity whatsoever. It is not,
and is never presented as, Apple Developer ID signing.

Copy it to `/Applications` yourself, or run it in place.

## Build a DMG (optional)

```sh
bash Scripts/package-dmg.sh 0.0.0-local
# Built: Release/CoreTend-0.0.0-local-arm64-unsigned.dmg
```

The script may report:

```
package-dmg.sh: BLOCKED_ENVIRONMENT — the Finder refused the layout pass
  (most likely automation permission). The DMG is still functional.
```

That is expected when the Finder cannot be automated (no GUI session, or
automation permission not granted). Only the saved icon *positions* are
skipped; the DMG mounts and drag-and-drop works either way.

## ClamAV (optional)

Malware scanning is optional and is **not** built into CoreTend. The app shells
out to a `clamscan` binary that you install and own:

```sh
brew install clamav
freshclam                   # download the signature database, once
```

CoreTend looks for `clamscan` at `/opt/homebrew/bin`, `/usr/local/bin` and
`/opt/local/bin` — fixed absolute paths, so `PATH` cannot be used to redirect
it at a different binary. It is invoked as a subprocess with an argument array,
never through a shell. If ClamAV is absent, the Protection module says so
plainly instead of pretending to scan. See `Documentation/CLAMAV.md`.

## What a local build does not give you

- **It is not notarized, and not Developer ID signed.** A build you compiled
  yourself will still be treated as unidentified by Gatekeeper. That is correct
  behaviour, not a defect.
- **It is not byte-identical to the published artifacts.** The ZIP and DMG
  embed timestamps, so their checksums differ between builds. Compare the
  *source commit*, not the artifact hash, if you want to know that a release
  matches this source.
- **Do not disable Gatekeeper** to run your own build. Control-click the app
  and choose **Open**, or use **System Settings → Privacy & Security → Open
  Anyway**. Both keep every system protection in place. See
  `Documentation/INSTALL_UNSIGNED.md`.
