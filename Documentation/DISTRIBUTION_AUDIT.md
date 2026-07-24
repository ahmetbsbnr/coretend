# Distribution Audit — Session 3

Date: 2026-07-20. Branch `feat/public-distribution`, HEAD `6ea6c48` (session 2 close),
build artifacts in `Release/` produced by `Scripts/build-release.sh` at
`sourceCommit 99bbe12`.

## Method
Real commands run this session, evidence below. Extraction/mount/launch/quit
performed **outside the repo**, in the session scratchpad
(`/private/tmp/.../scratchpad/disttest`), then cleaned up.

## 1. Checksum/size manifest sync (regression check for the session-2 fix, commit `88bbb9a`)

```
$ shasum -a 256 Release/CoreTend-0.7.0-arm64-unsigned.zip Release/CoreTend-0.7.0-arm64-unsigned.dmg
0515ea184425ab1829f0da2fd31c4661b97128da54c710e425c2b7b5f2fd9999  .zip
36aae052183df9e5933fa50264e3fc014cea5359b37636e656acdc7447a4ead8  .dmg
```
`Release/latest.json` `zipSHA256`/`dmgSHA256`/`zipSize`/`dmgSize` match exactly
(`zipSize` 2430463, `dmgSize` 2950713 — matches `ls -la`).
**VERIFIED_COMPLETE** — the session-2 auto-sync fix holds on the artifacts as they
sit in the tree today.

## 2. Architecture

```
$ file CoreTend
Mach-O 64-bit executable arm64
$ lipo -info CoreTend
Non-fat file: ... is architecture: arm64
```
Single-arch arm64 only, not a universal/fat binary. `latest.json` correctly
declares `"architecture": "arm64"` and does not claim Intel support.
**VERIFIED_COMPLETE** for the arm64 claim; **NOT_APPLICABLE** for x86_64 (never
claimed).

## 3. ZIP extract / launch / quit (outside repo)

Extracted `CoreTend-0.7.0-arm64-unsigned.zip` in a scratch temp dir,
`open`'d the `.app`, confirmed process running via `pgrep`, sent AppleScript
`quit`, confirmed process gone. All steps succeeded first try, no crash,
no hang. **VERIFIED_COMPLETE**.

## 4. DMG mount / detach (outside repo)

`hdiutil attach -nobrowse -readonly` on the dmg mounted cleanly to
`/Volumes/CoreTend`, CRC32 verification passed during mount,
`hdiutil detach` cleaned up without error. Did not additionally launch the
`.app` from the mounted volume (already covered via the zip path, which is
the same binary/bundle) — **VERIFIED_COMPLETE** for mount/detach mechanics,
**IMPLEMENTED_UNVERIFIED** for "launch specifically off the mounted DMG
volume" (untested this session, low risk since it's the identical `.app`).

## 5. License files shipped in artifacts

`Scripts/package-zip.sh:19` and `Scripts/package-dmg.sh:20` both
`cp LICENSE NOTICE THIRD_PARTY_NOTICES.md "$STAGE/"` before archiving.
Confirmed via `unzip -l`: `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md` present
at the zip root alongside the `.app` (not inside the app bundle itself —
that is normal/expected placement for a zip distribution, matches how most
macOS zip releases ship license text). **VERIFIED_COMPLETE**.

Note: the `.app` bundle's own `Contents/Resources` does **not** contain a
copy of the license text (only icons and the SwiftPM resource bundle). This
is fine for a zip/dmg distribution (license sits beside the app) but would
be a gap if the `.app` were ever distributed standalone (e.g. drag-installed
then the zip/dmg discarded) — the license no longer travels with the running
app once copied to `/Applications`. Not a blocker, but worth a mention in
`TECHNICAL_DEBT.md`.

## 6. What's distributable now vs. what blocks a first real publish

**Distributable today (mechanically):**
- zip and dmg both build, checksum-match their manifest, extract/mount
  cleanly, launch and quit cleanly, arm64 confirmed, licenses ship.

**Blocks an actual first public release** (carried over from
`HUMAN_BLOCKERS.md`, re-confirmed this session, not new):
- Unsigned, not notarized — Gatekeeper blocks first launch for anyone who
  isn't the developer; `latest.json.signed=false`, `notarized=false` are
  honest about this.
- No GitHub release/repo exists yet — `latest.json` has no `downloadURL`;
  `repositoryURL` in the manifest (`github.com/ahmetbsbnr/coretend`)
  is aspirational, not live (`git remote -v` is empty per session-1/2 audit).
- Only ever built/tested on one physical Mac, one macOS version (26.5.1
  arm64) — no multi-OS, no Intel, no clean-machine test.
- No x86_64 build exists — Apple Silicon only, undocumented whether that's
  a permanent decision or a gap.

None of the above changed this session; this audit re-verifies the
mechanical packaging is sound so that when signing/notarization/hosting are
resolved (human-gated, out of scope here), the artifact pipeline itself is
not the blocker.
