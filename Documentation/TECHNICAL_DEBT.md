# Technical Debt — consolidated, sessions 1-3

Real gaps only, each with evidence. Severity: critical/high/medium/low.
Effort: XS/S/M/L/XL (relative, no hours).

## Critical

None found across three audit sessions that block correctness or safety
of the core scan/delete/quarantine paths — the `PathValidator` protections,
argument-array-only `Process()` call, and 86/86 passing tests hold up
(see `SECURITY_AUDIT_CURRENT.md`).

## High

1. **LICENSE file references two non-existent paths** — RESOLVED (verified
   2026-09-02). `LICENSE` is now the verbatim Apache-2.0 text with no
   repo-specific path pointers; `Documentation/LICENSING.md`,
   `THIRD_PARTY_NOTICES.md` (root), `Documentation/THIRD_PARTY.md` and
   `NOTICE` all exist.

2. **Website legal identity placeholders unresolved** — CLOSED in the 0.9.0
   launch phase. Category: distribution/legal.
   Evidence when opened: `WEBSITE_AUDIT.md` — the `LEGAL_NAME_TO_DEFINE`,
   `LEGAL_ADDRESS_TO_DEFINE`, `SECURITY_CONTACT_TO_DEFINE` and
   `DOMAIN_TO_DEFINE` tokens were present in `legal.html`/`privacy.html`/
   `security.html` in both locales. Impact: the site could not go live
   truthfully with real legal/contact info missing.
   Resolution: `Website/generate.py` now reads
   `Configuration/PublicIdentity.example.json` overlaid with the gitignored
   `PublicIdentity.local.json`, which carries a real publisher of record, a
   verified security-reporting channel and the production domain.
   `legalAddress` stays deliberately `null` under LCEN Art. 6 III-2 and the
   page says so. Website placeholder count is zero.

3. **Unsigned, unnotarized distribution** — RESOLVED. Developer ID identity
   `Ahmet BASBUNAR (NSCUV5G738)` is installed; `Scripts/sign-and-notarize.sh`
   produces a real Developer ID signed + Apple-notarized + stapled build.
   Shipped this way since `v0.9.1-rc.6` (published 2026-08-31); `1.0.0` is
   signed and notarized on the `release/v1.0.0-prep` branch.

## Medium

4. **Only 1 of 22 shell scripts uses full `set -euo pipefail`** — category: scripts.
   Evidence: this session, `grep -m1 "^set " Scripts/*.sh` — 10 scripts use
   `set -e` only, 11 use `set -eu`, 1 (`test-release-manifest.sh` per
   earlier session note) uses the full strict form. A script with `set -e`
   but no `pipefail` will silently swallow a failure in the left side of a
   pipe (e.g. `cmd_that_fails | tee log`, exactly the pattern used in
   `ci.yml`'s "Release build" step). Impact: a masked failure could let a
   broken release build look green. Risk: medium — real but narrow (only
   matters for piped commands specifically). Effort: S (mechanical
   `set -euo pipefail` swap + spot-check for scripts relying on non-zero
   exit from an intentionally-tolerated command).

5. **GitHub Actions pinned to `@v4` tags, not commit SHAs** — RESOLVED.
   All five actions across the workflows are now SHA-pinned
   (`actions/checkout@3d3c42e5…`, `actions/upload-artifact@043fb46d…`,
   `actions/attest-build-provenance@4d101475…`, `anchore/sbom-action@…`,
   `softprops/action-gh-release@…`).

6. **License text not shipped inside the `.app` bundle itself** — RESOLVED.
   `Scripts/package-local.sh` copies `LICENSE`, `NOTICE` and
   `THIRD_PARTY_NOTICES.md` into `Contents/Resources/` before signing;
   `Scripts/test-dmg-layout.sh` asserts "licence texts sealed inside the
   bundle". They now travel with the app after the dmg/zip is discarded.

7. **Zero SPDX license headers in `Sources/`** — RESOLVED (2026-09-02). The
   two-line `// SPDX-License-Identifier: Apache-2.0` /
   `// SPDX-FileCopyrightText: The CoreTend Authors` header is now on all 54
   `Sources/` and 43 `Tests/` Swift files, matching the shell/Python
   scripts' convention. `Scripts/check-spdx-headers.sh` (in `ci.yml`)
   keeps new files from regressing.

## Low

8. **7 stray `worktree-agent-*` branches** left over from prior sessions —
   category: repository hygiene. Evidence: session-1 finding
   (`REPOSITORY_MAP.md`), not cleaned up in sessions 2 or 3 (out of scope
   — deleting branches is a git-history action, left for a human/explicit
   request). Effort: XS.

9. **Website has zero automated accessibility scan** — category:
   accessibility. Evidence: `WEBSITE_AUDIT.md` this session — lang attrs
   and viewport meta spot-checked by grep, but no axe/Lighthouse run (no
   browser tooling available in this environment). Effort: S once a
   browser/CI job is wired up.

10. **`AppUpdatesView` only deep-links to the App Store's Updates pane,
    does not check for updates itself** — category: architecture (carried
    from session 2 `FEATURE_INVENTORY.md`). Effort: M if real
    self-update-check behavior is wanted; currently honest UI-only.

11. **Model fields computed by an engine but never surfaced in the UI**
    — category: product polish. `periphery` (run 2026-09-02) flags them as
    "assign-only". They are correct, cheap, `Sendable`/`Codable` data — kept
    on purpose — but a "majestic" 1.x should show them:
    - `ScanFinding.category` / `.confidence` — per-finding classification and
      certainty; the Cleanup/Storage review lists neither.
    - `IntegrityCore.QuarantineInfo.originURL` / `.downloadedAt` — download
      referrer + date from the quarantine metadata; Protection shows only
      `sourceURL`.
    - `MCModuleIdentity.color` — the per-module role colour; module headers
      and cards pull only `.icon` from the identity, not the colour.
    - `SafetyLogViewModel.skippedOrErrorCount` — the audit view's subtitle
      shows executed count only; skipped/errored is computed, not shown.
    - `ReleaseInfo.channel` — parsed from `latest.json`; the update check
      compares version only, so it cannot yet gate on release channel.
    Effort: S each; net-new UI + a localized string or two, needs visual QA.

12. **Intentional-library `public` surface flagged as "redundant"** — not
    debt. `periphery` reports ~42 `public` symbols in `DesignSystem`,
    `ScanCore`, `SafetyCore`, `Persistence` as "not used outside the module".
    That is expected: these are deliberately-factored modules whose `public`
    API is the module boundary, and a design-system component vocabulary is
    meant to expose pieces the app has not adopted yet. Left as-is on
    purpose; listed here so a future periphery run has a known baseline.

13. **`dmgbuild` version pin outran the machine's Python** — RESOLVED
    (`6ae2343`, 2026-09-02). `requirements-packaging.txt` pins
    `dmgbuild==1.6.7`, which needs Python ≥ 3.10; a stock macOS `python3` is
    the 3.9 system interpreter, so once the cached `.build/packaging-venv`
    was gone `package-dmg.sh` failed to provision and **the 1.0.0 DMG could
    not be built on this machine**. `package-dmg.sh` now probes
    `python3.13/3.12/3.11/3.10` (`CORETEND_PACKAGING_PYTHON` overrides) and
    fails loudly if none is ≥ 3.10. The exact pin is kept for a reproducible
    `.DS_Store`.

14. **rc.6's DMG background says "Unsigned build"** — RESOLVED for 1.0.0.
    The published `v0.9.1-rc.6` disk image's background artwork reads
    *"Unsigned build — first launch needs System Settings › Privacy &
    Security"*, which is false — rc.6 is Developer ID signed and notarized.
    The current `Resources/Brand/Sources/generate-brand-assets.swift` draws
    *"Local scans · reversible cleanup · nothing leaves your Mac"* instead,
    and the committed `Resources/Brand/Generated/DMG-Background.png` already
    carries the new text, so the 1.0.0 DMG is correct. rc.6 itself is not
    being re-cut.

## Not technical debt (explicitly checked, found clean this session)

- Localization: 327/327 EN keys have an FR counterpart and vice versa,
  zero unused keys (checked via `grep -rlF` against `Sources/CoreTendApp`),
  exactly one non-localized `Text(...)` literal (`"CoreTend"`, the
  product name itself — correct to leave un-translated).
- Distribution checksum/size sync (the session-2 `fix(release)` commit
  `88bbb9a`): re-verified this session, zip/dmg SHA256 and byte sizes in
  `Release/latest.json` match the actual files exactly.
- No trackers/analytics on the website (grep swept for 9 common
  tracker/analytics signatures across all HTML — zero real hits).
