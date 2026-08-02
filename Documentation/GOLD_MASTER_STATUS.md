# CoreTend rc.5 delivery status

Last verified: 2026-08-02 (Europe/Istanbul)

This journal records the recovery, immutable binary release and public-product
promotion for `v0.9.1-rc.5`. Earlier rc.3 and rc.4 releases remain unchanged in
GitHub history. The rc.5 asset was built by the tag workflow from the exact
merge commit below; it is not the earlier local candidate.

## Recovery checkpoint

- Repository: workspace-relative `products/coretend/app`
- Recovered release branch: `release/v0.9.1-rc.4`
- Recovered base: `fb76c47d47ca6f544063a5de713a9c30245beb25`
- Existing recovered commits: `b5f84e2` and `87e035e`
- Existing recovery PR: GitHub PR #5
- Recovered uncommitted change: the canonical `Website/index.html` contained
  the under-900px `.flow-sticky { position: static; top: auto; }` correction.
  It was backed up before any edit and retained in the canonical template.
- Support's obsolete literal rc.3 was replaced by the canonical published
  release record, and a regression test prevents a hard-coded release version.

The recovery did not rely on a stash. Fresh independent archives were made
before work continued:

| Scope | Archive | SHA-256 |
| --- | --- | --- |
| Interrupted CoreTend | `_backups/coretend-interrupted-20260802T070612Z.tar.gz` | `447159ba457588785b696d12a00c765a533c7adfb4725fcbab2fa4595ce99ca4` |
| Portfolio pre-release | `_backups/portfolio-pre-rc4-20260802T071550Z.tar.gz` | `3a9076d6ec1dff127db0f8dde62d2b346c87282e8a24be63f410bcce526e82fe` |

Each archive contains repository state, a full Git bundle, bundle verification,
patch/untracked evidence and restore instructions. Final post-delivery bundles
are created separately after production verification.

## Why rc.5 exists

`v0.9.1-rc.4` had already become an immutable public tag and release when the
additional requirement arrived to remove Dry Run from the application, site
and current project surface. The public rc.4 tag and assets were therefore not
rewritten. The successor is `v0.9.1-rc.5`, build 915.

## Source lineage

- Release branch: `release/v0.9.1-rc.5`
- Release PR: GitHub PR #8
- Release commits:
  - `0a58a89` — remove the Dry Run product mode and prepare rc.5
  - `e6f7465` — accept manually reviewed rc.5 visual baselines
  - `72305ed` — merge the current `origin/main` route fixes
  - `7198c11` — harden the Gatekeeper client-journey check
  - `05121ab` — remove the stale Settings UI Dry Run contract
- Merge commit and tagged source:
  `efccece091ca793d8e176edf9249ec104332856a`
- Annotated tag: `v0.9.1-rc.5`; the dereferenced remote tag resolves exactly to
  the merge commit above.
- Post-publication branch: `release/v0.9.1-rc.5-publish`

GitHub automatically removed the remote release branch at merge time despite
the merge command not requesting deletion. The intact local branch was pushed
back immediately and is retained through final delivery verification.

## Retired Dry Run product mode

Dry Run is no longer a selectable or default product behavior:

- SafetyCore no longer exposes a Dry Run execution stage/property/setter and
  approved execution always targets the macOS Trash after revalidation.
- Settings, onboarding, activity/export copy, current view models,
  localizations, site copy and deterministic showcase fixtures no longer expose
  the mode.
- Cleanup, Duplicates, Applications, Leftovers, Privacy Cleaner, Smart Care and
  Space Lens show a reviewed selection and require explicit confirmation.
- Persistence migration v4 removes the retired preference. Reviewed legacy
  storage columns/keys remain only for downgrade/data compatibility and are
  not exposed by current APIs.
- `Scripts/check-retired-preview-mode.sh` is wired into repository doctor and
  Security. It scans app/site/docs/fixtures/UI tests, requires confirmation on
  every destructive surface and permits only the reviewed compatibility
  references in Store migration code.

Generic `--dry-run` options in unrelated uninstall/branch-maintenance tooling
remain because they are safety controls for those developer scripts, not an app
or website product feature. Historical changelogs may describe the removed
mode as history.

## Quality gates

| Gate | Verified result |
| --- | --- |
| Swift Debug build | passed |
| Swift Release build | passed with zero warnings |
| Swift package suite | 338/338 passed; recovered report was 329 |
| Xcode workspace suite | 346 total; 337 passed, 0 failed, 9 explicitly skipped |
| Xcode skips | 8 SwiftPM `XCUIApplication` contracts lack a native UI runner; 1 Developer-ID-only assertion has no signing identity |
| Demo fixture validation | passed, including 7 Python regression tests |
| Repository/Security/private-data/secrets/paths | passed |
| Localization/resources | passed |
| Site behavior/accessibility | 32/32 passed |
| Site visual matrix | 79 reviewed fingerprints, 7 required viewports, EN/FR, light/dark and Reduce Motion |
| PR #8 | CI, distribution, Security and both Vercel checks green on `05121ab` |
| Merge commit | CI, distribution, Security and both Vercel deployments green on `efccece` |
| Tag workflow | clean checkout, tests, zero-warning build, DMG/ZIP, layout, checksums, SBOM, provenance and Minisign all passed |

Xcode 26.6 reports deprecation warnings for the pinned `swift-testing` 0.99
dependency under Swift 6.3; the application Release build itself has zero
warnings. The skip boundary is explicit and is not reported as executed UI
coverage. Exact-artifact launch testing provides the final application smoke
gate.

## Public release

Release URL:
`https://github.com/ahmetbsbnr/coretend/releases/tag/v0.9.1-rc.5`

| Field | Downloaded public value |
| --- | --- |
| DMG | `CoreTend-0.9.1-rc.5-arm64-unsigned.dmg` |
| DMG size | `4,703,523` bytes |
| DMG SHA-256 | `b654975770cc1bfeb7e6a4f3cf180653a3182a55f8dc135db2083a72528998eb` |
| ZIP | `CoreTend-0.9.1-rc.5-arm64-unsigned.zip` |
| ZIP size | `2,857,653` bytes |
| ZIP SHA-256 | `c3e2c58a1034a8654c931dabedd279b5b320abd03e84caa300bb9e53e83675ae` |
| Source commit | `efccece091ca793d8e176edf9249ec104332856a` |
| Version/build | marketing `0.9.1-rc.5`; bundle `0.9.1` (915) |
| Platform | Apple silicon arm64; macOS 14.0+ |
| Signature | ad hoc; strict deep verification passed |
| Notarization | none; `spctl` exit 3/rejection is expected |

The GitHub asset API digest, freshly downloaded files, release `latest.json`,
`SHA256SUMS` and every Minisign signature agree. English and French release
notes are attached without replacing any binary asset. Evidence is preserved
under `_backups/coretend-rc5-public-20260802T134401Z/`.

## Exact public DMG validation

The downloaded DMG passes `hdiutil imageinfo` and full CRC verification. It
mounted read-only, detached, remounted and detached again. Its visible volume
contains only `CoreTend.app` and the Applications link; sealed layout resources
include `.DS_Store`, the volume icon and the HiDPI background.

The app was copied to an isolated Applications directory. The copied bundle is
arm64, self-contained, ad-hoc signed and reports the expected identifier,
version, build and minimum macOS. Bundle/Mach-O scans find:

- no current `ClamAV`, `clamscan` or `MalwareEngine` file/string;
- no retired Dry Run UI/localization copy;
- no real build-account or checkout path;
- `IntegrityCore`, `ProvenanceScanner` and `CodeSignInspector` present.

With `CORETEND_TEST_MODE=1`, an isolated store and no personal fixtures, the
exact public app stayed alive in English/dark and French/light sessions and
terminated normally under the harness. Gatekeeper rejection is documented as
the expected unsigned-build block, not an application crash. The supported
user route is copy to Applications, try once, then System Settings → Privacy &
Security → Open Anyway. The product never disables Gatekeeper or strips
quarantine automatically.

## `hdiutil` diagnosis

The earlier local failure was caused by the sandboxed disk-image device
lifecycle, not by a hidden packaging fallback. The failing environment emitted
`Cannot start hdiejectd because app is sandboxed` and `Périphérique non
configuré`. Packaging now runs on an unsandboxed macOS host or clean macOS
Actions runner and creates Finder metadata deterministically with pinned
`dmgbuild`/`ds_store` tooling. It never launches Finder or AppleScript. The
headless layout gate and repeated imageinfo/verify/mount/detach cycles pass.

## Public website and portfolio promotion

`Configuration/published-release.json` is generated from the newest real
GitHub Release and is the reviewed source for Support, Download, EN/FR copy,
`latest.json`, `SHA256SUMS` and both Vercel `/download` rules. The rc.5 hash and
size are pinned only after the independent public download above.

The production site is generated from `Website/index.html` by
`Website/build.py`. Its shared shell covers home, Privacy, Support, Legal,
Licenses, installation/download and the real 404, with independent logo arcs
around a fixed center, route-specific Paper/Ink/Cobalt backgrounds, themes,
FR/EN, keyboard focus, responsive layouts and Reduce Motion. The narrow
Workflow overlap and obsolete Support rc.3 literal are regression-gated.

The portfolio branch `release/coretend-v0.9.1-rc.5` removes the former mode
from current showcase data/copy and replaces its obsolete Settings capture.
Its release metadata is synchronized only from GitHub's published manifest.
Final production HTTP, visual and repository equality checks are recorded in
the delivery report and final verified bundle metadata; they cannot be
truthfully embedded into the commit whose deployment they verify.

## Remaining distribution limits

The only intended future distribution work is Developer ID signing, Apple
notarization and a separately evaluated Mac App Store edition. rc.5 is not
currently available from the Mac App Store and makes no claim otherwise.
