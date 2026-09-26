# Public integration — Programme 4

Date: 2026-09-26

## Delivered

- Localization catalogs now have syntax, duplicate-key, and exact EN/FR key-parity validation (585 keys per locale), run by repository-doctor and CI.
- Release synchronization verifies the selected stable release's signed manifest, then verifies downloaded DMG and ZIP byte lengths and SHA-256 before changing generated release metadata and download redirects (each file uses atomic replacement after full validation).
- Website build only exposes release version, checksum, signing claims, structured release metadata, `latest.json`, and artifact redirects when the local record carries a verified attestation. Legacy/unattested record falls back to GitHub Releases.
- Landing copy no longer promises reclaimable capacity, identifies sample metrics as example data, and reflects the current eleven app destinations.
- Installation and provenance documentation distinguishes source-built local package state from public release evidence.

## Evidence

- `python3 Tests/ScriptTests/test_localization_parity.py`
- `python3 Tests/ScriptTests/test_published_release.py`
- `python3 Tests/ScriptTests/test_website_release_mode.py`
- `bash Scripts/test-release-sync.sh`
- `python3 Scripts/check-copy-honesty.py`
- `python3 Scripts/check-localization-parity.py`
- `python3 Scripts/test-public-release-gate.py`
- `python3 Scripts/check-markdown-links.py`

## Limits

No network synchronization, public release download, Vercel deployment, or publication was performed. Checked-in release record has no verification attestation; public release state therefore remains unknown. Browser capture/accessibility gate remains dependent on pinned Playwright installation. Native GUI limits recorded in Programme 3 remain unchanged.

## Run record

Base after Programme 4 task 1: `c70ee0355a2a45a8ad476b5c0d032f8ae588ed45`.
Implementation commits: `0a47e9f` (signed manifest and artifact verification),
`d48b142` (fail-closed site), `514a81f` (claims and documentation).

Fixture totals on 2026-09-26:

- Localization parser: 4 passed.
- Published release synchronizer: 8 passed; `bash Scripts/test-release-sync.sh` passed.
- Website release modes: 3 passed (verified and legacy/unverified fixtures).
- Public release metadata generator: 14 passed.

Also passed: `Scripts/repository-doctor.sh`, release-sync consistency checks,
copy honesty (8 critical keys in each locale), localization parity (585/585),
design tokens, first paint, retired-page redirects, Markdown links (0 broken,
216 internal links checked), Python compilation, Bash syntax, and `git diff
--check`. A static site build to `/private/tmp/coretend-p4-site` contained no
`latest.json` or `SHA256SUMS`; English and French routes/support linked to the
general GitHub Releases page and displayed unverified status.

Limits: `Scripts/check-website.sh` reached the Playwright test and stopped because
Playwright is not installed (`Cannot find package 'playwright'`). Focused SwiftPM
`CoreTendAppTests` was attempted but stalled at planning (`1 / 1496` deferred
tasks), then was interrupted before test execution. Programme 3's recorded
focused app/accessibility results remain the latest Swift test evidence; this
programme changed no Swift sources. No authenticated GitHub comparison,
network fetch, publication, deployment, or GUI capture was run.
