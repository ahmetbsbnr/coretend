# Release Provenance

How CoreTend records what was built, from which commit, and by which run — and
why the previous design could not be made honest.

## The defect this replaces

`Release/latest.json` used to be **tracked by git** and carried a `sourceCommit`
field. `Scripts/build-release.sh` stamped that field from `git rev-parse HEAD`,
and `Scripts/test-release-manifest.sh` asserted `sourceCommit == HEAD`.

That is unsatisfiable. Committing the manifest creates a new commit, and the
`sourceCommit` written a moment earlier cannot name a commit that did not exist
yet. So:

- the gate was green only on a tree where `Release/` was still uncommitted;
- the moment the manifest was committed, it read one commit stale, forever;
- the gate "fixed" this by **rebuilding the artifacts as a side effect** of being
  run, which changed their checksums on every invocation because ZIP/DMG output
  is not byte-reproducible.

It also failed in the other direction. The 0.8.1 artifacts were built while the
release changes were still uncommitted, so `git rev-parse HEAD` truthfully
returned the *previous* commit (`3b5dc73`) while the packaged bundle already
carried `Info.plist` version `0.8.1`. The manifest named a commit whose tree could
not have produced the artifacts it described. Recorded as `DIST-003` and
`RESYNC-003` in `NON_COMPLIANCE_REGISTER.md`.

## The design now

| File | Tracked? | Contents | Written by |
|---|---|---|---|
| `Release/latest.template.json` | **yes** | Only human decisions: channel, prerelease, minimum macOS, signed/notarized, known limitations, URLs, licence, name patterns | a person |
| `dist/latest.json` | no | The template plus every computed fact | `Scripts/build-release.sh` |
| `dist/SHA256SUMS` | no | SHA-256 of both artifacts and the manifest | `Scripts/build-release.sh` |
| `Release/latest.json`, `Release/SHA256SUMS` | no | Copies of the above, at the historical paths, for existing tooling | `Scripts/build-release.sh` |

Because the manifest is **generated output and never committed**, `sourceCommit`
names the exact commit the artifacts were built from and that statement stays
true permanently. There is nothing to commit afterwards, so there is no later
commit to invalidate it.

### Computed fields

| Field | Meaning |
|---|---|
| `sourceCommit` | `git rev-parse HEAD` at build time — the commit whose tree was packaged |
| `releaseTag` | The exact tag at that commit (`git describe --exact-match --tags`), or `null` |
| `treeState` | `clean` or `dirty` |
| `releasable` | `false` whenever `treeState` is `dirty`, regardless of tag |
| `buildDate_UTC` | ISO-8601 UTC timestamp of the build |
| `buildInvocationID` | A UUID per invocation, so two builds of the same commit are distinguishable |
| `zipSHA256`, `zipSize`, `dmgSHA256`, `dmgSize` | Measured from the artifacts just built |

### Clean-tree rule

`build-release.sh` **refuses to run on a dirty tree**, because `sourceCommit`
would otherwise name a commit whose tree is not what was packaged — exactly the
0.8.1 defect.

`ALLOW_DIRTY_BUILD=1` overrides it for local iteration and stamps
`treeState: "dirty"` and `releasable: false`, so such a build cannot be mistaken
for a releasable one. `Scripts/check-publish-readiness.sh` rejects any manifest
whose `treeState` is not `clean`.

### Template protection

The template declares `_doNotAddHere`, listing every computed field. The build
**fails** if the template contains any of them, so a hand-edited checksum can
never silently win over a measured one. `test-release-manifest.sh` verifies both
that the declaration exists and that it is honoured.

## What each gate now checks

`Scripts/test-release-manifest.sh`:

- `Release/latest.json` and `Release/SHA256SUMS` are **not** tracked
- `Release/latest.template.json` **is** tracked
- the template carries no computed field
- `sourceCommit` is a commit that really exists in the repository — **not** that
  it equals current `HEAD`, since later commits do not change what was built
- `buildInvocationID` and `buildDate_UTC` are present
- `treeState` is valid, and `releasable` is consistent with it
- if `releaseTag` is set, it exists and points at `sourceCommit`
- `build-release.sh` still gates on a clean tree — checked by reading the script,
  so this gate never mutates or rebuilds anything

`Scripts/check-publish-readiness.sh` additionally requires, for a **public
release**:

- `treeState == clean`
- a `releaseTag` that exists and points at `sourceCommit`

That is the property the old design could not express: **the publication gate can
now be green on an exact tag, with no generated file needing to be committed
after that tag.**

## Releasing

```sh
git tag -a v0.9.0 -m "0.9.0 — Public Beta"
git status --short                 # must be empty
bash Scripts/build-release.sh 0.9.0
bash Scripts/test-release-manifest.sh
bash Scripts/check-publish-readiness.sh
```

The tag is created **before** the build, so `releaseTag` is populated and points
at `sourceCommit`. Nothing is committed afterwards.

## Consequences for the audit package

The audit package includes `dist/latest.json` and `dist/SHA256SUMS` as build
evidence rather than as repository files, and records `sourceCommit`,
`releaseTag` and `buildInvocationID` in `AUDIT_PACKAGE_MANIFEST.json`. The
package's own `finalRepositoryHead` may legitimately differ from `sourceCommit`
if documentation was committed after the build; that is now an ordinary fact
rather than a contradiction, because no tracked file claims otherwise.
