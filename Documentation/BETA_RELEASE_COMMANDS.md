<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# CoreTend 1.1.0-beta.1 — release command sequence

Run these **only after both hard preconditions are met**:

1. `Documentation/BETA_QA.md` records the maintainer's dated PASS results for
   every release-blocking human check, and its line-20 verdict is
   `V1.1.0-BETA.1 READY TO SIGN: YES` (committed on `release/v1.1.0-beta.1`).
2. The Apple Developer portal has `group.com.ahmetbsbnr.coretend` registered
   and associated with `com.ahmetbsbnr.coretend` **and**
   `com.ahmetbsbnr.coretend.widget`.

No secret appears in this file. `CoreTend-Notary` is a keychain profile name,
not a credential. This document does not run anything — it is the checklist
the signing pass executes.

All commands run from the repository root on `release/v1.1.0-beta.1`.

---

## 0. Position

```
cd ~/Developer/Website/products/coretend/app
git switch release/v1.1.0-beta.1
git status --short --branch          # must be clean
git rev-parse HEAD                   # note this SHA -> <RELEASE_HEAD>
```

## 1. Pre-sign gates (all must pass)

```
Scripts/check-version-consistency.sh
Scripts/build.sh
Scripts/build.sh release
Scripts/test.sh                      # expect 823+/0
Scripts/repository-doctor.sh
Scripts/build-xcode.sh               # -> build/CoreTend.app (universal, ad-hoc)
Scripts/test-release-sync.sh
Scripts/test-release-manifest.sh
Scripts/test-release-provenance.sh
python3 Scripts/test-public-release-gate.py
python3 Scripts/check-design-tokens.py
Scripts/release-preflight.sh         # bundle audit + entitlement config + toolchain
```

`release-preflight.sh` section 2 prints an `EXTERNAL` line for the App Group
portal registration — that is precondition 2 above, confirmed out of band.

## 2. Sign + notarize + staple + DMG (one script)

`Scripts/sign-and-notarize.sh` does the whole chain in the correct order:
loose Mach-O -> `CoreTendFinder.appex` (sandbox only) ->
`CoreTendWidget.appex` (sandbox + App Group) -> host `CoreTend.app`
(hardened runtime + App Group, no sandbox) -> verify each signature ->
ZIP -> `notarytool submit --wait` -> staple app -> build DMG from the stapled
app (no rebuild) -> sign DMG -> `notarytool submit --wait` -> staple DMG ->
`spctl` on app and DMG.

```
export CORETEND_DEVELOPER_ID_APPLICATION="Developer ID Application: Ahmet BASBUNAR (NSCUV5G738)"
Scripts/sign-and-notarize.sh 1.1.0-beta.1 CoreTend-Notary
```

**Require:** both `xcrun notarytool submit ... --wait` calls end with
`status: Accepted`. If either is `Invalid`:

```
xcrun notarytool log <submission-id> --keychain-profile CoreTend-Notary
```

Diagnose, fix only the release defect, rebuild from clean source
(`Scripts/build-xcode.sh`), re-run this script. Do not publish a
not-yet-Accepted artifact.

**Produces:**
- `Release/CoreTend-1.1.0-beta.1-arm64.zip` (signed, for notarization input)
- `Release/CoreTend-1.1.0-beta.1-arm64.dmg` (signed + notarized + stapled — the product)

## 3. Verify the signed artifacts

```
codesign --verify --deep --strict --verbose=2 build/CoreTend.app
codesign --display --entitlements :- build/CoreTend.app | grep application-groups        # host: group.com.ahmetbsbnr.coretend
codesign --display --entitlements :- build/CoreTend.app/Contents/PlugIns/CoreTendWidget.appex | grep -E 'app-sandbox|application-groups'
codesign --display --entitlements :- build/CoreTend.app/Contents/PlugIns/CoreTendFinder.appex   # exactly app-sandbox=true, no App Group
xcrun stapler validate build/CoreTend.app
xcrun stapler validate Release/CoreTend-1.1.0-beta.1-arm64.dmg
spctl --assess --type open --context context:primary-signature --verbose Release/CoreTend-1.1.0-beta.1-arm64.dmg   # -> accepted, source=Notarized Developer ID
```

## 4. Generate beta machine metadata from the real artifacts

```
CORETEND_RELEASE_SIGNED=1 Scripts/build-release.sh 1.1.0-beta.1
```

Reuses the signed/notarized bytes (no rebuild), computes checksums, and writes
`dist/latest.json` + `dist/SHA256SUMS` (both gitignored). Confirm
`dist/latest.json` shows:

```
version    : 1.1.0-beta.1
channel    : beta
prerelease : true
signed     : true
notarized  : true
releaseTag : v1.1.0-beta.1
treeState  : clean
sourceCommit : <RELEASE_HEAD>
```

Then copy to the tracked mirrors the release scripts expect:

```
cp dist/latest.json dist/SHA256SUMS Release/
```

## 5. Final launch gate (signed posture)

```
bash Scripts/final-launch-gate.sh --expect-version 1.1.0-beta.1 --expect-head <RELEASE_HEAD>
```

**Require:** `final-launch-gate.sh: READY` — 0 FAIL. The only permitted
`HUMAN_ACTION_REQUIRED` lines are "tag does not exist yet" and "no GitHub
release yet" (publication is a separate deliberate act). Any other FAIL: fix
it or stop — do not explain it away at this stage.

## 6. Post-sign smoke test (the signed/notarized DMG, not a source build)

```
hdiutil attach Release/CoreTend-1.1.0-beta.1-arm64.dmg
cp -R "/Volumes/CoreTend/CoreTend.app" /Applications/
hdiutil detach "/Volumes/CoreTend"
xattr -p com.apple.quarantine /Applications/CoreTend.app   # quarantine present = realistic
open /Applications/CoreTend.app
```

Confirm on the packaged app: Gatekeeper opens it with no "unidentified
developer" prompt; Dashboard renders; a short Smart Scan runs; Space Lens
opens a folder; Recovery Plan reaches the review boundary; the Finder
extension appears in System Settings; the widget is offered in the gallery;
Shortcuts lists the actions; FR/EN switch works; quit and relaunch is clean.
Record the result in `Documentation/BETA_QA.md` under a
"Post-sign smoke test — <date>" heading.

## 7. STOP

This sequence ends with a ready-to-publish artifact. **Do not** in this pass:
`git push` · `git tag` · `gh release create` · upload assets · update the
website beta manifest · edit `Configuration/published-release.json`. Those
happen only under a separate, explicit publication instruction.

### Publication (separate authorization required — reference only)

```
git tag -a v1.1.0-beta.1 -m "CoreTend 1.1.0-beta.1"
# (optional, if the maintainer wants Minisign for the beta:)
#   minisign -Sm Release/SHA256SUMS
git push origin release/v1.1.0-beta.1 v1.1.0-beta.1
gh release create v1.1.0-beta.1 --prerelease \
  --title "CoreTend 1.1.0-beta.1" \
  --notes-file Release/Notes/1.1.0-beta.1.en.md \
  Release/CoreTend-1.1.0-beta.1-arm64.dmg \
  Release/CoreTend-1.1.0-beta.1-arm64.zip \
  Release/latest.json Release/SHA256SUMS
Scripts/sync-published-release.sh      # then commit Configuration/published-release.json
# then: website beta-channel entry with the real DMG URL (separate branch)
```
