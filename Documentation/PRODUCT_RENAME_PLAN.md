# Product Rename Plan

Sequencing for the eventual rename, once a name reaches
`CLEAR_FOR_ENGINEERING` and `Configuration/BrandRenameApproval.local.json`
exists. **Nothing in this document is executed.** No string has been
replaced. See `product-rename-inventory.json` for the per-category detail
this plan sequences.

## Ordering principle

Low-risk, no-data-migration categories go first and can be done as a
single mechanical pass with review. High-risk, stateful categories
(bundle identifier, local user data) go last, only after the low-risk
pass is proven stable, and only with a tested migration path already in
place (`USER_DATA_RENAME_MIGRATION.md`,
`REBRAND_MIGRATION_TEST_PLAN.md`).

## Sequence

1. **Legal/trademark review** (manual, human-led): `TRADEMARKS.md`,
   `NOTICE`, `COPYRIGHT`, `LICENSE`, `THIRD_PARTY_NOTICES.md`. Not a
   find-replace — each needs deliberate review since they are governance
   text. Gate: `check-licenses.sh`.
2. **Documentation pass** (mostly mechanical, with manual review for
   HISTORICAL-marked sections that must stay as point-in-time records,
   not be rewritten as if the new name always applied). Gate:
   `check-markdown-links.py`, `check-placeholders.sh`.
3. **Website regeneration**: edit `Website/generate.py`'s name constant(s)
   once, regenerate all 30 output files. Gate: manual review of a sample
   of regenerated pages + existing link-check tooling.
4. **CI workflow / issue-template text**: mechanical text pass across
   `.github/`. Low risk since nothing has run against a remote yet (no
   remote configured).
5. **Scripts**: mechanical text pass across `Scripts/*.sh` (comments,
   output strings, DMG volume name/window title in `package-dmg.sh`).
   Gate: re-run every affected script's own test/check.
6. **Release artifact naming**: `Release/latest.json` fields, artifact
   filename pattern in `build-release.sh`/`package-zip.sh`/
   `package-dmg.sh`, new `Release/Notes/<version>.{en,fr}.md`. Gate:
   `test-release-manifest.sh`, `test-distribution.sh`.
7. **SwiftPM package/executable/test-target rename**: `Package.swift`
   (package name + executable target `MacCareApp` → new name + test
   target folder `Tests/MacCareAppTests/` → matching new name, done
   together, atomically, since a mismatch breaks the test target). Gate:
   `swift build`, `Scripts/test.sh`.
8. **`Resources/Info.plist`**: `CFBundleName`, `CFBundleDisplayName`,
   `CFBundleExecutable` (must match step 7's new executable name). Gate:
   `swift build -c release`, `test-distribution.sh` launch check.
9. **Bundle identifier + local user data migration** (highest risk, done
   last, only with a tested migration in place — see
   `USER_DATA_RENAME_MIGRATION.md` and
   `REBRAND_MIGRATION_TEST_PLAN.md`): `local.maccare.app` →
   `<new-reverse-dns>.app` in `Info.plist` and
   `Configuration/PublicIdentity.example.json`. This step is the one that
   can orphan real user data (`~/Library/Application Support/MacCareLocal/`
   is keyed by the old bundle ID's app-container convention, and
   `NSUserDefaults` domains are keyed by `CFBundleIdentifier`) if not
   paired with a working migration. **Do not do this step without
   step 9's migration already tested per `REBRAND_MIGRATION_TEST_PLAN.md`.**

## What stays untouched throughout

Core Bloom / Orbital Ecology vocabulary (`MCColor`, `MCSpacing`,
`MCMotion`, `MCFont`, `CoreBloomMark`, module/library target names like
`ScanCore`/`SafetyCore`/`DesignSystem`/etc.) — none of these are brand
references, see `product-rename-inventory.json`'s
`explicitlyExcluded` field.

## Verification after every step

`bash Scripts/test.sh && swift build && swift build -c release &&
bash Scripts/repository-doctor.sh` — the same battery this project
already runs after every change, applied per rename step rather than
once at the end, so a break is caught at the step that caused it.
