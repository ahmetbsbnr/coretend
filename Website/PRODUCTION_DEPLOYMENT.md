<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# CoreTend website — production deployment runbook

Ordered steps to take the `feat/community-contact-site-v1.1` work live on
Vercel (project `coretend`, `prj_hwACffIdxpNjzM0QTa1IZy8cX4XH`). Every step
that touches a provider console is marked **[EXTERNAL — unverified here]**.

Env var contract: `Website/ENVIRONMENT.md`. Architecture + decisions:
`Website/COMMUNITY_CONTACT_HANDOFF.md`. Do not put any secret in a committed
file; there is no `.env` in the repo by design.

## Pre-deploy (local, repeatable)

```
cd Website
npm test                       # API suite — expect 66/0, no env vars needed
node scripts/migrate.mjs --dry-run
python3 build.py --output /tmp/site-check     # static build must succeed
cd .. && bash Scripts/check-website.sh        # design tokens, first-paint,
                                              # retired-pages, e2e (needs a
                                              # browser for test-site.mjs)
```

`check-website.sh`'s `Scripts/site/test-site.mjs` is a Playwright end-to-end
crawl; run it where a headless Chromium is available (CI) — it is not part of
the static/API contract.

## 1. Database — Vercel Postgres (Neon) **[EXTERNAL — unverified here]**

1. Vercel → Storage → create a Postgres store; link it to project `coretend`.
   This auto-populates `POSTGRES_URL` in the project's env.
2. Run the migration against it:
   ```
   POSTGRES_URL="<from Vercel>" node Website/scripts/migrate.mjs
   ```
   Only migration on disk: `migrations/0001_init.sql`.

## 2. Environment variables — Vercel → Settings → Environment Variables **[EXTERNAL]**

| Var | Source | Notes |
|---|---|---|
| `POSTGRES_URL` | auto from step 1 | required for the API to persist |
| `RESEND_API_KEY` | Resend, after domain verification (step 3) | if unset, the API still saves and returns `202 {mailed:false}` — it never 500s |
| `ADMIN_TOKEN` | `openssl rand -hex 32` | gates `POST /api/admin/community` via `Authorization: Bearer` |
| `SITE_ORIGIN` | `https://coretend.ahmetbsbnr.com` | canonical origin for email links; has a safe default |
| `RATE_SALT` | any random string (optional) | only changes rate-limit bucket keys |

Set for **Production** (and Preview if you want previews to work). Never
client-side, never in generated JS.

## 3. Resend — sending domain `ahmetbsbnr.com` **[EXTERNAL — unverified here]**

Add the domain in Resend, then publish the DNS records **Resend generates**
at the `ahmetbsbnr.com` registrar. Do not invent record values — copy them
from the Resend dashboard. Expected record types:

- **SPF** — a `TXT` at the sending subdomain including Resend's `include:`.
- **DKIM** — the `CNAME` (or `TXT`) records Resend shows (usually 3).
- **DMARC** — a `TXT` at `_dmarc.ahmetbsbnr.com`, e.g.
  `v=DMARC1; p=quarantine; rua=mailto:dmarc@ahmetbsbnr.com` (policy is your
  call; start at `p=none` to observe, tighten later).
- **MX** — only if you want to *receive* mail at these addresses; transactional
  send does not need inbound MX.

Wait for Resend to show the domain **Verified** before creating the API key.

### Mail identities

| Address | Use |
|---|---|
| `contact@ahmetbsbnr.com` | Contact form routing target (human-read) |
| `support@ahmetbsbnr.com` | support requests |
| `feedback@ahmetbsbnr.com` | product feedback |
| `community@ahmetbsbnr.com` | Community submissions / moderation notices |
| `security@ahmetbsbnr.com` | already the security contact (GitHub PVR is primary) |
| `privacy@ahmetbsbnr.com` | privacy requests |
| `noreply@ahmetbsbnr.com` | **transactional only** — from-address for automated acknowledgements; never monitored, never used for human correspondence |

## 4. Deploy

```
cd Website
vercel deploy --prod            # framework: null; api/ is picked up as Functions
```

Confirm the CSP still ships as configured in `vercel.json`
(`form-action` restricted to `'self'`, `connect-src 'self'`, no wildcard
`script-src`).

## 5. Post-deploy smoke test **[EXTERNAL — do after deploy]**

1. `/download` and `/download?channel=stable` → 302 to the stable v1.0.0 DMG.
   `/download?channel=beta` → 302 to the published
   `CoreTend-1.1.0-beta.1-arm64.dmg` GitHub asset (beta channel wired
   2026-09-06 in `api/_lib/releases.json`).
2. Submit a **private** Contact message → `202`; it appears in the DB; if
   `RESEND_API_KEY` is set, the routing email arrives at `contact@`.
3. Submit a **Community** idea with `publicConsent:false` → stored `pending`,
   not on the public feed; email not exposed.
4. `POST /api/admin/community` with the `ADMIN_TOKEN` → approve it → it
   appears on the public `/community` feed; the submitter's email is still
   private.
5. Reject flow: reject a pending item → it never appears publicly.
6. Review-with-publication: a review with `publishConsent:true` publishes;
   `publishConsent` absent/false does not.
7. Rate limit: rapid repeat submissions from one IP get `429`.
8. Honeypot: a submission with any content in `company`/`website`/`hp` is
   silently dropped.
9. Email delivery: check Resend logs show `delivered`, not `bounced`.

## 6. After the beta DMG is published

- **DONE 2026-09-06** — `api/_lib/releases.json` `beta` now points at the
  published `v1.1.0-beta.1` prerelease
  (`https://github.com/ahmetbsbnr/coretend/releases/download/v1.1.0-beta.1/CoreTend-1.1.0-beta.1-arm64.dmg`).
  Repeat this step (bump `version`/`tag`/`dmgURL`/`releaseURL`, never a
  placeholder) for each future `1.1.0-beta.N`.
- The `1.1.0-beta.1` entry in `changelog.json` already exists as
  `status: "unreleased"`, `date: null` — flip `status` to `"released"` and
  set the real `date` **only after** the GitHub release is public.
- Refresh screenshots per `Website/SCREENSHOT_GUIDE.md` (see the app repo's
  `Documentation/RELEASE_v1.1.0-beta.1.md` capture checklist); replace any
  v1.0 imagery. All captures: real app, synthetic/demo data, no private
  paths, EN+FR, light+dark, `HUMAN ASSET REVIEW REQUIRED` before publish.
- Do not add SHA-256 / Minisign instructions to the normal user download
  path (beta artifact policy).

## Not in this runbook

- Portfolio case-study sync — separate repo `ahmetbsbnr-portfolio`, its own
  `feat/coretend-card-v1.1` branch, done only when the site links are final.
- The `#findings` interactive product-preview section on the homepage renders
  synthetic "example findings" — flagged against `.claude/rules/site-design.md`
  ("no generative product UI"). It is explicitly labelled "example /
  exemple"; deciding whether to replace it with a real screenshot is a
  website-QA design call, out of scope for a release-prep pass.
