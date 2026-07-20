# Technical Debt — consolidated, sessions 1-3

Real gaps only, each with evidence. Severity: critical/high/medium/low.
Effort: XS/S/M/L/XL (relative, no hours).

## Critical

None found across three audit sessions that block correctness or safety
of the core scan/delete/quarantine paths — the `PathValidator` protections,
argument-array-only `Process()` call, and 86/86 passing tests hold up
(see `SECURITY_AUDIT_CURRENT.md`).

## High

1. **LICENSE file references two non-existent paths** — category: documentation/legal.
   Evidence: `LEGAL_AND_LICENSE_STATUS.md` session-2 finding, `LICENSE` cites
   `Documentation/LICENSING.md` (doesn't exist) and `THIRD_PARTY_NOTICES.md`
   at repo root (real file is `Documentation/THIRD_PARTY.md`). Impact: a
   reader following the LICENSE's own pointers hits dead links. Risk: low
   functional risk, real trust/professionalism risk for an OSS repo.
   Effort: XS. No dependencies. Recommended: fix before any public tag.

2. **Website legal identity placeholders unresolved** — category: distribution/legal.
   Evidence: `WEBSITE_AUDIT.md` this session — `[LEGAL_NAME_TO_DEFINE]`,
   `[LEGAL_ADDRESS_TO_DEFINE]`, `[SECURITY_CONTACT_TO_DEFINE]`,
   `[DOMAIN_TO_DEFINE]` still present in `legal.html`/`privacy.html`/
   `security.html` (both locales). Impact: site cannot go live truthfully
   with real legal/contact info missing. Risk: legal exposure if published
   as-is claiming to be final. Effort: XS (once the human decides the
   values) — BLOCKED_HUMAN, not a coding task.

3. **Unsigned, unnotarized distribution** — category: distribution.
   Evidence: `DISTRIBUTION_AUDIT.md` this session, `latest.json`
   `signed:false, notarized:false`. Impact: Gatekeeper blocks first launch
   for every non-developer user. Effort: BLOCKED_HUMAN (needs an Apple
   Developer account/cert, not code).

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

5. **GitHub Actions pinned to `@v4` tags, not commit SHAs** — category: CI.
   Evidence: this session, all three workflows use
   `actions/checkout@v4`, `actions/upload-artifact@v4`. Tag pinning is
   standard practice and is not itself a defect, but SHA-pinning is the
   stricter supply-chain posture GitHub/OSSF recommend for public repos.
   Impact: low (both actions are first-party GitHub actions, not
   third-party). Effort: XS if desired, optional hardening not a blocker.

6. **License text not shipped inside the `.app` bundle itself** — category: distribution.
   Evidence: `DISTRIBUTION_AUDIT.md` this session — `LICENSE`/`NOTICE`/
   `THIRD_PARTY_NOTICES.md` ship at the zip/dmg root beside the `.app`, not
   inside `Contents/Resources`. Once a user drags the app to
   `/Applications` and discards the zip/dmg, the license text no longer
   travels with the app. Impact: low (common practice, not required by
   Apache-2.0/CC-BY-4.0), but a "Licenses" menu item or bundled copy would
   be friendlier. Effort: S.

7. **Zero SPDX license headers in `Sources/`** — category: legal (carried
   from session 2, re-confirmed not newly checked this session). Effort: M
   (mechanical but touches every file) if the project wants per-file SPDX
   headers; not legally required given the root `LICENSE`.

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

## Not technical debt (explicitly checked, found clean this session)

- Localization: 327/327 EN keys have an FR counterpart and vice versa,
  zero unused keys (checked via `grep -rlF` against `Sources/MacCareApp`),
  exactly one non-localized `Text(...)` literal (`"MacCare Local"`, the
  product name itself — correct to leave un-translated).
- Distribution checksum/size sync (the session-2 `fix(release)` commit
  `88bbb9a`): re-verified this session, zip/dmg SHA256 and byte sizes in
  `Release/latest.json` match the actual files exactly.
- No trackers/analytics on the website (grep swept for 9 common
  tracker/analytics signatures across all HTML — zero real hits).
