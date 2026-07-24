# Brand Conflict Register

Every conflict found during "MacClear" clearance research, in priority
order. Full raw evidence in `Documentation/BRAND_SEARCH_EVIDENCE.md`;
overall verdict in `Documentation/BRAND_NAME_CLEARANCE.md`.

| ID | Conflict | Severity | Type | Same category? | Status |
|---|---|---|---|---|---|
| BC-001 | `github.com/Matcha00/MacClear` — SwiftUI macOS cleaner: caches, logs, dev caches, downloads, temp files, Trash, large/old files, duplicates, app leftovers, system caches. Trash-default deletion, risk-tiered auto-select, FDA instructions. | **HIGH** | Prior software usage, exact name, same platform+framework+category | Yes — near-exact functional and technical twin of MacCare Local | OPEN — unresolved |
| BC-002 | `github.com/zhangyandong/MacClear` — Mac disk-cache-clearing tool | MEDIUM | Prior software usage, exact name | Yes — cache cleaning | OPEN — unresolved |
| BC-003 | `github.com/bistaalish/macclear` — Mac cleaning script | MEDIUM | Prior software usage, exact name (lowercase) | Yes — Mac cleaning | OPEN — unresolved |
| BC-004 | `macclear.com` — registered domain, blocklisted by AdGuard's HostlistsRegistry, broken/hostile TLS on direct connect | MEDIUM | Domain reputation risk | N/A (not software) | OPEN — would need acquisition + reputation remediation even if legally clear |
| BC-005 | User-supplied claim: a "MacClear" app since 2018 for uninstalling apps + cleaning residuals | **UNVERIFIED** | Prior software usage (claimed) | Yes, if real | OPEN — not independently reproduced this session; treat as still-credible, not disproven |
| BC-006 | Adjacent names already in the same functional space, found incidentally: "MacClean" (MacUpdate, since ≥2019), "MacCleanse", "MacCleaner Pro", "MacClean360", "MacSai" (SwiftUI, Swift 6, cleaner+protection+performance — structurally very close to MacCare Local's own module set) | LOW-MEDIUM (name-confusion risk, not "MacClear" itself) | Prior software usage, phonetically/visually adjacent names | Yes | Informational — factor into alternative-name screening (Section 6), avoid landing near this cluster again |

## Aggregate read

Three independent, real, exact-name "MacClear"/"macclear" software
repositories exist in the identical product category (macOS cleanup
utility), one of them (BC-001) close enough in tech stack and feature list
that it reads like a near-twin. Per the project's own non-negotiable
decision rule (`BRAND_NAME_CLEARANCE.md` §5), confirmed prior software
usage in the same category is sufficient for **CONFLICT_HIGH on its own**
— official registry silence (which this session couldn't even establish,
see the tool-limitation note) would not have overridden it, and does not
here.
