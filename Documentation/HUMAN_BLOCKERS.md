# Human Blockers

Things that cannot be automated and require a real decision by the
project owner before public release. Nothing below should block the
automatable work in this phase — it's tracked here so it isn't lost.

## RESOLVED / KNOWN

These are no longer open — the values are known and centralized in
`Configuration/PublicIdentity.example.json`, even though the actions
that use them (creating the repo, pushing, deploying) are still open
below.

| Item | Known value |
|---|---|
| GitHub maintainer handle | `ahmetbsbnr` |
| Planned public repository | `ahmetbsbnr/mac-care-local` (`https://github.com/ahmetbsbnr/mac-care-local`) |
| Planned production domain / subdomain | `ahmetbsbnr.com` / `maccare.ahmetbsbnr.com` |

## OPEN

| Blocker | Why it needs a human | Tracked placeholder |
|---|---|---|
| Security contact address/channel | Needs a real, monitored inbox or private reporting tool | `[SECURITY_CONTACT_TO_DEFINE]` (SECURITY.md, CODE_OF_CONDUCT.md) |
| Legal identity (publisher name/address) for legal notice pages | Real personal/legal info must not be invented | Website legal pages, `[LEGAL_NAME_TO_DEFINE]`, `[LEGAL_ADDRESS_TO_DEFINE]` |
| Legal address | Real personal/legal info must not be invented | `[LEGAL_ADDRESS_TO_DEFINE]` |
| Publisher of record | Real legal/business info must not be invented | `[PUBLISHER_OF_RECORD_TO_DEFINE]` (`Configuration/PublicIdentity.example.json`) |
| Approval to actually create the public GitHub repository | Irreversible, deliberate act | N/A — explicitly not done this phase |
| Approval to push to the public repository | Irreversible, deliberate act | N/A — explicitly not done this phase |
| Approval to deploy the website | Irreversible, deliberate act | N/A — explicitly not done this phase |
| Final screenshots for the website/App listing | Requires a real display/session, not available in this sandbox | `Website/README.md` dev placeholder box |
| Multi-Mac / multi-macOS-version testing | Only one physical Mac (macOS 26.5.1, arm64) is available in this environment | `Documentation/API_AVAILABILITY_AUDIT.md` |
| First public GitHub Release (signing/notarization) | Requires Apple Developer ID (out of scope this phase) | Documentation/PUBLIC_RELEASE_READINESS.md |
| Publication of the first public release | Deliberate act, requires the repo to exist first | `Release/latest.json` (no downloadURL yet) |

All placeholders above are also tracked centrally in
Documentation/PUBLICATION_PLACEHOLDERS.md so a pre-publication check can
grep for them.

## New placeholder usages added this session (same tokens, new files)

`[MAINTAINER_HANDLE_TO_DEFINE]` now also appears in `.github/CODEOWNERS`
(four owner lines) and `.github/ISSUE_TEMPLATE/config.yml`/
`GOVERNANCE.md`. `[REPO_URL_TO_DEFINE]` appears in
`.github/ISSUE_TEMPLATE/config.yml`'s contact links. No new placeholder
tokens were invented — reused exactly what's already tracked above.

## Website: same tokens, new files (this session)

`Website/generate.py` (source of truth rendering `Website/en|fr/*.html`)
uses `[LEGAL_NAME_TO_DEFINE]`, `[LEGAL_ADDRESS_TO_DEFINE]`,
`[SECURITY_CONTACT_TO_DEFINE]`, `[DOMAIN_TO_DEFINE]` (also standing in for
hosting, since no separate token existed for that) and
`[REPO_URL_TO_DEFINE]` on the Legal, Privacy, and Documentation pages. No
new placeholder tokens were invented. `Scripts/check-placeholders.sh`
already catches all of them (116 occurrences currently, expected
pre-release). The homepage screenshot uses a clearly labeled dev
placeholder box instead of a real screenshot — tracked in
`Website/README.md`, not a bracket token so `check-placeholders.sh` won't
catch it; must be manually replaced before any production deploy.

## This session: distribution-gate progress (compat audit, ZIP, DMG, checksums, manifest, release notes, CI draft workflow, install guide)

No new placeholder tokens were invented. Maintainer handle, planned repo,
and planned domain — already known values from
`Configuration/PublicIdentity.example.json` — are now marked RESOLVED
above since they're facts, not blockers; the *actions* that use them
(create repo, push, deploy) remain OPEN and unperformed this session, per
the safety rules for this work.

## Open item: Dependabot Swift Package Manager ecosystem support

`.github/dependabot.yml` only enables the `github-actions` ecosystem.
Whether GitHub Dependabot supports a Swift Package Manager ecosystem
entry was not verified this session (no network check performed); rather
than guess at a config key that might silently no-op, this was left as a
documented follow-up in the file itself. Not currently blocking — the
project has zero external SPM dependencies (see
Documentation/DEPENDENCIES.md) — but should be revisited before or when a
real dependency is added.

## v0.7.0 gate session

Version bumped to 0.7.0 "Public Distribution" after an independent
re-verification of all 24 gate criteria (not a re-read of prior
session claims) — see CHANGELOG.md and PUBLIC_RELEASE_READINESS.md.
No blockers were resolved by this session; `Documentation/
FIRST_PUBLIC_RELEASE_CHECKLIST.md` now lists the ordered human-only
steps (identity, security contact, repo creation, push, tag, workflow
run, prerelease, site deploy, announce) still required before any
public release, none of which were performed.
