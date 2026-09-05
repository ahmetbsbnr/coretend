<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# CoreTend website v1.1 — Community / Contact / release-UX handoff

Durable handoff per the assignment's §66 (Context Limit). This session
delivered the **repository audit + architecture decisions + branch setup**;
implementation of the 60-point mandate is a multi-session program that
starts from here. Nothing below is scaffolded-and-called-done.

## Git

- Repo: `~/Developer/Website/products/coretend/app` (the CoreTend app repo —
  the public site lives inside it at `Website/`, it is **not** a separate
  repo).
- Branch: `feat/community-contact-site-v1.1` (created from
  `feat/finder-extension` HEAD `1ed2efb`, which carries every prior app
  vertical; `Website/` itself is untouched by that stack).
- Portfolio: separate repo `~/Developer/Website/ahmetbsbnr-portfolio`, on
  `main` @ `e60b966`, clean. Touch it on its own `feat/coretend-card-v1.1`
  branch only when the site links are final.
- Nothing pushed. Nothing merged. `main` untouched.
- **Also on branch `feat/finder-extension` (FAIT, checkpointed):** the
  read-only Finder Sync extension vertical — 727 Swift tests green, Xcode
  build green, repository-doctor green. That work is complete and
  independent of this assignment; see `Documentation/AGENT_HANDOFF.md`.

## Current website architecture (audited)

- **Static only.** `Website/build.py` (Python) transforms the gold-master
  `Website/index.html` (1867 lines, EN/FR via `data-fr` attributes + JS
  toggle) into `dist/` routes: `/`, `/en`, `/fr`, `/privacy`, `/support`,
  `/legal`, `/licenses`. Deployed on Vercel (project `coretend`,
  `prj_hwACffIdxpNjzM0QTa1IZy8cX4XH`).
- **No backend, no API, no database.** `vercel.json` CSP is
  `default-src 'self'; script-src 'self'; connect-src 'self';
  form-action 'none'`. A Contact form and Community system therefore need
  **new infrastructure**, not just markup.
- `assets/` holds `app/` screenshots (png/webp), `brand/` (has `*.svg` +
  `favicon-v2-*.png` + `opengraph.png`), `demos/` (mp4/webm/vtt/webp),
  `design-system/tokens/*.css` + `*.json`. A vendored, pinned design-system
  copy exists at `Website/design-system/` (source of truth is the app's
  `app/DESIGN.md` / `app/Website/design-system/`).
- Release-UX clutter to remove: `index.html` `#install` section renders a
  `<code id="sha">@@CORETEND_DMG_SHA256@@</code>` block + copy button;
  `build.py` injects the DMG SHA-256. `/download` in `vercel.json` is a
  `302` **hardcoded to `v1.0.0`** —
  `github.com/ahmetbsbnr/coretend/releases/download/v1.0.0/CoreTend-1.0.0-arm64.dmg`
  — this breaks on the next release and must resolve dynamically.
- `robots.txt`, `sitemap.xml` exist; `build.py` writes per-route
  canonical/hreflang/OpenGraph metadata (`route_for`, `alternate_en/fr`).
- Footer (`build.py` ~line 511) lists privacy/support/legal/licenses only —
  no Download / Community / Changelog / Contact yet.

## Architecture decisions (made this session, ready to implement)

1. **Backend host = Vercel Functions** (same project, `Website/api/*.ts`),
   because the site already deploys on Vercel and the assignment says
   "smallest reliable solution compatible with existing infrastructure".
   No separate service. `framework: null` stays; add an `api/` dir and
   Vercel picks it up. CSP must gain `connect-src 'self'` already covers
   same-origin `/api/*`; **`form-action` must change from `'none'` to
   `'self'`** (or keep `'none'` and submit via `fetch`, which is cleaner and
   keeps the stricter directive — recommended: JS `fetch`, no native form
   POST).
2. **Database = Vercel Postgres** (Neon under the hood) via
   `@vercel/postgres`. One schema, two tables to start: `contact_messages`,
   `community_submissions` (+ `community_reviews`). Migrations as plain
   `.sql` files run by a `scripts/migrate.mjs`. Rationale: managed, free
   tier, first-party to the deploy target, SQL (matches the app's own
   SQLite/`Persistence` mental model).
3. **Transactional mail = Resend** (`resend` npm, single `RESEND_API_KEY`
   env var, EN/FR React-free HTML templates). Alternative kept in reserve:
   Postmark. Both give simple API-key auth, sandbox mode for tests, and
   straightforward SPF/DKIM. **Not** self-hosted SMTP.
4. **Moderation admin = a single bearer token** (`ADMIN_TOKEN` env) gating
   `/api/admin/*`, not a user system. The assignment says don't build an
   auth system if a secure boundary suffices.
5. **One API for site + future macOS app.** Public endpoints:
   `POST /api/contact`, `POST /api/community`, `GET /api/community` (approved
   only), `POST /api/community/:id/review`. Admin: `GET/PATCH
   /api/admin/community`. The macOS app will call the same public POSTs with
   no secret.
6. **Anti-abuse:** server-side zod validation, per-IP token-bucket rate
   limit in Postgres (no third-party), honeypot field, 8 KB body cap, no
   attachments in beta.1 (diagnostics schema reserved but disabled). CSRF
   is moot for token-less JSON `fetch` from same origin + no cookies.
7. **No analytics.** No GA. Operational logging = Vercel's own function
   logs, no PII beyond a truncated IP hash for rate-limiting (documented,
   30-day expiry row).
8. **Voting:** OUT for beta.1 (can't do it non-abusably without more than
   this vertical allows). Ship submission + moderation + public status
   taxonomy; document voting for beta.2.

## Ordered next actions (start of implementation)

1. **Brand/logo** — extract the authoritative vector from
   `Website/assets/brand/*.svg` (audit which is the wordmark vs symbol);
   produce crisp `logo-wordmark.svg`, `logo-symbol.svg`, light/dark
   variants; regenerate `favicon.svg` + `apple-touch-icon.png` (180²) +
   `opengraph.png` (1200×630) from vector, not upscaled PNG. Wire into
   `build.py` `logo_svg()` (currently inline).
2. **IA / header / footer** — rebuild nav to Overview · Features · Smart
   Scan · Space Lens · Privacy · Community · Download · FAQ · Contact;
   footer to Download · Community · Changelog · Contact · Privacy ·
   Security · GitHub. Remove the AI-assistant credit line from the global
   footer. Add `build.py` route stubs: `community`, `contact`, `security`,
   `changelog`, `faq`, `features`, `smart-scan`, `space-lens` (EN + FR).
3. **Download/install simplification** — delete the `#sha` code block +
   copy button + `@@CORETEND_DMG_SHA256@@` injection; rewrite `#install`
   to Download → open DMG → drag to Applications → launch; add a
   `GET /api/download` (or a Vercel rewrite) that reads
   `Configuration/published-release.json` (or GitHub's
   `releases/latest`) and 302s to the current DMG — kill the hardcoded
   `v1.0.0` redirect. Keep `latest.json` served for the updater but off the
   user path.
4. **Screenshot/demo system** — standardise `assets/app/` (Retina, fixed
   window padding, dark, EN/FR, webp) using the app's existing isolated
   capture harness + synthetic demo dataset (see app
   `Documentation/DEMO_DATASET.md`); document the workflow.
5. **Space Lens interactive demo** — deterministic synthetic bubble data,
   states before/scanning/complete/selected, list sync, restart,
   `prefers-reduced-motion` parity. Lightweight vanilla JS/CSS, no real
   scanner.
6. **Contact** — `api/contact.ts` (zod + rate limit + honeypot + Resend
   routing table) + `contact.html` route + EN/FR + client `fetch` + success
   / failure states + Postgres persist + acknowledgement email.
7. **Email infra** — Resend domain setup; emit the exact SPF/DKIM/DMARC/MX
   records as **EXTERNAL CONFIGURATION REQUIRED** (cannot verify without
   DNS + provider access).
8. **Community** — schema + `api/community*` + `/community` list & submit +
   moderation admin + public status taxonomy (under review / planned / in
   progress / completed / declined) + reviews with explicit publish
   consent. No voting.
9. **Security / Privacy / Changelog pages** — new `/security`, rewrite
   `/privacy` to split app-local behaviour vs Contact/Community
   transmission, `/changelog` fed from a maintainable source with a
   `1.1.0-beta.1` entry structure (no invented dates).
10. **SEO** — sitemap/robots/canonical/hreflang for the new routes,
    `SoftwareApplication` structured data (accurate: macOS 14+, Apple
    Silicon, free, no account), OG images per route.
11. **Portfolio** — trim the CoreTend card to a gateway (what it does,
    screenshots, no-telemetry, current version, Download + Visit-site);
    remove checksum/Minisign walkthrough.
12. **Quality passes** — responsive compositions, WCAG AA, performance
    (webp, lazy, no unbounded canvas), EN/FR parity audit, frontend tests
    (navigation, locale, download CTA, Contact validation, Community
    visibility) + backend tests (schema, routing, rate limit, honeypot,
    moderation transitions, consent, no secret leakage) + mail tests
    (injected transport, sender/reply-to/locale, header-injection).
13. **Deploy validation** — env var doc, migration on deploy, staging
    check; do not claim production deploy unless actually run.

## EXTERNAL CONFIGURATION REQUIRED (cannot be done from here)

- Vercel: create Postgres store on project `coretend`; set env vars
  `RESEND_API_KEY`, `ADMIN_TOKEN`, `POSTGRES_URL` (auto), `SITE_ORIGIN`.
- Resend (or Postmark): account, verified sending domain `ahmetbsbnr.com`,
  API key.
- DNS on `ahmetbsbnr.com`: SPF (`include:` the chosen provider), DKIM
  CNAME(s) from the provider, DMARC `_dmarc` TXT (`p=none` → `quarantine`),
  MX only if inbound is wanted (aliases can forward instead). Exact records
  depend on the provider chosen at implementation time — emit them then.
- Mailbox/alias routing for `contact@ support@ feedback@ community@
  security@ privacy@ noreply@ ahmetbsbnr.com`.
- GitHub bot token — only if approved-Community → GitHub-issue sync is
  enabled (optional, not beta.1-blocking).

## Status

**PARTIAL — implementation not started.** Audit complete, branch created,
architecture decided, next actions ordered. The Finder Extension vertical on
`feat/finder-extension` is separately **FAIT**.
