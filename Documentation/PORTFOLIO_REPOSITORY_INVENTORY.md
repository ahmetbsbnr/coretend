# Portfolio Repository Inventory

**Selection: CONFIRMED (not INCONCLUSIVE)** — see evidence chain below.
Nothing in this repository was modified during this inventory pass.

## How it was found

`~/Documents` itself has no other `.git` repo besides `MACCLEAN`. A wider
read-only search found two stale Claude session-metadata folders
referencing a since-removed path
(`~/Desktop/Stage/ahmetbsbnrportfolio`, no longer present on disk), which
pointed toward the phase brief's historical-name hint
("professionnel-portfolio-stage-2026"). Searching by that literal name
found it nested under a personal file-organization tree:

```
~/Documents/MAC_ORGANISE/00_DOCUMENTS_EXISTANTS/01_PROJETS/01_PROJETS_ACTIFS/professionnel-portfolio-stage-2026
```

Two other, older candidates exist in the same parent folder
(`personnel-portfolio-vercel-2025`, `personnel-portfolio-nextjs-2025`) —
both are minimal, untouched since **2025-05-02**, one has no `.git` at
all, the other has a literal broken folder named `{app,public,components}`
(an incomplete scaffold command artifact). Neither is a real candidate;
`professionnel-portfolio-stage-2026` is the only one with a real, active
Git history, a live production deployment, and a domain
(`ahmetbsbnr.com`) that matches `Configuration/PublicIdentity.example.json`'s
`developerDomain` field exactly — an independent cross-confirmation this
is the same person's live, current portfolio.

## Repository facts

| Field | Value |
|---|---|
| Path | `~/Documents/MAC_ORGANISE/00_DOCUMENTS_EXISTANTS/01_PROJETS/01_PROJETS_ACTIFS/professionnel-portfolio-stage-2026` |
| Git branch | `main` |
| Git HEAD | `e6db86dbebbce8b16088680d8894acd015b0e77c` |
| Git status | clean (0 changed files) |
| Remote | `origin` → `https://github.com/ahmetbsbnr/ahmetbsbnrportfolio.git` (matches MacCare Local's own `maintainerGitHub: "ahmetbsbnr"`) |
| Recent history | Active — top commits are 2026-07-16 fixes (404/hydration, OpenGraph metadataBase, production audit) |
| Package name | `portfolio-ahmet-basbunar`, version 1.0.0 |
| Framework | Next.js 15 (App Router, `app/(en)` + `app/(fr)` locale groups), React 18, TypeScript |
| Styling | Tailwind CSS 3, CSS custom-property color tokens (`--paper`, `--card`, `--ink`, `--sub`, `--dim`, `--line`, `--line-strong`, `--cobalt`, `--cobalt-deep`, `--ok`, `--err`) |
| Animation | GSAP 3 + `@gsap/react` |
| Icons | `@phosphor-icons/react` |
| Contact form | `@emailjs/browser` (client-side email send, no backend) |
| Fonts | `--font-archivo` (display/body), `--font-plex-mono` (mono) — via `next/font` |
| Deployment | Vercel (`.vercel/` present, `vercel.json` with redirects + security headers) |
| Domain | `ahmetbsbnr.com` (canonical, live, TLS valid per `docs/DOMAINS.md`); `www.ahmetbsbnr.com` 308-redirects to canonical; default `ahmetbsbnrportfolio.vercel.app` also live |
| Build output | Static export (`out/`) — `next build` + `out/` present alongside `.next/` |
| Tests | `npm test` → `node scripts/check-static.mjs` (custom static-output checker, not a full test framework) |
| Structure | `app/` (routes, locale-grouped), `components/` (Hero, About, Skills, Formation, Languages, Projects, Contact, Footer, SiteNav, Reveal, Magnetic, icons, content.ts), `assets-src/` (`cv.typ` — Typst source for the CV PDF, `photo_cv.png`), `public/` (served assets incl. `cv.pdf`, an attestation PDF), `scripts/`, `docs/` (production/DNS audit notes) |
| Security headers | CSP, HSTS (preload), X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy — all set in `vercel.json` |
| Accessibility | Not audited this pass (out of scope for a non-destructive inventory) — flagged as a real to-do for `CROSS_SITE_DESIGN_AUDIT.md` |

## Private/local data present — noted, never read in detail, never copied

- `.env.local`, `.vercel/.env.development.local` — local environment
  secrets (EmailJS keys, Vercel project linkage). **Not opened.**
- `docs/DNS_BACKUP_ahmetbsbnr_com_20260716.md`,
  `docs/DNS_ZONE_BACKUP_ahmetbsbnr_com_20260716b.md` — DNS zone records
  for the live personal domain. **Not opened, not copied.**
- `assets-src/photo_cv.png`, `public/photo_cv.webp`, `public/cv.pdf`,
  `public/attestation-pix-20240214.pdf` — personal photo and identity
  documents (CV, an official attestation). **Not opened, not copied.**
- `graphify-out/` — a local code-graph cache (tool-generated, not source).

**Any future workspace migration must exclude every item above from
anything that leaves this machine or gets shared** — same standard this
project already applies to its own `Configuration/PublicIdentity.local.json`
and `AuditPackages/`.

## What this inventory is NOT

This is a read-only survey. No file in the portfolio repository was
created, edited, or moved. Design-language comparison against MacCare
Local's site lives in `CROSS_SITE_DESIGN_AUDIT.md` (separate document,
also non-destructive this phase).
