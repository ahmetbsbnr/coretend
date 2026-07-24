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
