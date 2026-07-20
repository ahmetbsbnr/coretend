# Requirements Decision History

Reconciliation-session document. Verifies, against the actual repo state at commit
`b33c06b8d68b9b03316821c3f6cfb17252f35011`, the settled product/architecture/data/site/licensing
decisions that this phase of the audit is built on. Each claim below is checked with a real command or
file reference, not restated from a prompt. Where evidence contradicts a claim, that's stated plainly.

## Apple distribution stance

**Claim**: no App Store, no submission, no mandatory Developer ID/notarization this phase, unsigned
distribution OK if honestly disclosed, no Gatekeeper bypass.

- `Release/latest.json`: `"signed": false, "notarized": false` — confirmed current (this session
  rebuilt and re-verified via `Scripts/test-release-manifest.sh`, all checks pass).
- `Documentation/INSTALL_UNSIGNED.md` explicitly warns, "Do not work around Gatekeeper by disabling
  platform security instead of trusting this specific app" (line 72-84) — i.e. never run
  `sudo spctl --master-disable` or any system-wide Gatekeeper disable.
- No App Store artifacts anywhere in the repo (no `.storekit`, no `ExportOptions.plist` for App Store,
  no `Documentation/*APP_STORE*`). `DISTRIBUTION_AUDIT.md` and `FIRST_PUBLIC_RELEASE_CHECKLIST.md`
  confirm distribution is direct-download ZIP/DMG only.
- **Verdict: holds.** Evidence matches the claim exactly.

## Product positioning

**Claim**: real public independent open-source utility, not school/portfolio/AI-demo, not
Apple/MacPaw/CleanMyMac-affiliated.

- `LICENSE` (Apache-2.0) + `LICENSES/` + `TRADEMARKS.md` present — a real open-source license grant,
  not a portfolio placeholder.
- `README.md`/`Documentation/FAQ.md` do not claim Apple/MacPaw/CleanMyMac affiliation; `FAQ.md:42`
  explicitly separates itself from disabling SIP/Gatekeeper — a defensive, not affiliated, stance.
- `Documentation/TRADEMARKS.md` exists specifically to keep "MacCare Local" branding independent of
  any code/content license, consistent with an independent-product stance rather than a demo project.
- No files reference "school," "assignment," "portfolio piece," or similar in `Documentation/`.
- **Verdict: holds**, with the caveat (already tracked in `HUMAN_BLOCKERS.md`) that real maintainer
  identity, repo URL ownership, and legal entity are still placeholder/human-pending — positioning is
  consistent, but publication readiness is not yet complete.

## Architecture stance

**Claim**: native Swift/SwiftUI, arm64, no Electron/Tauri/WebView-as-primary-UI.

- `Package.swift` declares 9 SwiftPM targets, zero external dependencies (`Documentation/DEPENDENCIES.md`
  confirms via `Package.swift` inspection).
- `grep -rl "WKWebView\|electron\|tauri" Sources/` → no matches. The only "web" content in the repo is
  the static `Website/` (separate product site, not the app's UI).
- `Release/latest.json`: `"architecture": "arm64"`.
- **Verdict: holds.**

## Data stance

**Claim**: local-only, no account, no telemetry, no in-app analytics, no auto-upload, diagnostics only
on explicit voluntary export, anonymized.

- `Documentation/PRIVACY_AUDIT_CURRENT.md` (session 2): "zero `URLSession`/network-framework/socket
  usage found anywhere in `Sources/`; zero analytics/telemetry/crash-reporter/account-system code found."
- `Release/latest.json`: `"telemetry": false, "accountRequired": false`.
- `Sources/MacCareApp/DiagnosticReport.swift` + `Tests/MacCareAppTests/DiagnosticReportTests.swift`:
  diagnostic export is a manual Settings action with a mandatory preview sheet before save, and a test
  asserting a fixture with fake sensitive strings never leaks into the built report.
- **Verdict: holds**, and is the most heavily evidence-backed claim in this list — this session did not
  re-run the full `URLSession`/network grep independently (relying on session 2's sweep, which was a
  text-level `Sources/` grep, not a binary-level audit) — flagged as a good target for a fresh
  independent grep in session 2 of this new phase, not because there's reason to doubt it.

## Site stance

**Claim**: product site not portfolio, FR/EN, no account, no tracking, no fake download.

- `Website/` has parallel `en/` and `fr/` content per `WEBSITE_ARCHITECTURE.md` (session 3: "27 website
  HTML files," "2 localizations").
- `WEBSITE_AUDIT.md` (session 3) confirms the download page is manifest-driven and shows an honest
  "no public release yet" state rather than a fake download link — matches `Release/latest.json` having
  `repositoryURL`/`websiteURL` but no `downloadURL` field.
- `Documentation/WEBSITE_PRIVACY.md`, `WEBSITE_SECURITY.md` document zero-tracker intent; session 2's
  privacy sweep did a "shallow text-level check of `Website/*.html`" for tracker script tags (0 found)
  and flagged a full website audit as still queued — session 3 subsequently delivered
  `Documentation/WEBSITE_AUDIT.md`, closing that gap.
- **Verdict: holds.**

## Licensing stance

**Claim**: Apache-2.0 code / CC-BY-4.0 docs-and-original-resources / trademark handled separately /
third-party licenses preserved.

- `LICENSE` (repo root, now fixed this session — see the `fix(legal)` commit) declares exactly this
  three-way split and points at `LICENSES/Apache-2.0.txt`, `LICENSES/CC-BY-4.0.txt`, `TRADEMARKS.md`,
  `Documentation/THIRD_PARTY.md`.
- `Documentation/LEGAL_AND_LICENSE_STATUS.md` (session 2) verified all of `LICENSE`, `LICENSES/`,
  `TRADEMARKS.md`, `Documentation/THIRD_PARTY.md` actually exist and are internally consistent, and
  found the real dead-reference defect this session just fixed (`LICENSE` pointed at
  `Documentation/LICENSING.md` and `THIRD_PARTY_NOTICES.md`, neither of which existed).
- **Verdict: holds, and the one concrete defect under this claim is now fixed** (commit `964f110`,
  this session).

## Summary

All six settled-decision areas check out against current repo state. The only two open items are
process, not fact: (1) the network/analytics grep sweep behind the "data stance" claim was done once,
text-level, in session 2 — a fresh independent verification would strengthen it further; (2) full
publication readiness (maintainer identity, repo URL, legal entity, domain) remains genuinely blocked
on human decisions per `Documentation/HUMAN_BLOCKERS.md`, unrelated to whether these six decisions
themselves are honored in the code.
