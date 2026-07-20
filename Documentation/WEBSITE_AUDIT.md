# Website Audit — Session 3

Date: 2026-07-20. Scope: `website/` at HEAD `6ea6c48`.

## Stack

Static HTML/CSS, no framework, no build tool, no JS runtime dependency.
`website/generate.py` (single Python script, stdlib only) generates
`en/*.html` and `fr/*.html` from Python content tables — the script itself
notes `ponytail: hand-rolled string templating instead of a template
engine — add Jinja2 only if page count or logic genuinely outgrows this.`
Output is committed static HTML; nothing runs server-side. **VERIFIED_COMPLETE**
(read `generate.py`, confirmed no framework/bundler files present: no
`package.json`, no `node_modules`, no `.jsx`/`.vue`/etc. in `website/`).

## Structure / page inventory

11 pages per locale, present in both `en/` and `fr/` (22 files, exact
1:1 parity by filename — `find` listing confirmed identical basenames in
both directories): `index`, `features`, `download`, `documentation`,
`open-source`, `roadmap`, `faq`, `privacy`, `security`, `changelog`,
`licenses`, `legal`, `404`. Root `website/index.html` is a redirect/landing
shim (not a 12th content page). **VERIFIED_COMPLETE** for structural parity.

## Trackers / analytics

`grep -irl` for `google-analytics|gtag|analytics|facebook.net|hotjar|
mixpanel|segment.io|plausible|fathom` across `en/`, `fr/`, `assets/`
matched only `en/faq.html` and `en/privacy.html` — both are prose stating
*"no telemetry, no analytics, no network calls"*, not actual tracker script
tags. No `<script src="https://...">` or external `src=`/`href=` to a
third-party host found anywhere in `en/*.html` (grep for `src="https?://`
and `href="https?://` returned zero matches — i.e., no external resource
loads at all, consistent with the local-only, no-CDN design).
**VERIFIED_COMPLETE**: no trackers present.

## Real vs. placeholder content

Legitimate, deliberately-marked placeholders (not accidental gaps) found in:
- `legal.html`, `privacy.html`, `security.html` (both locales): bracketed
  tokens `[LEGAL_NAME_TO_DEFINE]`, `[LEGAL_ADDRESS_TO_DEFINE]`,
  `[SECURITY_CONTACT_TO_DEFINE]`, `[DOMAIN_TO_DEFINE]` — self-documented in
  page text as pending real legal identity, tracked already in
  `Documentation/PUBLICATION_PLACEHOLDERS.md` and `LEGAL_AND_LICENSE_STATUS.md`
  from prior sessions. Not new findings, re-confirmed present and unchanged.
- `download.html`: explicit prose stating "there is no public release yet,
  this page is a placeholder." Honest, not misleading.
- All other checked pages (`faq`, `features`, `index`) contained no
  `lorem ipsum`/`TODO`/`coming soon`/`TBD` — the grep hits on those files
  were the tracker-denial prose above and the Cloud Cleanup feature card's
  correct use of the word "placeholders" (an actual iCloud technical term,
  not a content gap). **VERIFIED_PARTIAL** overall: legal/contact identity
  is honestly and consistently marked incomplete; no undisclosed placeholder
  content found elsewhere.

## Accessibility basics

- `lang="en"` / `lang="fr"` present on `<html>` in both `index.html`
  variants (spot-checked; template-generated so applies site-wide by
  construction — read `generate.py`'s page-shell function to confirm it's
  emitted once per page, not just on the homepage).
- `viewport` meta tag present in 13 of the checked files.
- Zero `<img>` tags exist anywhere in `en/`+`fr/` (`grep -o "<img[^>]*>" | wc -l`
  → 0) — the site is pure text/CSS, so missing `alt` text is moot; there is
  nothing to caption. Not a finding, just a fact worth recording so a future
  auditor doesn't assume alt-text was skipped and unchecked.
- Did not run an automated a11y scanner (axe, Lighthouse) this session — no
  browser/display available in this environment (same constraint as the
  design/UI audit's screenshot blocker, see below). Semantic HTML tags used
  (`<h1>`-`<h3>`, `<nav>`, `<table>` for the legal page) were spot-checked by
  eye during `grep`/`Read`, not exhaustively. **IMPLEMENTED_UNVERIFIED** for
  full WCAG conformance; **VERIFIED_COMPLETE** for the basics actually
  checked (lang, viewport, no missing alt because no images).

## What blocks production deploy

Carried over from `HUMAN_BLOCKERS.md` / `PUBLICATION_PLACEHOLDERS.md`,
re-confirmed unchanged this session:
- Legal identity placeholders (`[LEGAL_NAME_TO_DEFINE]` etc.) must be
  resolved before the legal/privacy/security pages can go live truthfully.
- `download.html` has no real download to point to (no public GitHub
  release exists — see `DISTRIBUTION_AUDIT.md` this session).
- No deploy target configured/verified this session (`Documentation/
  WEBSITE_DEPLOYMENT.md` from a prior session documents the intended
  Netlify/static-host approach; not re-verified here — out of scope, no
  network deploy was attempted per the "do not deploy the site" constraint
  on this session).
