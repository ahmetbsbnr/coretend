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

## Progress log

### Session 2 — `7e2516f` (branch `feat/community-contact-site-v1.1`)

**Done & verified (`python3 Website/build.py` passes):**
- **Phase 8 (download resolution) — partial fix landed.** `vercel.json`
  `/download` no longer hardcodes `v1.0.0`; it 302s to
  `github.com/ahmetbsbnr/coretend/releases/latest`. Survives every release
  with no per-release edit. *Remaining for full Phase 8:* a
  `GET /api/download` Vercel Function that reads
  `Configuration/published-release.json` and 302s straight to the DMG
  (skips the GitHub release page). Blocked only on the `api/` runtime being
  stood up (Phase 10).
- **Phase 27 (footer) — credit line removed.** The
  "Ahmet Basbunar — direction … Claude (Anthropic) — supervised assistant"
  string is gone from `build.py`'s generated footer **and** from
  `index.html` (home). Now `CoreTend — free software for macOS · Apache-2.0`
  (EN/FR). *Remaining for full Phase 27:* add Download / Community /
  Changelog / Contact / Security to `foot-links` — deferred deliberately
  because those routes don't exist yet (adding them now = broken links).
  Do it in the same commit that creates each page.

**Brand audit correction (Phase 1):** the brand foundation is in better
shape than session 1's audit implied. `Website/assets/brand/` already has
vector `favicon.svg`, `mark-light.svg`, `mark-dark.svg` (concentric-arc
CoreTend symbol, teal `#0B6E6C` / `#5FD3C6`), PNG favicons at 16/32/180/192/512,
and `opengraph.png` (1200-wide). `build.py:logo_svg()` emits an **inline
vector** SVG (crisp at any DPI), not an upscaled PNG. Phase 1's real
remaining work is narrower than "recreate the logo": (a) confirm the header
`.wordmark` composition (mark + `<span>CoreTend</span>` text) reads as
crisp — it is vector + web font, so likely fine; (b) add an
`apple-touch-icon` `<link>` if missing; (c) verify `opengraph.png` is
1200×630 exactly and regenerate from `favicon-512` + wordmark if not.
Do **not** trace or redraw the mark — the vector source is authoritative.

### Session 3 — `967aed5` → `0504b57` (P0 complete)

`node --test test/*.test.js` = **55 pass**. `python3 build.py` green, 20
HTML routes, no secret in dist.

**P0-A download + install cleanup — DONE.** `api/download.js` +
`api/_lib/releases.json` resolve `/download` (+ `?channel=stable|beta`) with
graceful fallback; `beta` is `null` until a real artifact exists.
`vercel.json` `/download` is a rewrite now. All SHA-256 / Minisign / spctl /
stapler text removed from `index.html` (#install, hero link, ticker, toast,
FAQ), `build.py` `support_content` (rewritten), and the JSON-LD. The
simulated Gatekeeper dialogs in `#stage` are replaced with a
DMG→Applications→launched composition. `latest.json` + `SHA256SUMS` stay as
unlinked machine-only files.

**P0-B/C/D backend — DONE (LOCAL). EXTERNAL: Postgres + Resend + DNS.**
`Website/api/` Vercel Functions, only prod dep `@vercel/postgres` (lazy):
- `POST /api/contact` — validate → rate-limit (Postgres token bucket, salted
  IP hash) → honeypot → persist → route to human inbox (general→contact@,
  support→support@, bug/impr/feature→feedback@, privacy→privacy@,
  security→security@) → ack the sender iff they gave an email. Mail-fail =
  202 {mailed:false}, never lost.
- `GET /api/community` — approved + publicConsent only; `?type=` `?completed=1`;
  never returns email / notes / un-redacted body.
- `POST /api/community` — always `pending`, nothing public on submit.
- `POST /api/community/review` — private unless `publishConsent===true`
  (never default-checked) and then only after moderation.
- `/api/admin/community` — GET pending + PATCH {moderationStatus,
  publicStatus, publicTitle?, publicBody?}; constant-time Bearer
  `ADMIN_TOKEN`; bare 401.
- `_lib/`: validate (zero-dep, CR/LF-stripping → no header injection),
  store (memory for tests + postgres for prod; only public/admin views
  leave), mail (Resend via one fetch behind an injectable transport;
  `From: CoreTend <noreply@…>`, Reply-To the human inbox; every address
  CRLF/comma-guarded), templates (EN/FR, escaped), ratelimit, respond
  (16 KB cap, safe errors), context.
- `migrations/0001_init.sql` + `scripts/migrate.mjs` (`--dry-run` needs no
  DB). `Website/ENVIRONMENT.md` documents POSTGRES_URL / RESEND_API_KEY /
  ADMIN_TOKEN / RATE_SALT / SITE_ORIGIN (server-side only).

**P0-B/C frontend — DONE.** `/contact` `/fr/contact` `/community`
`/fr/community` (build.py `contact_content` / `community_content`), fetch
forms in `assets/shell/public.js` (`apiForms` + `communityFeed`), styled in
`public.css`. `<noscript>` fallback, hidden honeypot, consent never
pre-checked, "CoreTend never attaches anything from your Mac" stated.

**P0-E — DONE.** Privacy section 02 (app vs Contact/Community transmission,
fields, email, moderation, retention = salted-hash IP only, deletion via
privacy@). New `/security` `/fr/security` (trust guarantees, no crypto
steps, "signed ≠ safe"). New `/changelog` `/fr/changelog` from
`Website/changelog.json` — 1.0.0 dated (real), 1.1.0-beta.1 marked
**unreleased**, no invented date.

**P0-F — DONE.** Public-claim audit: site + portfolio already clean (no
ClamAV / antivirus / telemetry / account / Intel / universal claims; "not
an antivirus" disclaimers present; macOS 14+ correct). CSP audited &
**unchanged** — forms are fetch-based so `form-action 'none'` stays,
`/api/*` is same-origin so `connect-src 'self'` covers it, no wildcard.
In-code security: server validation, HTML-escaping, Postgres rate limit,
honeypot, constant-time admin token, no secret in dist — all covered by
tests.

**Nav / footer — DONE.** Header: Community · Privacy · Support · Contact.
Footer: Download · Community · Changelog · Contact · Privacy · Security ·
Support · Legal · Licenses · Source. AI-credit line gone (session 2).

**Portfolio — no change needed.** `~/Developer/Website/ahmetbsbnr-portfolio`
`components/CoretendPageContent.tsx` / `content.ts` already say "Installation
is reduced to downloading the DMG and launching", "No command or manual
verification is required", "no antivirus feature". No minisign/checksum
walkthrough exists to remove.

### Session 4 — `8392733` → `081fd22` (P1 visuals / demo / nav)

`node --test test/*.test.js` = **66 pass**. `python3 build.py` green, 20
routes, 28 screenshots in dist, no secret, no AI credit.

**Real product visuals — DONE.** Hero `#app` generative simulation removed
(the fake sidebar, JS rows, progress, Cancel/Pause) → a real Dashboard
screenshot in a `.shot--hero` macOS window frame. `Website/assets/app/screens/`
holds 28 webp (7 modules × light/dark × 1600 w + `-sm` 800 w) derived from
`Documentation/VisualAudit/After` via `cwebp`; `Website/SCREENSHOT_GUIDE.md`
documents naming / source / regen / capture params / HUMAN ASSET CAPTURE
items. `#modules` gallery rebuilt as 6 real light/dark `<picture>` figures
(`prefers-color-scheme` source, `srcset` + `sizes`, `width`/`height`,
`loading=lazy` + `decoding=async`; hero is `fetchpriority=high`). Dead
hero-demo JS neutralised (`demo()` early-returns when `#app` absent;
`#scanToggle`/`#scanCancel`/`#tabs` optional-chained).

**Space Lens web demo — DONE.** New `#space-lens` homepage section + rail
entry. `spaceLens()` in the inline script: deterministic 12-node dataset
(3 dirs drillable), states `idle → scanning → complete` via `[data-state]`,
~1.9 s rAF count/bytes animation with staggered bubble emergence,
reduced-motion jumps to the result. SVG size map (largest centred, ring
layout, r ∝ √size, ≤ 12 circles/level) ↔ ordered list, click-select synced
both ways, double-click / Enter drills, breadcrumb + Back + Restart.
Circles are `role=button` + `tabindex` + labelled. No destructive verb in
the section.

**Mobile navigation — DONE (info pages).** `shell()` desktop nav trimmed to
Community + Contact; at ≤ 720 px a `#navToggle` (`aria-expanded` /
`aria-controls`) opens `<nav id="mobile-nav" hidden>` with Community /
Contact / Changelog / Privacy / Security / Support / Download. `public.js`
`mobileNav()`: toggle + focus first link, Escape closes & refocuses toggle,
outside-click closes, ≥ 721 px force-resets. Homepage header was already
mobile-fine (wordmark + locale + theme + Download; section links in `#rail`)
— unchanged.

**Claims 2nd pass — DONE.** The two "CoreTend has no built-in restore
action" statements (EN/FR, Modules note + FAQ) rewritten: keep Put-Back
guidance, name the 1.1 Restore Center. No other stale claims.

**SEO enrichment — DONE.** `page_structured_data()` emits a WebPage +
Home›Page BreadcrumbList `@graph` on every info route (EN+FR); validated
parseable. Landing keeps its `SoftwareApplication` node. One shared
`opengraph.png` used per route (quality over count, per Phase 25).

**A11y — partial (structural).** Fixed: Space Lens SVG `role=img` dropped
(interactive children), full description in `aria-label`; mobile nav ARIA +
keyboard; form fields `aria-invalid`/labels (P0); focus-visible rings on all
new controls; feed status uses text not colour; reduced-motion on the demo +
install stage. **Not done:** a manual screen-reader pass, a measured
contrast audit of every surface, Lighthouse.

### Still open (P1 / P2)

- `#findings` homepage section is still a JS-populated fake app slab
  (smaller offender than the removed hero). Should become a screenshot or be
  cut — its `findings()` JS + `FINDINGS` data + `#tabs` would go with it.
- `#health` gauges and the `#privacy` `#term` terminal are mild
  generative-ish bits — review.
- Manual WCAG-AA screen-reader + contrast audit; responsive walk at 1440/
  1280/1024/768/430/390/360; performance/Lighthouse pass.
- FR screenshot variants (`-fr` captures exist in the source set).
- Interactive DOM tests for `spaceLens()` / `mobileNav()` / `apiForms()` —
  need a jsdom/linkedom devDependency, blocked offline; build-contract
  assertions cover structure. Marked HUMAN VERIFICATION.
- Homepage `#rail` sidenav mobile behaviour not audited.
- Portfolio (`ahmetbsbnr-portfolio`) not re-touched — its CoreTend page
  already reads as a concise gateway with the right copy; the new
  screenshots could refresh its imagery in a later pass.

### Final remote non-human cleanup pass (2026-09-06)

- **`#findings` generative product-window removed** (`9a7a1a4`). It was a fake
  CoreTend window (`.slab`, `#slabPath` fake path, JS-generated rows, animated
  "recoverable bytes") — an app impersonation, against
  `.claude/rules/site-design.md`. Replaced with a plain editorial list
  (`class="facts find-cats"`): Recoverable / Review / Informational /
  Reversible, EN/FR via `data-fr`. Section id + rail link kept.
- **Dead code removed**: `demo()`, `findings()`, `bubblePack()`, `VIEWS`,
  `FIND`, `demoState`/`demoLabel`/`demoTimer`/`demoRAF`, the `#app`/`#side`/
  `#scanToggle`/`#scanCancel`/`#tabs`-keydown handlers, the `coretend-view`
  sessionStorage round-trip; the `.app*` / `.lens*` / `.rows*` / `.slab*` /
  `.tabs*` / `.tag*` / `.pill*` / `.fr*` CSS and `@keyframes rowin/sweepx/
  confirmation-pulse`. Kept `.dots` (terminal) and `.mini` (Space Lens demo).
  Generated JS bundle **48K → 28K**; `index.html` −25 KB.
- **Screenshot manifest**: `Website/screenshots.json` — 44 entries
  (11 modules × en/fr × light/dark). **0 approved** (the 7 real captures are
  1.0-UI; the rest are `source:null`). Schema + validation: `Scripts/site/
  check-screenshots.py` (sanitisation, no OCR) and `Scripts/site/
  export-screenshots.py` (deterministic cwebp; re-run is byte-identical).
  `check-screenshots.py` is now in `check-website.sh`.
- **Tests added** (`npm test` 66 → **91 / 0**): `screenshots.test.js` (10),
  `secret-leak.test.js` (4 — `ADMIN_TOKEN`/`RESEND_API_KEY`/`POSTGRES_URL`
  never in client output or an API response; `checkAdmin` fails closed),
  `csp.test.js` (7 — pins the already-tight vercel.json CSP), plus 4 new
  `build.test.js` assertions for the `#findings` replacement.
- **CSP**: reviewed line-by-line, already correct (no `*`, `script-src
  'self'`, `connect-src 'self'`, `form-action`/`frame-ancestors`/`base-uri`
  `'none'`). **Not changed.**
- **Playwright**: the browser **runs here** (`~/Library/Caches/ms-playwright/
  chromium-1234`). A targeted run confirmed the `#findings` replacement
  renders 4 categories, localizes EN/FR, has no `#app`/`#tabs`/`.slab` in the
  DOM, no overflow, no page errors. `Scripts/site/test-site.mjs` was
  reconciled for the removed demo (4 gates deleted, 5 trimmed). The **full**
  `test-site.mjs` suite still fails on **pre-existing drift unrelated to this
  task** — the "release identity" gate expects a rendered DMG `SHA-256` that
  an earlier *claims* pass removed from the pages (`build.test.js` now forbids
  it). Reconciling that gate is a separate site-QA task.

### Remaining non-human tasks (site branch)

- Reconcile the `test-site.mjs` "release identity" gate (and any sibling
  SHA-256 assertions) with the checksum-free pages; then a full green
  `node Scripts/site/test-site.mjs` run.
- Capture the real 1.1 screenshots for the manifest's `source:null` entries
  and re-review the 1.0-UI ones (`HUMAN ASSET REVIEW REQUIRED`), then
  `Scripts/site/export-screenshots.py` + flip `approved` per human sign-off.
- The manual a11y / responsive / Lighthouse audit still owed from the P1 log.

## Status

**P0 FAIT (local). P1 LOCAL IMPLEMENTATION mostly FAIT** — real product
visuals, the Space Lens demo, mobile nav, claims, and SEO JSON-LD are done
and covered by 66 passing tests; remaining P1 is the manual a11y/responsive/
perf audit + the `#findings` slab + FR image variants.

**EXTERNAL CONFIGURATION REQUIRED** to run the backend in production: Vercel
Postgres store + `npm install` + `node scripts/migrate.mjs`; Resend account
+ verified `ahmetbsbnr.com` + `RESEND_API_KEY`; SPF/DKIM/DMARC; `ADMIN_TOKEN`;
deploy. Until then the API validates/returns cleanly and `node --test`
covers every path with fakes.

The Finder Extension vertical on `feat/finder-extension` (`1ed2efb`) is
separately **FAIT** — do not rework it.
