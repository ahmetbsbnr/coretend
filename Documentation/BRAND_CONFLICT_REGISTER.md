# Brand Conflict Register

Two eras are recorded here:

1. **MacClear** — a candidate that was researched, found conflicted, and
   abandoned. Its rows are kept as history, now marked CLOSED.
2. **CoreTend** — the name the project owner selected and approved. Its
   status is recorded honestly below: approved for local engineering work,
   **not** researched for publication.

Full raw evidence in `Documentation/BRAND_SEARCH_EVIDENCE.md`; overall
verdict in `Documentation/BRAND_NAME_CLEARANCE.md`; machine-readable status
in `Documentation/brand-name-clearance.json`.

## 1. MacClear — abandoned candidate (historical)

| ID | Conflict | Severity | Type | Same category? | Status |
|---|---|---|---|---|---|
| BC-001 | `github.com/Matcha00/MacClear` — SwiftUI macOS cleaner: caches, logs, dev caches, downloads, temp files, Trash, large/old files, duplicates, app leftovers, system caches. Trash-default deletion, risk-tiered auto-select, FDA instructions. | **HIGH** | Prior software usage, exact name, same platform+framework+category | Yes — near-exact functional and technical twin | CLOSED — candidate abandoned |
| BC-002 | `github.com/zhangyandong/MacClear` — Mac disk-cache-clearing tool | MEDIUM | Prior software usage, exact name | Yes — cache cleaning | CLOSED — candidate abandoned |
| BC-003 | `github.com/bistaalish/macclear` — Mac cleaning script | MEDIUM | Prior software usage, exact name (lowercase) | Yes — Mac cleaning | CLOSED — candidate abandoned |
| BC-004 | `macclear.com` — registered domain, blocklisted by AdGuard's HostlistsRegistry, broken/hostile TLS on direct connect | MEDIUM | Domain reputation risk | N/A (not software) | CLOSED — candidate abandoned |
| BC-005 | User-supplied claim: a "MacClear" app since 2018 for uninstalling apps + cleaning residuals | **UNVERIFIED** | Prior software usage (claimed) | Yes, if real | CLOSED — candidate abandoned |
| BC-006 | Adjacent names already in the same functional space, found incidentally: "MacClean" (MacUpdate, since ≥2019), "MacCleanse", "MacCleaner Pro", "MacClean360", "MacSai" | LOW-MEDIUM (name-confusion risk) | Prior software usage, phonetically/visually adjacent names | Yes | Informational — this is precisely the cluster the new name had to escape |

### Aggregate read (historical)

Three independent, real, exact-name "MacClear"/"macclear" software
repositories existed in the identical product category, one of them
(BC-001) close enough in tech stack and feature list that it read like a
near-twin. Per the project's non-negotiable decision rule
(`BRAND_NAME_CLEARANCE.md` §5), confirmed prior software usage in the same
category is sufficient for CONFLICT_HIGH on its own. The candidate was
dropped.

## 2. CoreTend — approved name

| ID | Item | Severity | Type | Status |
|---|---|---|---|---|
| CT-001 | No trademark-registry search has been run for the approved name in any jurisdiction. | UNKNOWN | Missing research | PENDING — blocks publication only, tracked in `brand-name-clearance.json.outstandingForPublication` |
| CT-002 | No prior-software-usage search has been run for the approved name (GitHub, app stores, package registries). | UNKNOWN | Missing research | PENDING — blocks publication only |
| CT-003 | Product site is a subdomain of the owner's existing root domain, so no domain acquisition and no domain-reputation exposure. | NONE | Domain | RESOLVED — subdomain of `ahmetbsbnr.com` |
| CT-004 | Name is not adjacent to the "MacClean / MacCleaner / MacCleanse" cluster and does not begin with "Mac", so BC-006's confusion risk does not carry over. | NONE | Name confusion | RESOLVED |

### Aggregate read

The approved name carries a **known unknown**, not a known conflict. No
conflict has been found because no search has been run — that distinction
is deliberately preserved rather than papered over. The consequence is
encoded in the gate: `Scripts/check-brand-clearance.sh --engineering`
passes, `--publication` does not, and it will keep failing until
`legalReviewStatus` is `accepted` in the local approval record.

> **Updated 2026-07-25.** A preliminary automated screening has since been run.
> §2 above is preserved as the 2026-07-24 record; see §3 below for the outcome.
> CT-002 is now partially discharged; **CT-001 is not.**

## 3. CoreTend — 2026-07-25 preliminary automated screening

Source of these rows: `Documentation/CORETEND_TRADEMARK_SCREENING.md` and
`Documentation/coretend-trademark-screening.json`. Screening status:
**`REVIEW_REQUIRED`**. Performed by an automated agent, not a lawyer. Not a
clearance, not a legal opinion, not a guarantee. Nothing was filed, nothing was
paid for.

| ID | Item | Severity | Type | Same category? | Status |
|---|---|---|---|---|---|
| CT-005 | `coretend.com` is registered to an unidentified third party — created 2026-03-18, expires 2027-03-18, `client transfer prohibited`, registrar Hosting Concepts B.V. d/b/a Registrar.eu, NS `dyna-ns.net`. The domain **does not resolve**: no A record, no website, not indexed. | **MEDIUM** | Third-party domain holding; parked speculation *or* an unlaunched project — the evidence does not distinguish | **Unknown** — no product visible, so no category can be assigned | **OPEN** — needs a human WHOIS / registrant investigation. Do not contact the registrant before taking advice. |
| CT-006 | GitHub account `coretendency` exists (found via `api.github.com/search/users?q=coretend`). Public repository list came back **empty**. | NONE | Handle adjacency, different word ("core tendency") | No | INFORMATIONAL — logged for completeness, not a conflict |
| CT-007 | `CoreTrend` — a one-letter phonetic neighbour — is in use by at least three unrelated parties: a New Delhi enterprise/digital-marketing services firm (founded 2024), `CoreTrend Pro` (a TradingView trading indicator at `coretrendpro.com`), and `CoreTRM` (commodity/oil-trading CTRM SaaS). | LOW | Phonetic / visual name confusion | No — marketing services, trading indicators, commodity SaaS | INFORMATIONAL — different word, no category overlap; noted so a future professional search covers the neighbourhood |
| CT-008 | GitHub **code** search (as distinct from repository-name search) requires authentication and was not run. A same-category project using the string internally without naming its repo `coretend` would not have been caught. | UNKNOWN | Search-coverage gap | Unknown | **OPEN** |
| CT-009 | **No official trademark register was queryable.** TMview (POST-only, `ECONNRESET`), EUIPO eSearch plus (JS SPA), INPI (403), WIPO Global Brand Database (CAPTCHA), USPTO TMsearch (JS SPA), UKIPO (DNS failure, then 403), plus all secondary mirrors (Justia, Trademarkia, uspto.report — all 403). Nice classes 9 and 42 were therefore never searched. | **UNKNOWN** | Missing research — tool limitation, not a finding | Unknown | **OPEN** — this is CT-001, unchanged and still blocking. An unreachable registry is neutral evidence, never exculpatory evidence. |
| CT-010 | Prior-software-usage search **was** run and came back with no exact-name hit anywhere reachable: GitHub repos `total_count 0`, `github.com/coretend` 404, no CoreTend org, GitLab empty, npm `total 0`, PyPI 404, Homebrew formula 404, Homebrew cask 404, Apple App Store Search API (`entity=macSoftware`) `resultCount 0`. Variants `Coretend` / `CORE TEND` / `Core Tend` / `Core-Tend` / `CoreTendo` / `KoreTend` also returned nothing. | NONE FOUND | Prior software usage | No exact-name user found in any category | **PARTIALLY DISCHARGES CT-002** — via authoritative APIs, not via a lawyer. Platform-native search on Product Hunt, MacUpdate, Gitee and SourceForge was reached only through a web index, and no non-Latin/phonetic variants were screened, so CT-002 is narrowed rather than closed. |
| CT-011 | **Same-category check (macOS cleanup / storage / disk space / malware / system maintenance): no exact or near-exact conflict found.** Category-scoped web search returned only the incumbents (CleanMyMac, MacKeeper, MacBooster, OnyX, CCleaner, Avast Cleanup); Apple's own search API and the Homebrew casks API both returned nothing. | NONE FOUND | Prior software usage, same category | **No same-category conflict found** | **NO CONFLICT_HIGH TRIGGER.** The project's rule — confirmed prior software usage in the same category is `CONFLICT_HIGH` on its own — is **not** tripped, because no such usage was confirmed. This says nothing about usage the tools could not see. |

### Aggregate read (2026-07-25)

The category that killed the previous candidate is, on this evidence, empty:
there is no `CoreTend` macOS maintenance utility on GitHub, GitLab, npm, PyPI,
Homebrew, the Mac App Store, or in the public web index, and the negative
results came from those platforms' own authoritative APIs rather than from a
search engine's guess. `CoreTend` also stays clear of the `Mac*` cleaner
cluster (BC-006), so CT-004 still holds.

What has **not** moved is CT-001. Zero of six target trademark registers could
be queried, so classes 9 and 42 remain entirely unexamined, and one substantive
question is now open that was not open before — who holds `coretend.com` and
why (CT-005).

Net effect on the gate: **unchanged**. `REVIEW_REQUIRED` is not the `accepted`
that `Scripts/check-brand-clearance.sh --publication` waits for.
`legalReviewStatus` must not be flipped on the strength of this screening. What
the screening does support is publishing the **free, unsigned, open-source
beta** under the name with **no `®`** and **no claim of registration or
clearance** anywhere — and nothing beyond that. Commercial use, a `®`, or any
registration claim needs a paid professional search by a human attorney across
EUIPO, INPI, UKIPO, USPTO and WIPO in classes 9 and 42, including similarity
searching.

## 3. CoreTend — official register screening, 2026-07-27

Status of the name after the official registers were finally reached:
**`PRELIMINARY_CLEARANCE_NO_HIGH_CONFLICT_FOUND`** (was `REVIEW_REQUIRED`).

TMview — aggregating ~80 offices including EUIPO, INPI, USPTO, WIPO and UKIPO —
returned **zero marks containing `coretend`** across 141 856 516 records.
Full method and raw results: `BRAND_SEARCH_EVIDENCE.md`, section 2026-07-27.

### Status vocabulary (closed set)

`Scripts/check-brand-clearance.sh` reads these tokens. Every row below carries
exactly one, and the meanings are fixed:

| Token | Meaning | Blocks the gate? |
|---|---|---|
| `BLOCKING` | A real conflict. The name must not be used for this purpose. | **Yes — both engineering and publication.** |
| `OPEN` | Legacy token, retained so pre-existing rows keep their force. Treated as `BLOCKING`. | **Yes.** |
| `WATCH` | Recorded, understood, and judged not to bar a free unsigned beta — but it carries a named condition that must be met before a stated future step (typically commercial use or a trademark filing). | No. Surfaced, not blocking. |
| `INFORMATIONAL` | Noted for completeness; no action implied. | No. |
| `CLOSED` | Resolved or abandoned. | No. |

`WATCH` is not a softer way of writing `BLOCKING`. It exists because the earlier
single-token scheme could only say "unresolved", which forced genuinely
non-blocking observations (an adjacent mark in a different industry, a parked
domain the project does not need) to read as though they barred publication. Each
`WATCH` row must state its condition explicitly, and those conditions are
restated as standing rules at the end of this section.

| ID | Conflict | Severity | Type | Same category? | Status |
|---|---|---|---|---|---|
| BC-101 | `COREXTEND` — MIPS Tech, LLC. **Live registrations in class 9**: EUIPO 003170149, UKIPO UK00903170149. Also USPTO 78189735 (closed, Imagination Technologies), JPO 2003035267 (expired), ILPO 164176 (closed), MOIP KR 4020030019740 (closed). One letter from CORETEND. Field of use is embedded-CPU instruction-set extension IP licensed to chip designers — not consumer macOS software. | **WATCH** | Registered mark, class 9, adjacent spelling | No — semiconductor IP vs. consumer macOS maintenance app | **WATCH.** Not blocking a free unsigned beta. Condition: attorney review required before filing, before any commercial use, and before any move into embedded/processor-adjacent tooling. |
| BC-102 | `COREXTENDER` — Double E Company, LLC. USPTO 88606735 and 97796314, class 7, both closed. | LOW | Closed applications, unrelated class | No | Informational — closed, class 7 (machines). |
| BC-103 | `TENDCORE CONSULTING` / 腾诺咨询 — CNIPA 15317472 (cl. 41) and 15317311 (cl. 35), registered. Element order reversed; consulting services. | LOW | Registered mark, reversed elements | No — consulting services | Informational. |
| BC-104 | `XRCORE` — Matrixed Reality Technology Co., Ltd. USPTO 90538739 (cl. 35/9), 90977209 (cl. 9), registered. Shares only the `core` element. | LOW | Registered mark, shared common element | No | Informational — `core` is a weak, widely-used element in class 9. |
| BC-105 | Romance-language token coincidences: `NutriCore atendimento`, `CORES & TENDÊNCIAS`, `ATENDACOREN`, `Tendências Decor`, `NO LO ENTENDERÍAS CORE`, `contendo as cores`. `tend` is a fragment of ordinary words (*atendimento*, *tendências*, *entenderías*, *contendo*). | NONE | Search-tokenisation artefact | No | Closed — not conflicts. |
| BC-106 | `coretend.com` — third-party registered/parked domain, surfaced 2026-07-25, appearing in a bulk domain listing alongside `coreten*` architecture/fitness domains (Corten steel cluster). No software product, no content, no trademark record found. | LOW-MEDIUM | Domain occupancy | No — not software | **WATCH.** Condition: revisit only if the apex domain is ever wanted. The project ships on `coretend.ahmetbsbnr.com`, a subdomain it already controls, so this does not affect the launch. |

### Software-channel occupancy — all clear (2026-07-27)

| Channel | Result |
|---|---|
| GitHub repositories | 0 |
| GitHub users/orgs | 1 unrelated (`coretendency`) |
| npm | 0 |
| PyPI | 404 |
| Homebrew formula / cask | 404 / 404 |
| Mac App Store (macSoftware) | 0 |

No prior software use of the name CoreTend exists in any channel checked.
`github.com/ahmetbsbnr/coretend` is available.

### Standing rules while BC-101 is open

1. Never use `®` with CoreTend. Never state or imply the name is registered.
2. Never describe the name as "legally cleared", "validated", or "protected".
3. Attorney review of `COREXTEND` is required before: filing in class 9 or 42,
   charging money for the software, or entering embedded/semiconductor tooling.
4. Re-run the TMview queries before any 1.0 commercial release; new filings appear
   continuously and this register is a snapshot, not a subscription.
