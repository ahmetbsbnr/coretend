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

**If your clone lives inside an iCloud Drive-synced folder** (anywhere under
`~/Documents` or `~/Desktop` with iCloud Drive's "Desktop & Documents" sync on),
point `.build` outside it. SwiftPM's build cache is thousands of small files;
iCloud actively syncing that same folder while the compiler writes to it
causes severe I/O contention — builds stall, `git status` stalls, even plain
file reads can time out, all with no error that points at the real cause:

```sh
swift build --scratch-path /tmp/coretend-dev-build
swift test  --scratch-path /tmp/coretend-dev-build
```

`Scripts/package-local.sh` already does this (`SCRATCH=/tmp/coretend-release-build`)
for exactly this reason. A plain `swift build`/`swift test` with no
`--scratch-path` does not, and will hit the same wall on an iCloud-synced clone.

Observed in a clean clone on the configuration above:

```
Build complete! (52.77s)
✔ Test run with 276 tests passed after 5.919 seconds.
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

The window layout (background, icon positions) is generated deterministically
by `dmgbuild` — no Finder, no AppleScript, no automation permission, so this
works the same in a plain terminal and in CI. `Scripts/test-dmg-layout.sh`
verifies the result; a DMG whose layout didn't come through fails the build
rather than shipping unstyled.

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
