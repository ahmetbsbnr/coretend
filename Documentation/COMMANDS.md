<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Commands

Every command this project actually uses. Run from the repository root.

## Build

```sh
swift build                     # Debug
swift build -c release          # Release
bash Scripts/package-local.sh   # assemble build/CoreTend.app (ad-hoc signed)
```

There is no Xcode on this machine — Command Line Tools only, so `xcodebuild` is
unavailable. Do not write build steps that need it.

After changing a public struct's stored layout, `rm -rf .build` once:
incremental cross-module reads have corrupted historically.

## Test

```sh
bash Scripts/test.sh            # the ONLY supported runner
```

Not `swift test`. XCTest ships with Xcode; Swift Testing needs explicit
`-F`/`-rpath` flags, which the script supplies.

Expected: **342 tests in 58 suites, 0 failures.**

## Site

```sh
python3 Website/build.py --output Website/dist   # pages, robots.txt, sitemap.xml, latest.json, SHA256SUMS
bash Scripts/check-website.sh
```

`Website/index.html` is the visual source of truth; `build.py` produces the
gitignored `Website/dist/` that Vercel deploys, deriving release facts from
`Configuration/published-release.json`. `Website/vercel.json` (redirects,
rewrites, headers) is hand-maintained, not generated. Never hand-edit anything
under `Website/dist/`.

## Release artifacts

```sh
bash Scripts/build-release.sh   # ZIP + DMG + Release/latest.json + SHA256SUMS
```

Refuses a dirty tree, because `sourceCommit` would name a commit whose tree is
not what was packaged. `ALLOW_DIRTY_BUILD=1` overrides for local iteration and
stamps `treeState:"dirty"`, marking the build non-releasable.

`Release/latest.json` is **generated, never committed**. A tracked file cannot
contain the SHA of the commit that adds it.

## Gates

```sh
bash Scripts/final-launch-gate.sh                        # the one that matters
bash Scripts/final-launch-gate.sh --expect-version 0.9.0 --expect-head <sha>

bash Scripts/check-publish-readiness.sh
bash Scripts/check-placeholders.sh
bash Scripts/check-private-data.sh
bash Scripts/check-licenses.sh
bash Scripts/check-version-consistency.sh
bash Scripts/check-legacy-brand-references.sh
bash Scripts/check-brand-assets.sh
bash Scripts/check-feature-inventory.sh
bash Scripts/check-workspace-layout.sh
bash Scripts/check-website.sh
python3 Scripts/check-markdown-links.py
bash Scripts/doctor.sh
bash Scripts/repository-doctor.sh
```

**Capture a gate's exit code directly; never read it through a pipe.**
`bash gate.sh | tail -1` reports `tail`'s status, so a failing gate looks like a
passing one. This has already caused one bad commit in this project.

For the same reason, avoid `producer | grep -q` inside gates: `grep -q` exits at
the first match and SIGPIPEs the producer, which under `set -o pipefail` reports
the pipeline as failed despite the match — nondeterministically. Capture output
into a variable and match with `case`.

## Artifact verification

```sh
unzip -t  Release/CoreTend-0.9.0-arm64-unsigned.zip
hdiutil verify Release/CoreTend-0.9.0-arm64-unsigned.dmg
( cd Release && shasum -a 256 -c SHA256SUMS )
shasum -a 256 <artifact>

codesign -dv                                  build/CoreTend.app   # expect Signature=adhoc
codesign --verify --deep --strict --verbose=2 build/CoreTend.app
spctl --assess --type execute --verbose=4     build/CoreTend.app   # expect: rejected
security find-identity -v -p codesigning                            # expect: 0 valid identities
```

`spctl` returning **rejected** is the expected result for an unsigned build.
Record it as a rejection; never present it as a signing pass.

## Publication — not performed

See `RELEASE_STATE.md` for the exact sequences, kept in one place so they are
not retyped from memory.

## Forbidden

```sh
git reset --hard
git clean -fd
git checkout --orphan
git push --force
git push --force-with-lease
```

Never change branch with a dirty working tree. Never export via an orphan
checkout in the active repository — that method previously destroyed the
working tree; `Scripts/build-public-branch.sh` builds its commit with
`commit-tree` against a throwaway index instead.
# CoreTend commands

## Read-only CLI

Swift Package Manager builds a small inspection binary alongside the app:

```sh
swift run coretend-cli --list-rules
swift run coretend-cli --paths
```

The CLI lists cleanup rules, risk levels, and user-scoped roots. It never
deletes, moves, edits, or uploads files. Destructive actions stay inside the
reviewed SwiftUI safety flow, with per-item confirmation and Trash rollback.

Use `swift run coretend-cli --help` for complete usage.
