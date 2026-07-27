# Brand Search Evidence — "MacClear"

Raw, dated findings from this session's research. Every entry below is a
real search result or fetch, not inference. Search performed via
`mcp__web__web_search` (DuckDuckGo-backed) on **2026-07-24**. Snippets are
short by design (tool constraint) — where a full page was fetched, that is
noted.

**Tool limitation, stated honestly**: this session's web-search tool
returns search-engine snippets and can fetch individual static pages; it
cannot execute the JavaScript-driven search UIs of EUIPO eSearch Plus,
TMview, INPI DATA, WIPO Global Brand Database, UKIPO, or USPTO TESS/TMsearch
— those return an empty/generic shell to a plain HTTP fetch. Every attempt
at these registries is logged below as INCONCLUSIVE_TOOL_LIMITATION, not
as "no conflict found." A real clearance search requires either those
sites' own search forms (interactive) or a paid clearance-search service —
this is exactly why Section 5's decision rule treats confirmed prior
software usage as sufficient for CONFLICT_HIGH on its own, without waiting
on registry access this tool cannot provide.

## Software usage — exact name "MacClear" / "macclear"

| # | Finding | Source | Date seen | Category match |
|---|---|---|---|---|
| 1 | `github.com/Matcha00/MacClear` — "MacClear 一个轻量的原生 macOS 清理工具，使用 SwiftUI 编写" (a lightweight native macOS cleaning tool, written in SwiftUI). Scans caches, logs, dev caches, download leftovers, temp files, Trash items, large/old files, duplicate files, app leftovers, system-level caches/logs. Default = Trash-based deletion, low-risk items auto-selected, high-risk shown but not auto-selected, Full Disk Access instructions included. Repo has 2 commits, 0 stars/forks/watchers as of fetch. | Direct GitHub fetch (full README read) | 2026-07-24 (repo's own reference date implies very recent, 2026) | **Extremely close** — same platform (macOS), same UI framework (SwiftUI), same category (cleaner), near-identical feature list (caches/logs/dev-caches/downloads/temp/trash/large-old/duplicates/app-leftovers/system-caches), same safety posture (Trash-default, risk-tiered auto-select) |
| 2 | `github.com/zhangyandong/MacClear` — "一个Mac清除磁盘缓存小工具：MacClear" (a Mac disk-cache-clearing tool: MacClear) | Search snippet | 2026-07-24 | Close — disk cache cleaning utility for Mac |
| 3 | `github.com/bistaalish/macclear` — "Script to Clean the Offline Mac from..." | Search snippet | 2026-07-24 | Close — Mac cleaning script |
| 4 | `macclear.com` appears in AdGuard's `HostlistsRegistry` filter list (`filter_27.txt`) — a maintained ad/tracker/malicious-domain blocklist | Search snippet, confirmed via direct fetch attempt | 2026-07-24 | Not a software-category match, but a **negative domain-reputation signal**: the domain is registered, live enough to be blocklisted, and its HTTPS endpoint returned `TLSV1_ALERT_INTERNAL_ERROR` on direct connection attempt this session (broken/hostile TLS config consistent with a parked-and-monetized or previously-compromised domain) |

**User-supplied claim not independently reproduced**: the brief describes a
"MacClear" software product "existing since at least 2018... uninstalling
apps... cleaning residual files" — this session's tool did not surface an
exact match to that specific description (no App Store listing, no
MacUpdate/ProductHunt page titled exactly "MacClear" was found). This does
**not** clear the name — three independent real "MacClear"/"macclear"
software repositories were found regardless (rows 1-3 above), one of which
(row 1) is a closer functional/technical match than an uninstaller would
even be. The original claim should be treated as **unverified but not
contradicted** — a professional clearance search may well surface the
specific product referenced.

## Domain checks (existence only — nothing purchased or reserved)

| Domain | Method | Result |
|---|---|---|
| `macclear.com` | Search snippet (AdGuard blocklist) + direct HTTPS fetch | **Registered, live** — blocklisted by at least one ad/tracker registry; TLS handshake fails (`TLSV1_ALERT_INTERNAL_ERROR`) on direct connection. Negative signal, not simply "taken." |
| `macclear.dev` | Direct fetch | **DNS does not resolve** (`nodename nor servname provided`) — consistent with unregistered, not independently confirmed via a registrar/WHOIS lookup |
| `macclear.app`, `macclear.io`, `macclear.fr`, `macclear.eu`, `macclear.ahmetbsbnr.com` | Not checked this session (time-boxed) | UNKNOWN — needs a follow-up pass or a real WHOIS/registrar check before any purchase decision |
| `github.com/macclear` (user/org handle) | Direct fetch | **HTTP 404** — handle appears free at the account-name level (does not affect the three existing repos named "MacClear"/"macclear" under *other* users' accounts, rows 1-3 above, which remain real prior-art regardless of who owns the top-level handle) |

## Trademark registries — attempted, not conclusively queryable this session

| Registry | Attempt | Result |
|---|---|---|
| EUIPO eSearch Plus | Search query | Returned only the registry's own homepage/about text, not search results — **INCONCLUSIVE_TOOL_LIMITATION** |
| TMview | Not separately queryable via this tool | **NOT ATTEMPTED — requires interactive form** |
| INPI DATA | Not separately queryable via this tool | **NOT ATTEMPTED — requires interactive form** |
| WIPO Global Brand Database | Search query | Returned only the registry's own homepage/about text — **INCONCLUSIVE_TOOL_LIMITATION** |
| UKIPO | Not attempted (lower priority, no confirmed UK-specific distribution plan) | **NOT ATTEMPTED** |
| USPTO TESS/TMsearch | Search query | Returned only the registry's own homepage/about text — **INCONCLUSIVE_TOOL_LIMITATION** |

None of the above can be treated as "searched and clear." They are
**unqueried** by this session's tooling — see `BRAND_NAME_CLEARANCE.md` for
how this feeds the final status.
