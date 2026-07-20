# Human Blockers

Things that cannot be automated and require a real decision by the
project owner before public release. Nothing below should block the
automatable work in this phase — it's tracked here so it isn't lost.

| Blocker | Why it needs a human | Tracked placeholder |
|---|---|---|
| Exact GitHub maintainer handle for CODEOWNERS | Requires a real GitHub account decision | see `.github/CODEOWNERS` |
| Final public repository URL | Not yet decided/created | referenced as `[REPO_URL_TO_DEFINE]` in docs |
| Security contact address/channel | Needs a real, monitored inbox or private reporting tool | `[SECURITY_CONTACT_TO_DEFINE]` (SECURITY.md, CODE_OF_CONDUCT.md) |
| Legal identity (publisher name/address) for legal notice pages | Real personal/legal info must not be invented | Website legal pages, `[LEGAL_NAME_TO_DEFINE]`, `[LEGAL_ADDRESS_TO_DEFINE]` |
| Final production domain | Not registered/decided | Website config, `[DOMAIN_TO_DEFINE]` |
| Decision to actually make the repo public | Irreversible, deliberate act | N/A — explicitly not done this phase |
| First public GitHub Release (signing/notarization) | Requires Apple Developer ID (out of scope this phase) | Documentation/PUBLIC_RELEASE_READINESS.md |
| Production deploy of the website | Deliberate act, out of scope this phase | Documentation/WEBSITE_DEPLOYMENT.md |

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

## Open item: Dependabot Swift Package Manager ecosystem support

`.github/dependabot.yml` only enables the `github-actions` ecosystem.
Whether GitHub Dependabot supports a Swift Package Manager ecosystem
entry was not verified this session (no network check performed); rather
than guess at a config key that might silently no-op, this was left as a
documented follow-up in the file itself. Not currently blocking — the
project has zero external SPM dependencies (see
Documentation/DEPENDENCIES.md) — but should be revisited before or when a
real dependency is added.
