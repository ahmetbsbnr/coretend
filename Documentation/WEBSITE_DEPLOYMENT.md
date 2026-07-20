# Website Deployment

Status: **not deployed.** No production URL exists, no hosting account has
been provisioned by this session, no deploy has been triggered. This
documents the process for later, once a human makes that deliberate
decision.

## Why nothing was deployed this session

Per repo-wide constraint: no public push, no production deploy, ever, from
an automated session. This applies to the website exactly as it applies to
the app repository.

## Candidate hosting

Any static host works — the site is plain HTML/CSS with zero server-side
requirements (e.g. Vercel, Netlify, GitHub Pages, or a plain object-storage
bucket with a CDN in front). Vercel MCP tooling is available in this
environment (`mcp__plugin_vercel_vercel__*`) and would be a reasonable
choice given it's already integrated, but no project has been created and
no deploy has been triggered — that is a human decision, not made here.

## Pre-deploy checklist (for whoever deploys)

1. Run `Scripts/check-placeholders.sh` — must show 0 remaining tokens in
   `Website/` before this site is genuinely production-ready (see
   `Website/README.md` for the current placeholder inventory: legal name,
   address, domain, security contact, repo URL, screenshot placeholder).
2. Replace the homepage `.screenshot-placeholder` box with a real
   screenshot.
3. Confirm `python3 Website/generate.py` output is current (no
   uncommitted content-table changes not yet rendered).
4. Configure the HTTP security headers listed in `WEBSITE_SECURITY.md` at
   the hosting layer.
5. Confirm zero tracking is configured at the host level too (no
   host-provided analytics add-on enabled).
6. Point `[DOMAIN_TO_DEFINE]` at the real domain once registered, and
   update the legal/privacy pages accordingly.

## Build/deploy commands

Build: `python3 Website/generate.py` (see `WEBSITE_ARCHITECTURE.md`).
Deploy command depends on the host chosen at that time — not decided here.
