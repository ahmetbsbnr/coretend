<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Release State

## Current release — v1.0.0, stable, published 2026-09-03

`v1.0.0` points to source commit `0ecddea`. GitHub release is public, not a
draft, and not a prerelease. Both arm64 artifacts are Developer ID signed,
Apple-notarized, and stapled. `SHA256SUMS` and its Minisign signature verify
against `Configuration/minisign.pub`.

| Artifact | Size (bytes) | SHA-256 |
|---|---:|---|
| `CoreTend-1.0.0-arm64.dmg` | 4,938,110 | `0969ea2565b98fc950a589855ebafa2b811474fd1383092c3567e192f404534d` |
| `CoreTend-1.0.0-arm64.zip` | 3,013,484 | `c11c1cbac95a48c9fa9b3cb54596313f52af9ad89dd930e51bcde6cbd152244b` |

Published assets: DMG, ZIP, `latest.json`, `SHA256SUMS`,
`SHA256SUMS.minisig`, and `minisign.pub`. `Configuration/published-release.json`,
site download route, portfolio, and in-app updater agree on 1.0.0.

Current automated result: 342 Swift tests pass, 0 fail. On 2026-09-04,
maintainer reported PASS for interactive accessibility and second-Mac/
different-supported-macOS compatibility. Maintainer also accepted 44 native
captures covering 11 modules × EN/FR × light/dark.
No SLSA build attestation exists for 1.0.0 because final Apple signing happened
outside Actions; creating one after downloading the release would falsely name
the downloader workflow as builder. Developer ID/notarization, SHA-256, and
Minisign remain the truthful verification chain for 1.0.0. Next release must
integrate provenance with final signed bytes. See root `TODO.md` and
`Documentation/PROJECT_STATE.json`.

## Historical release — v0.9.1-rc.6, published 2026-08-31

`v0.9.1-rc.6` (`sourceCommit 568bdbf`, published from the merged
`feat/porcelaine-and-signing` branch) is the **first Developer ID signed and
Apple-notarized** CoreTend release.

| Artifact | Size (bytes) | SHA-256 |
|---|---|---|
| `CoreTend-0.9.1-rc.6-arm64.dmg` | 4,790,985 | `770bd0340cf887d90bb2a0a6b6510a420a8e268de550a7ff73c88dcb7138df32` |
| `CoreTend-0.9.1-rc.6-arm64.zip` | 2,933,940 | `c0ea57e375ef5ef00d38d04687a647a1e9e11cf21302ad836c1aadd415a0112e` |

Verified from a clean re-download of the published DMG:
`shasum -a 256 -c SHA256SUMS` → OK; `minisign -Vm SHA256SUMS -P <minisign.pub>`
→ verifies; `xcrun stapler validate` → worked; `spctl --assess --type open`
→ **accepted, `source=Notarized Developer ID`,
`origin=Developer ID Application: Ahmet BASBUNAR (NSCUV5G738)`**. The app
inside the DMG: `codesign` chain Developer ID Application → Developer ID CA →
Apple Root CA, `TeamIdentifier=NSCUV5G738`, staple validates offline.

`Configuration/published-release.json` and the `/download` redirect
(`vercel.json`) point at this release. The portfolio case study synced via
`repository_dispatch`.

**Published manually** (local signed build → `gh release create`, CI workflow
disabled during the tag push so it could not rebuild an unsigned artifact over
it). Consequence: **no `actions/attest-build-provenance` attestation** exists
for rc.6 — `gh attestation verify` returns 404. Minisign + SHA-256 +
notarization are the provenance guarantees for this release.

## Historical v1.0.0 preparation record

The branch is **not merged, not pushed**; the annotated tag `v1.0.0` exists
**only in this working copy** (recreated at each re-sign, deleted freely).

**Release prep** (`2b13ee4` → `dfc0f37`): crash-matrix 25/27/38 closed,
`SmartCareView` retired, version → 1.0.0 / build 1000 / channel `stable`,
`Release/Notes/1.0.0.{en,fr}.md` added, `final-launch-gate.sh` reworked around
a signed/unsigned release posture (bundle-nested licence texts, stapled-ticket
authority check).

**Pre-release cleanup sweep** (`a50774c` → `6ae2343`, `periphery` 3.8.0 +
manual review):
- `Website/build.py` — removed ~94 lines of shadowed dead definitions
  (byte-identical output).
- DesignSystem — removed the superseded per-module scan motifs
  (`MCFragmentView`, `MCMeshView`, `MCHeroCoreView`/`MCHeroState`,
  `OrbitalProgressView`); `MCScanStage` is the single scan visualization.
- Removed `ScanConfiguration.followSymlinks` (no-op knob — the walker always
  skips symlinks), `SafetyError.notRegularFileOrDirectory` (never thrown),
  and the unadopted `MCErrorState` + a set of zero-reference DS tokens.
- Two force-unwraps in `SimilarImagesEngine` → `compactMap` + `guard let`.
- `check-first-paint.py` / `check-retired-pages.py` were orphaned checks —
  wired into `check-website.sh` and `ci.yml`.
- Fixed the stale GitHub repo description ("optional ClamAV scanning") and
  the "Paper / Ink / Cobalt" comments in `DesignSystem.swift`.
- SPDX headers on all 54 `Sources/` + 43 `Tests/` Swift files;
  `Scripts/check-spdx-headers.sh` in `ci.yml` keeps them from regressing.
- `-o pipefail` added to `build-release.sh`, `package-dmg.sh`,
  `package-zip.sh`, `test-dmg-layout.sh`.
- `TECHNICAL_DEBT.md`: 5 stale items marked RESOLVED (LICENSE pointers,
  unsigned distribution, Actions SHA-pinning, licences-in-bundle, SPDX
  headers); records the periphery baseline (engine-filled model fields not
  yet surfaced in UI = post-1.0 polish; ~42 module-`public` symbols = not
  debt).
- `Scripts/test.sh` now sweeps leaked `coretend.tests.*` preference plists
  before each run (352 had accumulated from SIGKILLed test runs; the
  `removePersistentDomain` `defer` leaves a stub file, and SIGKILL skips it).
- `Store.userPath()` / `userDirectory()` no longer create the real
  `~/Library/Application Support/CoreTend` — unit tests that call them only to
  assert a path string were creating an empty real directory each run.
- `latest.template.json` `channel` drifted to `release-candidate` at 1.0.0
  (would have published `latest.json` as a prerelease RC); fixed to `stable`
  / `prerelease:false`, and `test-release-sync.sh` now asserts the template's
  channel + prerelease (negative-tested).
- Portfolio (`content/coretend-dashboard-copy`, not pushed): the two remaining
  "Smart Care" strings in the CoreTend case study → "Dashboard" / "Privacy
  Cleaner"; typecheck + lint + test + build pass.
- `Scripts/package-dmg.sh` picks a Python ≥ 3.10 for the `dmgbuild` venv —
  `dmgbuild==1.6.7` needs 3.10+, and a stock macOS `python3` is 3.9; once
  the cached venv was gone the DMG build failed. **This would have blocked
  building the 1.0.0 DMG on this machine.**

**The 1.0.0 build was Developer ID signed + notarized twice earlier today
(`a3fd224`, `7f73d98`) — Apple notary `Accepted`, stapled, verified.** Those
artifacts were then deleted during the 2026-09-02 clean-Mac QA (deliberate
wipe). The **currently on disk** `Release/CoreTend-1.0.0-arm64-unsigned.*`
are an unsigned rebuild at `6ae2343`; the signed set must be regenerated
(see "Before tomorrow's publish" above).

`dist/latest.json` at `6ae2343`: `signed:false notarized:false
releaseTag:v1.0.0 treeState:clean sourceCommit:6ae2343`.

All non-Gatekeeper gates green at HEAD `6ae2343` (the machine's `spctl`/
`trustd` is wedged for Developer ID chains — a reboot fixes it — so the
signed-posture launch gate and `sign-and-notarize.sh` could not run):
`test.sh` 342/0 · debug + release build 0 warnings ·
`test-robustness.sh --quick` 31/0 · `test-release-manifest.sh` ·
`test-release-provenance.sh` 15/0 · `test-dmg-layout.sh` ·
`test-release-sync.sh` · `check-website.sh` 32/0 + first-paint + retired-pages ·
`check-spdx-headers.sh` 97/97 · `test-public-release-gate.py` 14/0 ·
`check-version-consistency.sh` · `check-feature-inventory.sh` ·
`check-legacy-brand-references.sh` · `check-placeholders.sh` ·
`check-private-data.sh` · `check-licenses.sh` · `check-brand-assets.sh` ·
`check-media.sh` · `check-markdown-links.py` · visual regression 79/79 ·
**`final-launch-gate.sh --expect-version 1.0.0 --expect-head 6ae2343`
(unsigned posture) → READY: 54 PASS, 0 FAIL, 0 NA, 4 HUMAN** (all four are the
sign / notarize / publish steps).

## Historical path to v1.0.0

Signing/notarization (the historic 1.0 blocker) is **done for the published
line** (rc.6). What is left for the 1.0 tag:

### Agent-automatable
| Gate | Note |
|---|---|
| Build-provenance attestation | **Still open.** Needs either a CI run or a CI path that can codesign+notarize (`release.yml` currently cannot — no Developer ID in Actions). See `SIGNING_NOTARIZATION.md` → "Publishing a signed release". |
| Crash-test matrix, 3 open items | **Done** (`2b13ee4`). disk-nearly-full + CPU-under-load are new `Scripts/test-robustness.sh` cases (`case_disk_nearly_full`, `case_cpu_under_load`); `URLSession` timeout is now `UpdateCheckerTests.requestTimeoutIsReportedAsOffline` + `defaultFetchHasABoundedTimeout`. `Documentation/Audits/CRASH_MATRIX_CLASSIFICATION.md` items 25/27/38. |
| `SmartCareView` decision (`TODO.md` #8) | **Decided: retired** (`2b13ee4`). `.smartCare` renders `DashboardView` and always did; the standalone `SmartCareView` + view model were deleted, the safety filter moved to `UserCleanupRules.autoExecutable(_:)`, `SMART_CARE.md` rewritten as a pointer to the Dashboard, `check-retired-preview-mode.sh` and `feature-inventory.json` updated. |
| Version bump + 1.0.0 release notes + launch-gate rewire (ship steps 1–2) | **Done** (`9be4043`, `84b96ae`, `67fbef9`, `dfc0f37`). |
| Sign + notarize + staple + signed manifest (ship steps 3–5) | **Proven twice on 2026-09-02** (`a3fd224`, `7f73d98`) — notary `Accepted`, stapled, verified. Those artifacts were then deleted in the clean-Mac QA wipe; the human re-runs `sign-and-notarize.sh 1.0.0` after a reboot (the machine's `spctl`/`trustd` is currently wedged for Developer ID chains). |

### Clean-install QA — 2026-09-02 (computer-use, this Mac wiped of CoreTend first)

The dev machine was stripped of every CoreTend artifact (app, `~/Library`
data, 352 leaked `coretend.tests.*` prefs, an orphan `CoreTend.plist`, all
build dirs), then rc.6 was downloaded from `coretend.ahmetbsbnr.com` and
installed like a user would.

| Step | Result |
|---|---|
| Download from the site | `CoreTend-0.9.1-rc.6-arm64.dmg`, SHA-256 = the published hash exactly, `com.apple.quarantine` + real GitHub `kMDItemWhereFroms` set. |
| DMG verification | `xcrun stapler validate` OK · `spctl --assess --type open` → "accepted, source=Notarized Developer ID" · `hdiutil verify` VALID · LICENSE/NOTICE/THIRD_PARTY_NOTICES sealed in `Contents/Resources`. |
| **DMG Finder visual (`TODO.md` #2)** | Layout correct (custom background, app → dashed arrow → Applications). **Finding:** rc.6's background reads *"Unsigned build — first launch needs System Settings › Privacy & Security"* — **wrong** for the signed rc.6. The current `generate-brand-assets.swift` already fixed this ("Local scans · reversible cleanup · nothing leaves your Mac"), and the committed `DMG-Background.png` carries the new text, so **1.0.0's DMG is correct**. |
| Drag-install to `/Applications` | Works. |
| **Clean-Mac first launch (`TODO.md` #1)** | rc.6's Developer-ID-signed app **hangs at `_dyld_start`** (no window, no store) — but this is a **machine-state fault, not a CoreTend bug**: this Mac's Gatekeeper trust-policy evaluation for non-Apple Developer ID cert chains is wedged (`spctl -a` on Google Chrome *also* hangs > 10 s; likely fallout from the day's heavy `codesign`/`spctl`/`sign-and-notarize` load). **A reboot clears it.** Proof the app is fine: `build/CoreTend.app` (Apple-Development-signed, same source) launches in ~5 s, creates its store, renders the full Porcelaine UI. |
| **Client journey (`TODO.md` #3)** | Run on the working build. Dashboard (Porcelaine identity) → Storage → Start Scan (`MCScanStage` motif live) → grouped review: Xcode DerivedData 935 MB / User caches 123 MB / User logs 64 MB, each explained + sized + per-item paths, "Move to Trash" as the explicit gate (stopped there — no execute) → Space Lens ("analysis only") → Integrity ("Native signals, not a scanner"). Quit clean. |
| Uninstaller | `Scripts/uninstall.sh --remove-all --yes` removes the app + `~/Library/Application Support/CoreTend`; "no agent, daemon, helper, or hidden file elsewhere" confirmed. Mac left clean. |
| Interactive VoiceOver / keyboard / Dynamic Type QA (`TODO.md` #7) | Not exercised this pass. Code-level a11y is tested. |

**Before tomorrow's publish:** reboot the Mac (resets `trustd`/`syspolicyd`),
run `Scripts/sign-and-notarize.sh 1.0.0 CoreTend-Notary` then
`CORETEND_RELEASE_SIGNED=1 Scripts/build-release.sh 1.0.0`, then install the
1.0.0 DMG from `/Applications` and confirm the window opens (the check rc.6
could not complete here).

**Trademark attorney review — DONE 2026-09-02.** A trademark attorney
reviewed the `COREXTEND` (MIPS Tech, class 9) adjacency and concluded CoreTend
and COREXTEND are two entirely separate products with two entirely separate
meanings — no conflict. The name is cleared for the 1.0 release. Not a
registration and not a `®`; a filing remains a separate future step. See
`Documentation/CORETEND_TRADEMARK_SCREENING.md`.

### Ship sequence
1. ~~Bump `PublicIdentity.example.json` → `1.0.0`, `channel: stable`; mirror
   `Info.plist` + `PROJECT_STATE.json`.~~ **Done — `9be4043`.**
2. ~~`Release/Notes/1.0.0.{en,fr}.md`.~~ **Done — `9be4043`.**
3. ~~`Scripts/package-local.sh` → `Scripts/sign-and-notarize.sh 1.0.0 CoreTend-Notary`.~~
   **Done 2026-09-02** — signed, notarized (`Accepted`), stapled.
4. ~~`git tag -a v1.0.0` → `CORETEND_RELEASE_SIGNED=1 Scripts/build-release.sh 1.0.0`.~~
   **Done** — tag local only; manifest `sourceCommit:dfc0f37`, `releaseTag:v1.0.0`.
5. ~~Run every release gate.~~ **Done — `final-launch-gate.sh` READY in the
   signed posture** (55 PASS / 0 FAIL / 1 human = "no GitHub release yet").
6. Minisign-sign the artifacts (human — key password): `minisign -Sm
   Release/SHA256SUMS`.
7. Merge `release/v1.0.0-prep` to `main`; move the `v1.0.0` tag onto the merge
   commit and re-run `CORETEND_RELEASE_SIGNED=1 Scripts/build-release.sh 1.0.0`
   there so `sourceCommit` names it (the notarized bytes are reused, not
   rebuilt); `gh workflow disable` the Release workflow, `git push` branch +
   tag, `gh release create v1.0.0` with the signed assets, `gh workflow enable`.
8. `Scripts/sync-published-release.sh`; commit `published-release.json`.
9. Update the site copy (already signed-aware) and redeploy.

`final-launch-gate.sh` already allows 1.x once `published-release.json` shows
`signed && notarized` (true since rc.6).

---

## Current release — v0.9.1-rc.5, verified 2026-08-02

The annotated `v0.9.1-rc.5` tag resolves to
`efccece091ca793d8e176edf9249ec104332856a`. The tag-triggered clean macOS
workflow passed the complete release gates and published the non-draft
prerelease at
`https://github.com/ahmetbsbnr/coretend/releases/tag/v0.9.1-rc.5`.

The downloaded public DMG is
`CoreTend-0.9.1-rc.5-arm64-unsigned.dmg`, 4,703,523 bytes, SHA-256
`b654975770cc1bfeb7e6a4f3cf180653a3182a55f8dc135db2083a72528998eb`.
The public ZIP is 2,857,653 bytes, SHA-256
`c3e2c58a1034a8654c931dabedd279b5b320abd03e84caa300bb9e53e83675ae`.
GitHub asset digests, `latest.json`, `SHA256SUMS` and Minisign all agree.

The exact public DMG passes `hdiutil imageinfo` and verification, mounts and
detaches twice, contains the designed Finder layout and Applications link,
and copies a self-contained arm64 app off-volume. The bundle reports marketing
version 0.9.1-rc.5, build 915 and macOS 14.0+. Its ad-hoc signature verifies;
Gatekeeper rejects it with exit 3 as expected without Developer ID or
notarization. Isolated English/dark and French/light launches stay alive and
exit normally under the harness. Bundle and Mach-O scans find IntegrityCore
and no current ClamAV scanner/interface, retired Dry Run UI copy, personal
checkout path or local dependency.

rc.5 removes the former Dry Run product mode. Scans remain read-only; cleanup
surfaces present reviewed selections and require explicit confirmation before
eligible paths move to the macOS Trash. The sections below are retained as
historical release-state evidence and do not describe the current download.

## Current post-release checkpoint — 2026-07-27

No application source changed, so no 0.9.1 binary is being prepared. The
public 0.9.0 assets remain immutable and were downloaded again: ZIP and DMG
hashes match `SHA256SUMS`, `unzip -t` and `hdiutil verify` pass, and
`latest.json` is valid. New website/media work must not be described as part of
the downloadable 0.9.0 binary.

The branch now contains three approved media sources (Smart Care screenshot,
menu-bar screenshot, and genuine Gatekeeper clip) plus local site changes. Nothing
in this checkpoint has been pushed, merged, deployed, or attached to the
release yet. `v0.9.0` remains annotated and points to `a6aa3bf`.

## Local presentation work after v0.9.0 — 2026-07-27

The binary release remains exactly the annotated `v0.9.0` tag at
`a6aa3bf20cc1f3b7623291660c4943db2e5d4a50`. The current branch contains
post-release website, help, documentation and media-validation work; none of
it is represented as part of the downloadable 0.9.0 binary.

The public ZIP, DMG, `latest.json` and `SHA256SUMS` were downloaded again and
validated. Their sizes, hashes, archive integrity and manifest values match
the production state below. The available binary is arm64, requires macOS 14
or later, is unsigned by Developer ID and is not notarized.

This historical paragraph is superseded by the checkpoint above: two supplied
media items subsequently passed full privacy review and were integrated.

## Production state — verified 2026-07-27

The annotated `v0.9.0` tag is public and still resolves to
`a6aa3bf20cc1f3b7623291660c4943db2e5d4a50`. GitHub hosts a non-draft
prerelease at
`https://github.com/ahmetbsbnr/coretend/releases/tag/v0.9.0` with the ZIP,
DMG, `latest.json`, and `SHA256SUMS` assets. GitHub licence detection remains
`NOASSERTION` / `Other`; no licence change was made during deployment.

Production is served by Vercel project `ahmets-projects-ed32c752/coretend`,
deployment `dpl_GcQWq468fFGa6zcaLWLx1tinVhGg`, at
`https://coretend.ahmetbsbnr.com`. DNS, HTTP-to-HTTPS redirection, TLS,
security headers, public routes, asset downloads and checksums were verified.
Production indexing is enabled; `robots.txt` allows crawling and references
the public sitemap.

Downloaded artifact verification reproduced the recorded sizes and hashes:
ZIP 2833085 bytes / `1d224b7655cfbcb15b5f9a37302c454775fae34d17d7f010f8c9ab026999b7d8`;
DMG 5192666 bytes /
`f2fbc7840ac4a5509836a495c51e72e6cfd52ef24e6cbdd792fa8404bd3f6c8d`.
`SHA256SUMS`, ZIP integrity, DMG integrity and `latest.json` validation pass.
The isolated post-deployment gate reports **55 PASS, 0 FAIL,
2 NOT_APPLICABLE, 0 HUMAN_ACTION_REQUIRED**.

The prepublication snapshot below is historical and is superseded by this
section. No branch commit was pushed as part of the deployment.

Snapshot at commit `a6aa3bf`, tag `v0.9.0` (local only). Written 2026-07-27.

## Version

**0.9.0**, unsigned public beta. Not 1.0.0; not claimed as signed or
notarized anywhere. The launch gate refuses any 1.x while this holds.

## Strategy: unsigned public beta

`security find-identity -v -p codesigning` reports **0 valid identities**. A
Developer ID requires a paid Apple Developer Program membership, out of scope.
That fixes the outcome — see `DECISIONS.md` D-N6.

## Artifacts — verified at HEAD `a6aa3bf`

| Artifact | Size (bytes) | SHA-256 |
|---|---|---|
| `CoreTend-0.9.0-arm64-unsigned.zip` | 2833085 | `1d224b7655cfbcb15b5f9a37302c454775fae34d17d7f010f8c9ab026999b7d8` |
| `CoreTend-0.9.0-arm64-unsigned.dmg` | 5192666 | `f2fbc7840ac4a5509836a495c51e72e6cfd52ef24e6cbdd792fa8404bd3f6c8d` |

Verification commands and results, this exact build:

- `unzip -t Release/CoreTend-0.9.0-arm64-unsigned.zip` → **No errors detected.**
- `hdiutil verify Release/CoreTend-0.9.0-arm64-unsigned.dmg` → **checksum is VALID.**
- `(cd Release && shasum -a 256 -c SHA256SUMS)` → **ZIP: OK, DMG: OK, latest.json: OK.**
- `python3 -m json.tool Release/latest.json` → valid JSON.
- ZIP contains `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md` (Apache-2.0 §4).

`Release/latest.json` — key fields: `version: 0.9.0`, `releaseTag: v0.9.0`,
`sourceCommit: a6aa3bf20cc1f3b7623291660c4943db2e5d4a50`, `treeState: clean`,
`signed: false`, `notarized: false`, `releasable: true`.

`Release/latest.json`, `Release/SHA256SUMS` and `dist/` are **generated,
gitignored, never committed.**

## Signing and notarization

| Property | Value | How verified |
|---|---|---|
| Signing identities | 0 | `security find-identity -v -p codesigning` |
| Built app signature | `Signature=adhoc`, `TeamIdentifier=not set` | `codesign -dv build/CoreTend.app` |
| Signature integrity | valid on disk | `codesign --verify --deep --strict` |
| Gatekeeper | **rejected** | `spctl --assess --type execute` |
| Notarization | not performed, not possible without a Developer ID | — |

The `spctl` rejection is the **expected, correct** result for this build. It is
recorded as a rejection, never reframed as a pass.

## GitHub

- Repository: `github.com/ahmetbsbnr/coretend`, public, default branch `main`
  at `b2bca85` — verified via `gh api repos/ahmetbsbnr/coretend`.
- Private vulnerability reporting: **enabled**.
- Secret scanning: **enabled**. Push protection: **enabled**.
  Dependabot security updates: **enabled**.
- `secret_scanning_non_provider_patterns` and `secret_scanning_validity_checks`:
  disabled — optional hardening, never claimed enabled.
- Licence detection: was `NOASSERTION`; `LICENSE` restructured to the verbatim
  Apache-2.0 text to fix this (commit `45ed83b`). **Unconfirmed against the
  live API** — nothing has been pushed since the change. Verify with
  `gh api repos/ahmetbsbnr/coretend --jq .license.spdx_id` after pushing.

## Tag

`v0.9.0`, annotated, **local only, never pushed**. Points at `a6aa3bf`
(verified: `git rev-parse v0.9.0^{commit}` = `git rev-parse HEAD`).

No `v0.9.0` or `0.9.0` tag existed before this session created one. It was
moved once, from `a43d644` to `a6aa3bf`, entirely locally, to fix a bug found
in the gate that was checking it (`git rev-parse` on an annotated tag returns
the tag object's own sha, not the commit sha — the gate now dereferences with
`^{commit}`). It has never been pushed, so this was not "silently moving an
existing published tag" — it is local iteration before publication.

## GitHub prerelease

**Not created.** Exact commands, once authorised:

```sh
git push origin v0.9.0
gh release create v0.9.0 \
  --title "CoreTend 0.9.0 — Public Beta" \
  --prerelease \
  --notes-file Release/Notes/0.9.0.en.md \
  Release/CoreTend-0.9.0-arm64-unsigned.zip \
  Release/CoreTend-0.9.0-arm64-unsigned.dmg \
  Release/latest.json
```

## Vercel / site deployment

**Not performed.** Vercel CLI authenticated as `ahmetbsbnr`; no project
created, no domain added. `Website/vercel.json` generated and ready (headers
per `WEBSITE_SECURITY.md`). Exact sequence in `WEBSITE_DEPLOYMENT.md`.

## DNS / SSL

`coretend.ahmetbsbnr.com` **already resolves** (`dig +short` returns two
addresses) but **returns HTTP 404** — the name points somewhere real, the site
is not deployed there yet. Neither DNS nor SSL is marked complete; both require
the deploy first, then re-verification with `dig`, `curl -sI`, and
`openssl s_client … | openssl x509 -noout -dates`.

## Public download

**Not available.** No GitHub release exists, so `Website/en/download.html`
correctly shows "prepared, not yet published" with no download link — verified
by regenerating the site against the current manifest.

## Proof summary

| Item | Result | Evidence |
|---|---|---|
| Tests | 296 / 58 suites, 0 failures | `bash Scripts/test.sh` |
| Debug build | clean | `swift build` |
| Release build | clean | `swift build -c release` |
| Final launch gate | 52 PASS, 0 FAIL, 2 NOT_APPLICABLE, 2 HUMAN_ACTION_REQUIRED | 3 runs, identical, exit 0 each |
| ZIP | valid | `unzip -t` |
| DMG | valid | `hdiutil verify` |
| Checksums | match | `shasum -a 256 -c SHA256SUMS` |
| Repo clean | yes | `git status --porcelain` empty |
| Push performed | **no** | `git log --oneline origin/main` unchanged at 1 commit |
| Deploy performed | **no** | no Vercel project exists |
| Secrets | none found in tracked files | `check-private-data.sh` PASSED |

## Remaining human actions

1. `git push origin v0.9.0`
2. `gh release create v0.9.0 --prerelease …` (command above)
3. Verify downloads publicly (URL, HTTP status, checksum match)
4. `cd Website && vercel deploy --prod`
5. `vercel domains add coretend.ahmetbsbnr.com`, then create the CNAME at the
   registrar for `ahmetbsbnr.com` — the one step outside this environment
6. Verify DNS/TLS for real, then flip `siteIndexable` to `true` and regenerate
7. Confirm GitHub reports `Apache-2.0` after the push
