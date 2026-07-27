# Website Deployment

## Production deployment — verified 2026-07-27

The static `Website/` directory is deployed to Vercel project
`ahmets-projects-ed32c752/coretend` (`prj_hwACffIdxpNjzM0QTa1IZy8cX4XH`).
The verified production deployment is
`https://coretend-6gh4uz2bc-ahmets-projects-ed32c752.vercel.app`
(`dpl_GcQWq468fFGa6zcaLWLx1tinVhGg`), served publicly as
`https://coretend.ahmetbsbnr.com`.

Build and deploy remain:

```sh
python3 Website/generate.py
bash Scripts/check-website.sh
bash Scripts/check-placeholders.sh
bash Scripts/check-private-data.sh
cd Website
vercel deploy --prod --yes
```

DNS uses flattened A records `64.29.17.1` and `216.198.79.65` (TTL 1800);
there is no AAAA or CNAME. HTTP redirects to HTTPS with 308. TLS uses a
Let's Encrypt certificate covering `*.ahmetbsbnr.com`, valid from
2026-07-16 through 2026-10-14. Production indexing is enabled and
`robots.txt` references `https://coretend.ahmetbsbnr.com/sitemap.xml`.

The public download page links the GitHub prerelease and all four assets.
Downloaded ZIP and DMG hashes match `Release/SHA256SUMS`; ZIP, DMG and
`latest.json` integrity checks pass. Post-deployment gate:
**55 PASS / 0 FAIL / 2 NOT_APPLICABLE / 0 HUMAN_ACTION_REQUIRED**.

An empty Vercel project named `app` was accidentally created during an
interrupted root-directory upload. It has no deployments and was not deleted
without explicit authorization.

The predeployment instructions below are retained as historical context and
are superseded by this verified state.

Status: **not deployed.** No production URL exists and no deploy has been
triggered. The configuration is now prepared and verified locally, so the
remaining step is a single deliberate human decision.

The Vercel CLI is authenticated in this environment (`vercel whoami` →
`ahmetbsbnr`). No Vercel project has been created, no domain has been added,
and no DNS record has been touched.

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
6. Point `coretend.ahmetbsbnr.com` at the real domain once registered, and
   update the legal/privacy pages accordingly.

## Build/deploy commands

Build: `python3 Website/generate.py` (see `WEBSITE_ARCHITECTURE.md`). This also
generates `Website/vercel.json`, `Website/robots.txt` and
`Website/sitemap.xml`. None of them is hand-edited.

`Website/vercel.json` carries the headers from `WEBSITE_SECURITY.md`:
Content-Security-Policy, Referrer-Policy, X-Content-Type-Options,
X-Frame-Options, Permissions-Policy, Strict-Transport-Security, and the two
Cross-Origin-* headers. The CSP is strict — `script-src 'none'`,
`style-src 'self'` with no `'unsafe-inline'` — which the site earns by having
no JavaScript, no external origin and no inline style attributes.

### The exact deploy sequence

Run from the repository root. Everything before the last two commands is
non-destructive and reversible.

```sh
# 1. Regenerate and verify locally.
python3 Website/generate.py
bash Scripts/check-website.sh
bash Scripts/check-placeholders.sh          # must report 0

# 2. Preview deploy (creates the project on first run; not production).
cd Website && vercel deploy

# 3. Verify the preview URL before promoting it.
curl -sI <preview-url>/en/index.html | grep -i 'content-security-policy\|strict-transport'

# 4. Promote to production.
vercel deploy --prod

# 5. Attach the domain.
vercel domains add coretend.ahmetbsbnr.com
```

### The single human action that cannot be automated here

**The DNS record.** `coretend.ahmetbsbnr.com` is a subdomain of a domain whose
registrar credentials are not present in this environment. After step 5 Vercel
prints the record it wants; it must be created at the registrar for
`ahmetbsbnr.com`, typically:

```
CNAME   coretend   cname.vercel-dns.com.
```

### After DNS propagates

Do not mark DNS or TLS done before these return the expected values:

```sh
dig +short coretend.ahmetbsbnr.com
curl -sI https://coretend.ahmetbsbnr.com/en/index.html
curl -sI http://coretend.ahmetbsbnr.com/         # expect a redirect to HTTPS
openssl s_client -connect coretend.ahmetbsbnr.com:443 -servername coretend.ahmetbsbnr.com </dev/null 2>/dev/null | openssl x509 -noout -dates -subject
```

Then, and only then, set `siteIndexable` to `true` in
`Configuration/PublicIdentity.example.json` and regenerate. That one flag moves
the per-page robots meta, `robots.txt` and the `X-Robots-Tag` header together —
until the site is reachable they all say noindex, because indexing a page
nobody can load is a promise nobody can keep.
