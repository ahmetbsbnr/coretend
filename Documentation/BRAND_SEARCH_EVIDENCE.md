# Brand Search Evidence — "CoreTend"

**Status: NO SEARCH PERFORMED**
**Date: 2026-07-24**

> **Superseded in part on 2026-07-25.** The header above and the two sections
> that follow it are preserved verbatim as the record of the state on
> 2026-07-24. A preliminary automated screening *was* subsequently run — see
> the appended section
> `## 2026-07-25 — CoreTend screening (0.9.0 launch phase)`
> at the end of this file. That screening reached the software and package
> ecosystems but **not** a single official trademark register, and its status is
> `REVIEW_REQUIRED`, not a clearance.

## What this file records

Nothing. That is the finding.

No trademark-registry query, no prior-software-usage query, and no domain
or handle availability query was run for `CoreTend` or `coretend`. This
file exists so that the absence is explicit and auditable rather than
inferred from an empty conflict table.

The name was selected by the project owner as a direct decision, and the
rename proceeds under the engineering gate only — see
`Documentation/BRAND_NAME_CLEARANCE.md` for why that separation is
defensible, and `Documentation/BRAND_CONFLICT_REGISTER.md` §2 for the
tracked unknowns (CT-001, CT-002).

## What a real evidence file must contain before publication

When the search is eventually run, this file must be replaced with, at
minimum:

| Source | Query | Date (UTC) | Raw result | Interpretation |
|---|---|---|---|---|
| EUIPO eSearch Plus | `CoreTend`, classes 9 + 42 | | | |
| TMview | `CoreTend`, all offices | | | |
| INPI DATA (FR) | `CoreTend` | | | |
| USPTO TMsearch | `CoreTend`, classes 9 + 42 | | | |
| UKIPO | `CoreTend` | | | |
| WIPO Global Brand Database | `CoreTend` | | | |
| GitHub | `CoreTend`, `coretend` (repos + orgs) | | | |
| App Store / Mac App Store | `CoreTend` | | | |
| Package registries (npm, PyPI, Homebrew, SwiftPM index) | `coretend` | | | |

Each row needs the raw result, not a summary of it, and a tool-limitation
note where a source could not be reached — an unreachable registry is
neutral evidence, never exculpatory evidence.

## Prior candidate

The corresponding evidence for the abandoned `MacClear` candidate — which
*was* researched — is preserved at
`Documentation/RebrandHistory/BRAND_SEARCH_EVIDENCE_MACCLEAR.md`.

---

## 2026-07-25 — CoreTend screening (0.9.0 launch phase)

**Performed by:** automated agent (Claude Code) — non-human, non-lawyer.
**Tools:** `WebSearch` (web index), `WebFetch` (unauthenticated HTTP GET only —
no POST, no JavaScript execution, no form submission), local `dig`.
**Full write-up:** `Documentation/CORETEND_TRADEMARK_SCREENING.md`
**Machine-readable:** `Documentation/coretend-trademark-screening.json`
**Status: `REVIEW_REQUIRED`** — not a clearance, not a legal opinion, not a
guarantee. No filing was made. No money was spent. No account was created.

This screening does **not** satisfy the publication gate. `legalReviewStatus`
stays as it was; `Scripts/check-brand-clearance.sh --publication` should still
fail.

### A. Trademark registers — 0 of 6 actually searched

| Source | Query | Date (UTC) | Raw result | Interpretation |
|---|---|---|---|---|
| EUIPO eSearch plus | `GET euipo.europa.eu/eSearch/#basic/1+1+1+1/100+100+100+100/coretend` | 2026-07-25 | Site chrome only; no search UI, no records rendered | JS SPA — the fragment query never reaches a server the tool can see. **No evidence, either way.** |
| TMview (TMDN) | `GET tmdn.org/tmview/api/search/results?query=coretend` | 2026-07-25 | `ECONNRESET` | POST-only API. **No evidence.** |
| INPI DATA (FR) | `GET data.inpi.fr/search?q=coretend` | 2026-07-25 | HTTP 403 Forbidden | Bot-blocked. **No evidence.** |
| USPTO TMsearch | `GET tmsearch.uspto.gov/search/search-results?q=coretend` | 2026-07-25 | Page shell, heading only, no records | JS SPA. **No evidence.** |
| UKIPO | `GET www.search-for-uk-trademark.service.gov.uk/search/results?searchTerm=coretend`; then `GET trademarks.ipo.gov.uk/ipo-tmtext` | 2026-07-25 | DNS `ENOTFOUND`; then HTTP 403 | Unreachable. **No evidence.** |
| WIPO Global Brand DB | `GET branddb.wipo.int/branddb/en/?q=coretend` | 2026-07-25 | CAPTCHA gate (`altcha-widget` → `api.branddb.wipo.int/captcha`) before any data | Human-verification wall. **No evidence.** |
| Justia Trademarks (secondary) | `GET trademarks.justia.com/search?q=coretend` | 2026-07-25 | HTTP 403 | Bot-blocked. |
| Trademarkia (secondary) | `GET trademarkia.com/search?searchTerm=coretend` | 2026-07-25 | HTTP 403 | Bot-blocked. |
| uspto.report (secondary) | `GET uspto.report/Search/?q=coretend` | 2026-07-25 | HTTP 403 | Bot-blocked. |
| Web index, domain-restricted | `WebSearch "coretend trademark"`, allowed_domains = justia / trademarkia / uspto.report / tsdr.uspto.gov / trademarkelite / tmdn.org / euipo.europa.eu | 2026-07-25 | No `CoreTend` record page; nearest marks returned were `CORE`, `COREVANT`, `COMMON CORE` | Weak negative signal only. An index is not a register. **Does not substitute for a register query.** |

**Nice classes 9 and 42 were therefore never searched.** Class-restricted
searching is a register function and no register was reachable. Per this
file's own standing rule, an unreachable registry is neutral evidence, never
exculpatory evidence.

### B. Prior software usage — reachable, real machine-readable results

| Source | Query | Date (UTC) | Raw result | Interpretation |
|---|---|---|---|---|
| GitHub REST repos | `GET api.github.com/search/repositories?q=coretend` | 2026-07-25 | `"total_count":0` | No repository under the name. |
| GitHub REST user | `GET api.github.com/users/coretend` | 2026-07-25 | HTTP 404 | `github.com/coretend` unclaimed. |
| GitHub REST org | `GET api.github.com/orgs/coretend` | 2026-07-25 | HTTP 404 | No CoreTend organisation. |
| GitHub REST users | `GET api.github.com/search/users?q=coretend` | 2026-07-25 | `total_count` 1 → login `coretendency`; its `/repos` list returned empty | Different word ("core tendency"), no repositories, no product. Logged, not a conflict. |
| GitHub REST variants | `GET api.github.com/search/repositories?q=coretendo+OR+koretend+OR+core-tend` | 2026-07-25 | 52 hits, all tokenizer noise on `core`/`tender`: `Tenderize/tender-core`, `abdkrn/TenderCore`, `tendril-framework/*`, `Bread-Corp/Tender-Core-Logic` … | **No repository named** CoreTend / Core-Tend / CoreTendo / KoreTend. |
| GitLab REST | `GET gitlab.com/api/v4/projects?search=coretend` | 2026-07-25 | Empty array | No project. |
| npm | `GET registry.npmjs.org/-/v1/search?text=coretend` | 2026-07-25 | `"objects":[]`, `"total":0` | Name unused. |
| PyPI | `GET pypi.org/pypi/coretend/json` | 2026-07-25 | HTTP 404 | Name unused. |
| Homebrew formulae | `GET formulae.brew.sh/api/formula/coretend.json` | 2026-07-25 | HTTP 404 | No formula. |
| Homebrew casks | `GET formulae.brew.sh/api/cask/coretend.json` | 2026-07-25 | HTTP 404 | No cask — the place a macOS GUI utility would live. |
| Apple App Store API (Mac) | `GET itunes.apple.com/search?term=coretend&entity=macSoftware&limit=25` | 2026-07-25 | `resultCount: 0` | No Mac App Store app (US storefront). |
| Apple App Store API (all software) | `GET itunes.apple.com/search?term=coretend&entity=software&limit=25&country=us` | 2026-07-25 | `resultCount: 2` — a Korean-language learning app, and `ROIthink` | Fuzzy-match noise, neither named CoreTend, neither same-category. |
| Product Hunt / MacUpdate / Gitee / SourceForge | `WebSearch "coretend" site:producthunt.com OR site:macupdate.com OR site:gitee.com OR site:sourceforge.net` | 2026-07-25 | No listing; nearest was unrelated `CoreRender` on SourceForge | Index-only, not the platforms' own search backends. Weak negative. |

### C. Same-category check (macOS cleanup / storage / malware / maintenance)

| Query | Date (UTC) | Raw result | Interpretation |
|---|---|---|---|
| `WebSearch "CoreTend" mac cleaner OR cleanup OR storage OR antivirus OR maintenance` | 2026-07-25 | Zero CoreTend results; index returned only incumbents — CleanMyMac, MacKeeper, MacBooster, OnyX, CCleaner, Avast Cleanup, Setapp roundups | **No macOS-maintenance product named CoreTend surfaced in the exact category.** |
| `WebSearch "CoreTend" app store OR macOS OR swift OR beta 2026` | 2026-07-25 | No CoreTend result | No recent/beta macOS project under the name is indexed. |

Combined with `resultCount: 0` from Apple's own search API and 404 from the
Homebrew casks API, this is the strongest negative evidence in the file — and
it remains "**no same-category conflict was found**", not "none exists".

### D. General web and near-miss control

| Query | Date (UTC) | Raw result | Interpretation |
|---|---|---|---|
| `WebSearch "CoreTend"` | 2026-07-25 | No CoreTend entity; index fell back to Core Scientific, CoreMedia, Core International, Corent | No company/product/brand called CoreTend is visible. |
| `WebSearch "CoreTend" software OR app OR trademark` | 2026-07-25 | No CoreTend result; only generic "how to trademark an app" articles | Same. |
| `WebSearch "Core Tend" OR "Core-Tend" company product` | 2026-07-25 | No such company; hits were Core Products International, CoreFiling, Corega | Spaced/hyphenated forms unused. |
| `WebSearch "KoreTend" OR "CoreTendo" OR "Coretend"` | 2026-07-25 | No hits for any of the three | Variants unused. |
| `WebSearch "CoreTrend" software company` (deliberate one-letter near-miss, **not** a candidate name) | 2026-07-25 | Three distinct real users: `CoreTrend` — New Delhi enterprise/digital-marketing services, founded 2024 (inc42); `CoreTrend Pro` — a TradingView trading indicator at `coretrendpro.com`; `CoreTRM` — commodity/oil-trading CTRM SaaS | `CoreTrend` is occupied by several parties in unrelated categories. Different word (extra `r`). Low-severity phonetic-confusion note, not a conflict. |

### E. Domains and handles

| Source | Query | Date (UTC) | Raw result | Interpretation |
|---|---|---|---|---|
| Verisign RDAP | `GET rdap.verisign.com/com/v1/domain/coretend.com` | 2026-07-25 | **Registered.** Created 2026-03-18, expires 2027-03-18, status `client transfer prohibited`, registrar Hosting Concepts B.V. d/b/a Registrar.eu, NS `ns1.dyna-ns.net` / `ns2.dyna-ns.net` | **`coretend.com` is held by an unidentified third party**, registered ~4 months before this screening, one-year term. Registrant identity not disclosed by RDAP. |
| Live HTTP | `GET https://coretend.com` | 2026-07-25 | DNS failure, no address record | Does not resolve — no site, no landing page, no product visible. Consistent with parking *or* an unlaunched project; this screening cannot tell which. |
| `dig` A + NS | `coretend.com`, `.app`, `.io`, `.net`, `.dev` @1.1.1.1 | 2026-07-25 | `.com` → NS present, **no A record**. `.app`, `.io`, `.net`, `.dev` → **no NS** | Only the `.com` appears registered. No delegation on the others, consistent with unregistered — strong but not conclusive. |
| RDAP `.app` / `.io` | `registry.google/rdap`, `rdap.nic.google`, `rdap.identitydigital.services`, `rdap.org` | 2026-07-25 | HTTP 404 / 403 / DNS failure | Could not confirm `.app` / `.io` registration by RDAP. Tool limitation. |
| GitHub handle | `api.github.com/users/coretend`, `api.github.com/orgs/coretend` | 2026-07-25 | Both HTTP 404 | Handle and org name both free. |

### F. Variant coverage

`CoreTend`, `Coretend`, `CORETEND`, `CORE TEND`, `Core Tend`, `Core-Tend`,
`CoreTendo`, `KoreTend` — all screened; every API endpoint used is
case-insensitive, so casing variants are one query. Plus `CoreTrend` as a
near-miss control. **Not** screened: phonetic/similarity families, non-Latin
scripts and transliterations — the exact work a professional register search
does and this method cannot.

### G. Tool limitations, restated as unknowns

TMview, EUIPO, INPI, WIPO, USPTO and UKIPO were **all** unqueryable
(POST-only, JS SPA, 403, or CAPTCHA). No similarity search. No common-law /
business-register search. US App Store storefront only. GitHub code search
needs auth and was skipped. Private repos and pending applications are
invisible. RDAP for `.app`/`.io` blocked.

### H. Net position

No conflict was found. That is not the same finding as no conflict existing,
and the difference is the whole point of this file. The registry dimension is
entirely unknown; the software-ecosystem dimension came back genuinely clean
via authoritative APIs; one unresolved third-party signal (`coretend.com`)
remains. Hence `REVIEW_REQUIRED`, and hence the recommended next step is a
**paid professional search by a human attorney** — see
`Documentation/CORETEND_TRADEMARK_SCREENING.md` §9.
