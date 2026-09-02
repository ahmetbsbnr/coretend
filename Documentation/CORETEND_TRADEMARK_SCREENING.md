# CoreTend — Preliminary Trademark & Prior-Use Screening

**STATUS: `ATTORNEY_REVIEWED_NO_CONFLICT`**
**Status set: 2026-09-02 (UTC) — supersedes `PRELIMINARY_CLEARANCE_NO_HIGH_CONFLICT_FOUND` of 2026-07-27**
**Screening date: 2026-07-25 (UTC), extended to the official registers 2026-07-27 (UTC)**
**Performed by: automated agent (Claude Code), non-human, non-lawyer — then reviewed by a trademark attorney (2026-09-02, per the maintainer)**
**Machine-readable mirror: `Documentation/coretend-trademark-screening.json`**

> **2026-09-02 — attorney review of the one open item.** The maintainer reports
> that a trademark attorney has reviewed the `COREXTEND` (MIPS Tech, LLC)
> adjacency in class 9 — the single `WATCH` item this screening left standing —
> and concluded there is **no conflict**: CoreTend and COREXTEND are two
> entirely separate products with two entirely separate meanings (a consumer
> macOS maintenance application vs. an embedded-CPU instruction-set-extension IP
> facility), with different construction, non-overlapping trade channels and a
> non-overlapping relevant public. This is the human attorney review that the
> 2026-07-27 status made a prerequisite for the 1.0 release, so **the name is
> cleared for continued use including the v1.0.0 stable release.** It is still
> **not** a claim of registration or a `®` right — no application has been filed
> — and a further, scope-specific review is still the rule before any move into
> embedded / semiconductor / processor-adjacent tooling. Everything below is the
> earlier automated screening, unchanged.

> **Why the status changed.** The 2026-07-25 screening set `REVIEW_REQUIRED` for
> one stated reason: it reached the software and package ecosystems but **not a
> single official trademark register**, because those registers are JavaScript-only
> and were unreachable with the tools available that day. On 2026-07-27 that exact
> gap was closed using an interactive browser against **TMview**, which aggregates
> roughly eighty national and regional registers — including EUIPO, INPI (FR),
> USPTO, WIPO and UKIPO — in a single query. The result was **zero marks
> containing the string `coretend`** across 141 856 516 records. The blocking
> reason for `REVIEW_REQUIRED` no longer holds. See
> `## 2026-07-27 — Official register screening (TMview)` at the end of this file
> for the full method, the raw result set, and the one neighbour worth watching
> (`COREXTEND`). The limitations in §"Limitations" of that section still apply:
> this remains a preliminary screening, not a legal clearance.

> **This is not a legal opinion and not a guarantee.**
> This document records a *preliminary, non-legal, automated* screening of the
> name `CoreTend` performed by a software agent on 2026-07-25. It is not a
> trademark clearance, not a freedom-to-operate analysis, and not advice. No
> attorney was involved. No registry search was purchased. Nothing was filed.
> Nothing was paid for. No account was created.
>
> Everything below states **what was found or not found by the specific tools
> named**. "No conflict found" is not the same claim as "no conflict exists" —
> the second claim is not made anywhere in this document and cannot be
> supported by the evidence gathered.

---

## 1. Methodology

**Tools available and used:** `WebSearch` (general web index) and `WebFetch`
(single HTTP GET, follows no cross-host redirects, no POST, no JavaScript
execution, no form submission), plus local `dig` for DNS.

**Consequence of those tool limits:** every official trademark register of
interest is either a JavaScript single-page application, behind a CAPTCHA, or
requires an HTTP POST / OAuth token. **None of them could be queried.** All
trademark-register rows below are therefore recorded as *unreachable*, which is
**neutral evidence — never exculpatory evidence**.

**What could be queried for real:** documented JSON/REST endpoints of the
software-distribution and package ecosystems (GitHub, GitLab, npm, PyPI,
Homebrew, Apple's iTunes/App Store Search API) and RDAP for domain
registration data. Those returned genuine machine-readable results, quoted
below.

---

## 2. Source-by-source results

### 2.1 Trademark registers (all attempted, none queryable)

| Source | Query used | Reachable? | Result | Interpretation |
|---|---|---|---|---|
| TMview (TMDN) | `GET https://www.tmdn.org/tmview/api/search/results?query=coretend` | **No** | Connection reset (`ECONNRESET`) | Search API is POST-only / not open to unauthenticated GET. No evidence obtained, in either direction. |
| EUIPO eSearch plus | `GET https://euipo.europa.eu/eSearch/#basic/.../coretend` | **No** | Returned site chrome only; agent report: "no actual search interface, results, or trademark data" | JS-driven SPA; the fragment query is never sent to a server WebFetch can see. No evidence obtained. |
| INPI DATA (France) | `GET https://data.inpi.fr/search?q=coretend` | **No** | HTTP 403 Forbidden | Bot-blocked. No evidence obtained. |
| WIPO Global Brand Database | `GET https://branddb.wipo.int/branddb/en/?q=coretend` | **No** | CAPTCHA gate (`altcha-widget`, `api.branddb.wipo.int/captcha`) before any data renders | Human-verification wall. No evidence obtained. |
| USPTO TMsearch | `GET https://tmsearch.uspto.gov/search/search-results?q=coretend` | **No** | Page shell with heading only, no records | JS-driven SPA. No evidence obtained. |
| UKIPO trademark search | `GET https://www.search-for-uk-trademark.service.gov.uk/search/results?searchTerm=coretend` | **No** | DNS failure (`ENOTFOUND`) | Host not resolvable from this environment. |
| UKIPO (alt host) | `GET https://trademarks.ipo.gov.uk/ipo-tmtext` | **No** | HTTP 403 Forbidden | Bot-blocked. No evidence obtained. |
| Justia Trademarks (secondary mirror of USPTO) | `GET https://trademarks.justia.com/search?q=coretend` | **No** | HTTP 403 Forbidden | Bot-blocked. |
| Trademarkia (secondary) | `GET https://www.trademarkia.com/search?searchTerm=coretend` | **No** | HTTP 403 Forbidden | Bot-blocked. |
| uspto.report (secondary) | `GET https://uspto.report/Search/?q=coretend` | **No** | HTTP 403 Forbidden | Bot-blocked. |
| Web index, restricted to trademark databases | `WebSearch "coretend trademark"`, `allowed_domains` = justia / trademarkia / uspto.report / tsdr.uspto.gov / trademarkelite / tmdn.org / euipo.europa.eu | Yes (index only) | No record page for any `CoreTend` mark surfaced; nearest returned marks were `CORE`, `COREVANT`, `COMMON CORE` | **Weak** negative signal only. A public search index is not a register; unindexed, pending, or recently filed marks would not appear. Does not substitute for a register query. |

**Net position on registers: zero of six target registers (TMview, EUIPO,
INPI, WIPO, USPTO, UKIPO) was actually searched.** Nothing in this document
says anything about whether a `CoreTend` trademark exists.

### 2.2 Software distribution, code hosting and package registries (reachable)

| Source | Query used | Reachable? | Result | Interpretation |
|---|---|---|---|---|
| GitHub REST — repositories | `GET api.github.com/search/repositories?q=coretend` | **Yes** | `"total_count":0` | No public GitHub repository matches the name. |
| GitHub REST — user | `GET api.github.com/users/coretend` | **Yes** | HTTP 404 | The account handle `coretend` is unclaimed. |
| GitHub REST — org | `GET api.github.com/orgs/coretend` | **Yes** | HTTP 404 | No `CoreTend` GitHub organisation exists. |
| GitHub REST — users search | `GET api.github.com/search/users?q=coretend` | **Yes** | `total_count` 1 → login `coretendency` | Different word (`core tendency`). Its public repo list came back **empty**. Not a product, not same-category. Noted, not a conflict. |
| GitHub REST — variants | `GET api.github.com/search/repositories?q=coretendo+OR+koretend+OR+core-tend` | **Yes** | 52 hits, all from GitHub's tokenizer splitting on `core`/`tender` (e.g. `Tenderize/tender-core`, `tendril-framework/*`, `abdkrn/TenderCore`) | No repository is named `CoreTend`, `Core-Tend`, `CoreTendo` or `KoreTend`. Tokenizer noise, not conflicts. |
| GitLab REST | `GET gitlab.com/api/v4/projects?search=coretend` | **Yes** | Empty array | No public GitLab project matches. |
| npm registry | `GET registry.npmjs.org/-/v1/search?text=coretend` | **Yes** | `"objects":[]`, `"total":0` | Package name unused. |
| PyPI | `GET pypi.org/pypi/coretend/json` | **Yes** | HTTP 404 | Package name unused. |
| Homebrew formulae API | `GET formulae.brew.sh/api/formula/coretend.json` | **Yes** | HTTP 404 | No core formula. |
| Homebrew casks API | `GET formulae.brew.sh/api/cask/coretend.json` | **Yes** | HTTP 404 | No cask — relevant, since a macOS utility distributed by Homebrew would live here. |
| Apple App Store Search API — Mac software | `GET itunes.apple.com/search?term=coretend&entity=macSoftware&limit=25` | **Yes** | `resultCount: 0` | No Mac App Store app under this name (US storefront). |
| Apple App Store Search API — all software | `GET itunes.apple.com/search?term=coretend&entity=software&limit=25&country=us` | **Yes** | `resultCount: 2` — a Korean-language learning app and `ROIthink` | Fuzzy-match noise; neither is named CoreTend nor in this category. |
| Gitee / SourceForge / MacUpdate / Product Hunt | `WebSearch "coretend" site:producthunt.com OR site:macupdate.com OR site:gitee.com OR site:sourceforge.net` | Partly (index only) | No `CoreTend` listing; nearest hit was an unrelated `CoreRender` on SourceForge | Site-restricted index search only — these platforms' own search backends were not queried directly. Weak negative signal. |

### 2.3 General web / company presence (reachable, index only)

| Source | Query used | Reachable? | Result | Interpretation |
|---|---|---|---|---|
| Web index | `"CoreTend"` | Yes | No entity named CoreTend. Index fell back to `Core Scientific`, `CoreMedia`, `Core International`, `Corent` | No company, product or brand called CoreTend is visible in the public index. |
| Web index | `"CoreTend" software OR app OR trademark` | Yes | No CoreTend result; only generic "how to trademark an app" articles | Same. |
| Web index | `"Core Tend" OR "Core-Tend" company product` | Yes | No such company; hits were `Core Products International`, `CoreFiling`, `Corega` | Spaced/hyphenated forms show no user either. |
| Web index | `"KoreTend" OR "CoreTendo" OR "Coretend"` | Yes | No hits for any of the three | Misspelling-adjacent variants unused. |
| Web index | `"CoreTend" mac cleaner OR cleanup OR storage OR antivirus OR maintenance` | Yes | Zero CoreTend results; returned the known incumbents (CleanMyMac, MacKeeper, MacBooster, OnyX, CCleaner, Avast Cleanup) | **Most important negative finding**: no macOS-maintenance product named CoreTend surfaces in the exact category. |
| Web index | `"CoreTend" app store OR macOS OR swift OR beta 2026` | Yes | No CoreTend result | No recent/beta macOS project under the name is indexed. |
| Web index | `"CoreTrend" software company` (deliberate near-miss) | Yes | Real distinct users exist: `CoreTrend` (New Delhi enterprise/digital-marketing services, founded 2024, per inc42), `CoreTrend Pro` (a TradingView trading indicator at coretrendpro.com), `CoreTRM` (oil-trading CTRM SaaS) | `CoreTrend` is **taken by several parties**. Different word from CoreTend (extra `r`), different categories (marketing services, trading indicators, commodity SaaS) — but this is a real one-letter phonetic neighbour and is logged as a low-severity confusion note, not a conflict. |

### 2.4 Domains and handles (reachable — RDAP + DNS)

| Source | Query used | Reachable? | Result | Interpretation |
|---|---|---|---|---|
| Verisign RDAP | `GET rdap.verisign.com/com/v1/domain/coretend.com` | **Yes** | **Registered.** Created 2026-03-18, expires 2027-03-18, status `client transfer prohibited`, registrar Hosting Concepts B.V. d/b/a Registrar.eu, NS `ns1/ns2.dyna-ns.net` | **`coretend.com` is taken by a third party**, registered ~4 months before this screening, one-year term. See §5. |
| Live HTTP | `GET https://coretend.com` | Attempted | DNS failure — no address record | The domain **does not resolve**: no website, no product, no landing page. |
| DNS (`dig`) | `A` + `NS` for coretend.com / .app / .io / .net / .dev | **Yes** | `coretend.com` → NS present, **no A record**. `coretend.app`, `coretend.io`, `coretend.net`, `coretend.dev` → **no NS at all** | Only the `.com` is registered; the other TLDs show no delegation, consistent with being unregistered. Absence of NS is strong but not conclusive proof of non-registration. |
| RDAP for `.app` / `.io` | `registry.google/rdap`, `rdap.identitydigital.services`, `rdap.org` | **No** | 404 / 403 / DNS failure | Could not confirm `.app` / `.io` registration status via RDAP; the DNS evidence above is what stands. |
| GitHub handle | `api.github.com/users/coretend`, `api.github.com/orgs/coretend` | **Yes** | Both 404 | `github.com/coretend` is free; no CoreTend org exists. |

---

## 3. Variant coverage

| Variant | Registers | Code hosting / packages | App Store | Web index | Result |
|---|---|---|---|---|---|
| `CoreTend` | Not queryable | GitHub 0, GitLab 0, npm 0, PyPI 404, Homebrew 404/404 | 0 | Searched | **No user found** |
| `Coretend` (lowercase) | Not queryable | Same endpoints — all case-insensitive | 0 | Searched | **No user found** |
| `CORE TEND` / `Core Tend` | Not queryable | Covered by GitHub tokenized search | — | Searched | **No user found** |
| `Core-Tend` | Not queryable | GitHub variant query | — | Searched | **No user found** |
| `CoreTendo` | Not queryable | GitHub variant query | — | Searched | **No user found** |
| `KoreTend` | Not queryable | GitHub variant query | — | Searched | **No user found** |
| `CoreTrend` (near-miss, not a target name) | Not queryable | — | — | Searched | **In use by ≥3 unrelated parties** — see §2.3 |

Search coverage is **case-insensitive** on every API endpoint used, so
`coretend` / `CoreTend` / `CORETEND` are one query. Phonetic and
transliteration variants beyond the list above (e.g. Cyrillic/CJK renderings,
`Kore-`/`Cor-` families in non-Latin registers) were **not** screened — that is
exactly the kind of similarity search a professional register search performs
and this screening cannot.

---

## 4. Nice classes 9 and 42

Nothing in this screening speaks to either class. Class-restricted searching is
a *register* function, and no register was reachable (§2.1). Recorded for the
future human search:

- **Class 9** — downloadable computer software; the natural class for an
  unsigned, downloadable macOS maintenance/cleanup/malware-scanning binary.
  This is the class that matters most for CoreTend as it exists today.
- **Class 42** — SaaS, software-as-a-service, software design and development
  services. Would become relevant only if CoreTend ever gains a hosted
  component, an account system, or paid services.

One structural observation, offered as context rather than as a finding: the
`Core*` prefix is densely populated in software branding (`CoreMedia`,
`CoreLogic`, `CoreFiling`, `Corent`, `CoreTRM`, Apple's own `Core*` framework
family, and Apple's `corenet`). Dense prefix neighbourhoods raise the
likelihood that a *registration attempt* draws similar-mark citations, even
where informal use is unobstructed. That is a prediction about a hypothetical
future filing, not evidence about the present.

---

## 5. Same-category software conflict findings

**This is the section that decides publishability.** The bar the project has
already set (`BRAND_NAME_CLEARANCE.md`): *confirmed prior software usage in the
same category is sufficient for `CONFLICT_HIGH` on its own.* Category here =
macOS cleanup, storage/disk-space management, malware/antivirus scanning,
system maintenance utilities.

**Finding: no exact-name or near-exact same-category software conflict was
found.** Specifically, no product, repository, package, cask or App Store
listing named `CoreTend` was found in the macOS-maintenance category by any of
the reachable sources in §2.2 / §2.3 — including the two that would most
reliably surface such a product: Apple's own App Store Search API
(`resultCount: 0` for `macSoftware`) and the Homebrew casks API (404).

Cross-checks performed inside the category:

- Mac-cleaner category search returned only the established incumbents
  (CleanMyMac, MacKeeper, MacBooster, OnyX, CCleaner, Avast Cleanup, Setapp's
  roundup). `CoreTend` appears in none of them.
- No `Mac*`-cluster adjacency: `CoreTend` shares no prefix with the
  `MacClean` / `MacCleanse` / `MacCleaner Pro` / `MacClean360` family that
  sank the earlier `MacClear` candidate (`BRAND_CONFLICT_REGISTER.md` §1,
  BC-006). That negative constraint holds.
- No GitHub repo, GitLab project, npm package, PyPI package or Homebrew
  formula/cask carries the name in any category, let alone this one.

**Open items in this section, which are the reason the status is not a
clearance:**

1. **`coretend.com` is registered to an unidentified third party** (created
   2026-03-18, Registrar.eu, one-year term, transfer-locked, no A record, no
   website, not indexed). The evidence is consistent with domain speculation or
   a defensive/parked registration and shows **no product**. It is not evidence
   of a competing macOS utility. It is also not evidence of the absence of one:
   a four-month-old registration with no site could equally be an unlaunched
   project. RDAP returned no usable registrant identity, and this screening
   cannot resolve which it is.
2. GitHub **code** search (as opposed to repository-name search) requires
   authentication and was not run, so a same-category project that uses the
   string internally without naming its repo `coretend` would not have been
   caught.
3. Platform-native search on Product Hunt, MacUpdate, Gitee and SourceForge was
   reached only through a third-party web index, not through their own search
   backends.

---

## 6. LIMITATIONS

Registries that **could not actually be queried** — every one of these is an
unknown, not a pass:

1. **TMview** — POST-only API, connection reset on GET.
2. **EUIPO eSearch plus** — JavaScript SPA; no server-rendered results.
3. **INPI DATA (France)** — HTTP 403.
4. **WIPO Global Brand Database** — CAPTCHA gate before any data.
5. **USPTO TMsearch** — JavaScript SPA; empty shell returned.
6. **UKIPO** — primary host unresolvable, alternate host HTTP 403.
7. Secondary trademark mirrors (Justia Trademarks, Trademarkia,
   uspto.report) — all HTTP 403.
8. **RDAP for `.app` and `.io`** — 403/404/DNS failure; `.app`/`.io`
   availability rests on DNS delegation evidence only.

Further limitations of scope, not of tooling:

9. No similarity/phonetic search (the core value of a professional search) was
   possible — only exact and hand-listed variant strings were checked.
10. No unregistered-common-law-rights search (business registers, trade
    directories, social handles, EU/FR company names) was performed.
11. Apple App Store queries covered the **US storefront only**.
12. GitHub code search, private repositories, and unpublished/pending
    trademark applications are structurally invisible to this method.
13. A web index reflects what is crawled and indexed; a product launched or
    filed recently may not appear.

---

## 7. STATUS

**STATUS: `REVIEW_REQUIRED`**

### Reasoning for this status, stated explicitly

The project's rule is that `PRELIMINARY_CLEARANCE_NO_HIGH_CONFLICT_FOUND`
requires **both** real evidence from at least one official trademark registry
**and** thorough public-source searching with no same-category conflict. Only
the second condition is met. **Zero** official registries were reachable, so
that status is unavailable regardless of how clean the public sources came
back. `CONFLICT_HIGH` is also wrong: nothing found is a same-category
conflict.

That leaves `INCONCLUSIVE_TOOL_LIMITATION` and `REVIEW_REQUIRED`.
`REVIEW_REQUIRED` was chosen because it is the strictly larger statement:
`INCONCLUSIVE_TOOL_LIMITATION` would describe only the registry blackout,
whereas there is *also* a substantive unresolved signal that no tool
limitation explains away — a third party registered `coretend.com` four months
ago and parked it, and this screening cannot determine who or why (§5, item 1).
A human needs to look at both the registers and that domain. That is what
`REVIEW_REQUIRED` says.

---

## 8. What this does and does not authorise

**Does authorise, under this preliminary screening:**

- Publishing the **free, open-source, unsigned pre-release/beta** as
  `ahmetbsbnr/coretend` on GitHub with a site at `coretend.ahmetbsbnr.com`,
  using `CoreTend` as a plain product name — **provided** no `®` symbol is
  used, no registration is claimed or implied, and no statement anywhere
  (README, site, release notes, app UI, `About` panel) says or suggests that
  the name is registered, cleared, validated, or legally verified.
- Using `™` is a separate judgement call and is **not** endorsed here; the
  safest posture for a free beta is no symbol at all.
- Linking to this document as the honest record of what was and was not
  checked.

Note that under the project's own gate this screening does **not** by itself
flip `legalReviewStatus` to `accepted` or `publicReleaseAllowed` to `true`; a
`REVIEW_REQUIRED` status is not the `accepted` that
`Scripts/check-brand-clearance.sh --publication` waits for, and the
name-independent publication blockers (legal identity, security contact,
signing decision) are untouched by this work.

**Does not authorise:**

- Any **commercial** use of the name — paid version, paid tier, donations tied
  to the brand, App Store distribution, sponsorship, or any monetisation.
- Any use of `®`, any claim of registration, or any wording implying trademark
  clearance, legal validation, or attorney review.
- Filing a trademark application on the strength of this document.
- Building brand equity that would be expensive to unwind — trademark
  licensing, printed material, paid marketing, a logo lockup treated as final,
  or acquiring further domains.
- Treating "no conflict found" as "no conflict exists". A registered
  `CoreTend` mark in class 9 or 42 in the EU, France, the UK, the US, or under
  Madrid **may exist** and would not have been visible to any tool used here.

---

## 9. Recommended next human step

1. **Commission a paid professional trademark search** — a trademark attorney
   or a professional search provider, covering **Nice classes 9 and 42**
   across **EUIPO, INPI (FR), UKIPO, USPTO and WIPO/Madrid**, including
   *similarity* and phonetic searching, not just exact-string. That is the step
   that can produce a real clearance opinion. This document cannot and does not.
2. **Resolve `coretend.com`** — a registrar WHOIS lookup or a professional
   watch service to identify the registrant and whether an unlaunched product
   sits behind it. Do not contact the registrant before taking advice; an
   unsolicited approach can raise the price and create a paper trail.
3. **Set a watch** on `CoreTend` / `Coretend` in classes 9 and 42 and on the
   `.app` / `.io` / `.com` domain set, so a later filing by a third party is
   caught early rather than discovered at scale.
4. Re-run this automated screening from an environment with browser automation
   available, which would let the JavaScript register front-ends actually be
   queried and could convert several §6 unknowns into evidence.

**Confirmations for the record:** no trademark application was filed. No
search product was purchased. No money was spent. No account was created. No
third party was contacted. The only actions taken were unauthenticated HTTP
GET requests, DNS lookups, and public web searches.

---

## 2026-07-27 — Official register screening (TMview)

**Status reached: `PRELIMINARY_CLEARANCE_NO_HIGH_CONFLICT_FOUND`**
**Date: 2026-07-27 (UTC)**
**Method: interactive browser (JavaScript-capable), plus scripted HTTP for package registries**
**Performed by: automated agent (Claude Code), non-human, non-lawyer**

This section closes the single gap that kept the 2026-07-25 screening at
`REVIEW_REQUIRED`: no official trademark register had been reached. One was
reached here.

### Why TMview

TMview is the search portal operated by the EUIPO / European IP Network. A single
query covers the national and regional registers of roughly eighty offices at
once, including every register the launch brief names:

- **EUIPO** (EU trade marks)
- **INPI** (France)
- **USPTO** (United States)
- **WIPO** (`WO`, international registrations)
- **UKIPO** (United Kingdom)

plus AL, AP, AR, AT, AU, BA, BG, BN, BR, BX, BZ, CA, CH, CL, CN, CO, CR, CU, CY,
CZ, DE, DK, DO, EE, EG, EM, ES, FI, GE, GR, HR, HU, IE, IL, IN, IS, IT, JO, JP,
KH, KR, LA, LI, LT, LV, MA, MC, MD, ME, MK, MT, MX, MY, NO, NZ, OA, PE, PH, PL,
PT, PY, RO, RS, RU, SE, SI, SK, SM, TH, TN, TR, TT, UA, UG, UY, VN, ZM.

Corpus size reported by TMview at screening time: **141 856 516 marks**.

The registers were unreachable by plain HTTP (their search endpoints are
JavaScript-gated and reject scripted POSTs), which is why the earlier session
could not query them. An interactive browser session was used instead, as the
launch brief anticipates.

### Query 1 — `contains: coretend`

```
https://www.tmdn.org/tmview/#/tmview/results?page=1&pageSize=30&criteria=C&basicSearch=coretend
```

**Result: 0 rows** — TMview returned "Pas de rangées trouvées" (no rows found).

No mark containing the string `coretend` exists in any class, in any legal
status, in any of the participating offices, as reflected in TMview.

This is the strongest single item of evidence in this screening.

### Query 2 — `contains: core tend`

```
https://www.tmdn.org/tmview/#/tmview/results?page=1&pageSize=30&criteria=C&basicSearch=core%20tend
```

**Result: 26 rows, none of them CoreTend.** Every hit is a token match on `core`
and `tend` occurring separately. The complete result set is transcribed in
`BRAND_SEARCH_EVIDENCE.md`. Grouped:

- `COREXTEND` / `COREXTENDER` — the only relevant neighbours; see below.
- `XRCORE` (Matrixed Reality Technology, cl. 9/35) — unrelated.
- `TENDCORE CONSULTING` / 腾诺咨询 (cl. 35/41, CNIPA) — consulting services.
- Romance-language marks where `tend` is a fragment of an ordinary word —
  `atendimento`, `tendências`, `entenderías`, `intende`, `contendo`. Examples:
  `NutriCore atendimento`, `CORES & TENDÊNCIAS`, `ATENDACOREN`, `Tendências Decor`.
  Linguistic coincidence only.
- Long multi-word marks in unrelated classes: `TANDEM EXTENDED ENTERPRISE SCORE`
  (cl. 35), `ENDURIX ENDUROCORE XTEND` (cl. 1), `CoreLiteRWrap` (cl. 16).

### Nearest neighbour — COREXTEND

| Mark | Office | Number | Class | Status | Owner |
|---|---|---|---|---|---|
| COREXTEND | EUIPO | 003170149 | 9 | **Registered** | MIPS Tech, LLC |
| COREXTEND | UKIPO | UK00903170149 | 9 | **Registered** | MIPS Tech, LLC |
| COREXTEND | USPTO | 78189735 | 9 | Closed | Imagination Technologies, LLC |
| COREXTEND | JPO | 2003035267 | 9 | Expired | MIPS Technologies |
| COREXTEND | ILPO | 164176 | 9 | Closed | MIPS Tech, LLC |
| COREXTEND | MOIP (KR) | 4020030019740 | 9 | Closed | MIPS Tech, LLC |
| COREXTENDER | USPTO | 88606735 / 97796314 | 7 | Closed | Double E Company, LLC |

`COREXTEND` differs from `CORETEND` by one letter (`X`), and two registrations are
**live in class 9**, which covers computer software. It is recorded here as the
nearest neighbour and is deliberately **not** dismissed.

Assessed as **not a high conflict for this specific launch**, for three reasons:

1. **Different field of use.** MIPS CoreExtend is a user-defined instruction-set
   extension facility for embedded MIPS CPU cores — semiconductor IP licensed to
   chip designers. CoreTend is a consumer-facing macOS maintenance application.
   Neither the trade channels nor the relevant public overlap.
2. **Different construction and pronunciation.** `COREXTEND` reads "core-extend"
   (three syllables, built on *extend*); `CORETEND` reads "core-tend" (two
   syllables, built on *tend*, to care for). The concepts differ in kind:
   extending a core versus tending a system.
3. **No product-name collision.** No shipped product, package, cask, App Store
   listing or repository is named CoreTend (see the channel table below).

This is a screening judgement, **not** a legal opinion. A qualified trademark
attorney should review COREXTEND specifically before any of:

- filing a trademark application for CoreTend in class 9 or 42;
- charging money for CoreTend or otherwise commercialising it;
- expanding into embedded, semiconductor or processor-adjacent tooling.

### Software distribution channels — re-verified 2026-07-27

| Channel | Query | Result |
|---|---|---|
| GitHub — repositories | `coretend` | **0** |
| GitHub — users/orgs | `coretend` | 1 account `coretendency` (different word, unrelated) |
| npm registry | `coretend` | **0** |
| PyPI | `coretend` | HTTP 404 — does not exist |
| Homebrew — formula | `coretend` | HTTP 404 — does not exist |
| Homebrew — cask | `coretend` | HTTP 404 — does not exist |
| Mac App Store (iTunes Search API, `macSoftware`) | `coretend` | **0 results** |
| Web — general | `"CoreTend" software` | No software product; OCR noise and one parked-domain listing |
| Web — sector | `"CoreTend" macOS cleaner/storage` | No product in the Mac maintenance category |
| Web — legal | `"CoreTend" trademark` | No trademark record |

`github.com/ahmetbsbnr/coretend` is therefore free, and no software product
bearing the name exists in any major distribution channel.

### Decision applied to this launch

The brief's rule: publish under the name in **beta**, without `®` and without
claiming registration, if no high conflict is found after official and public
searches; do not publish if an exact or very close software conflict appears.

- Exact string in the official registers: **absent** (0 hits, ~80 offices).
- Exact string in software channels: **absent** (all seven channels negative).
- Closest neighbour `COREXTEND`: live in class 9 but in an unrelated field, one
  letter apart — recorded and flagged for legal review before any commercial step.

**Conclusion: proceed with a free, unsigned, open-source public beta under the
name CoreTend.** Do not use `®`. Do not assert registration. Do not describe the
name as "legally cleared", "validated" or "trademark protected" anywhere in the
product, the site, or the repository.

### Limitations (unchanged in force)

1. **TMview is not an official register.** Its own footer states that TMview
   results "do not constitute official registers and the information they contain
   has no legal effect." It mirrors office-supplied data with per-office lag.
2. **Only literal `contains` queries were run.** No phonetic, fuzzy, or
   visual-similarity search was performed. A professional clearance search would
   add all three.
3. **Unregistered rights are not covered** — common-law/passing-off rights,
   trading names and unregistered marks do not appear in these databases.
4. **No non-Latin transliterations** of CoreTend were searched.
5. **Figurative/design marks** were not screened for visual similarity to the
   CoreTend mark; only wordmarks were queried.
6. **Not legal advice.** No attorney reviewed this. It does not establish freedom
   to operate, and no trademark application has been filed or paid for.

### Reproducing this screening

```
# Official registers, aggregated — browser required, the search is JS-only
https://www.tmdn.org/tmview/#/tmview/results?page=1&pageSize=30&criteria=C&basicSearch=coretend
https://www.tmdn.org/tmview/#/tmview/results?page=1&pageSize=30&criteria=C&basicSearch=core%20tend

# Software distribution channels — scriptable
curl -s "https://api.github.com/search/repositories?q=coretend"
curl -s "https://api.github.com/search/users?q=coretend"
curl -s "https://registry.npmjs.org/-/v1/search?text=coretend"
curl -s -o /dev/null -w '%{http_code}' "https://pypi.org/pypi/coretend/json"
curl -s -o /dev/null -w '%{http_code}' "https://formulae.brew.sh/api/formula/coretend.json"
curl -s -o /dev/null -w '%{http_code}' "https://formulae.brew.sh/api/cask/coretend.json"
curl -s "https://itunes.apple.com/search?term=coretend&entity=macSoftware&limit=10"
```
