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
