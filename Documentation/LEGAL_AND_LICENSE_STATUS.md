# Legal & License Status — Session 2

Evidence: `ls`/`cat`/`grep` on `LICENSE`, `LICENSES/`, `TRADEMARKS.md`, `Documentation/THIRD_PARTY.md`,
`Documentation/ASSET_PROVENANCE.md`, `Documentation/DEPENDENCIES.md`. Factual inventory only, no legal advice.

## Files verified to exist (not assumed)

| File | Exists | Content |
|---|---|---|
| `LICENSE` (repo root) | Yes | States source code (`*.swift`, `*.sh`, build config) = Apache-2.0, full Apache-2.0 text follows in the same file |
| `LICENSES/Apache-2.0.txt` | Yes | Full Apache-2.0 text |
| `LICENSES/CC-BY-4.0.txt` | Yes | Full CC-BY-4.0 text |
| `TRADEMARKS.md` (repo root) | Yes | "MacCare Local" name/logo not covered by code/doc licenses; nominative-use terms; explicit statement of non-affiliation with Apple/MacPaw ("not a CleanMyMac clone") |
| `Documentation/THIRD_PARTY.md` | Yes | Declares zero SwiftPM deps; ClamAV (GPLv2, external subprocess, never linked) and system SQLite as the only runtime integrations |
| `Documentation/ASSET_PROVENANCE.md` | Yes | App icon, menu-bar icon, design tokens all declared original/in-repo-generated; no bundled fonts (system SF Pro only); no third-party stock imagery found |
| `Documentation/DEPENDENCIES.md` | Yes | Corroborates zero external SwiftPM packages; ClamAV entry matches THIRD_PARTY.md |

## Files LICENSE references but that do NOT exist — real inconsistency, found this session

`LICENSE:4` says "See Documentation/LICENSING.md for the full breakdown" — **`Documentation/LICENSING.md` does
not exist** (`find` over the tracked tree returns nothing).
`LICENSE:11` says third-party notices are in "THIRD_PARTY_NOTICES.md" — **no file by that exact name exists**;
the actual content lives in `Documentation/THIRD_PARTY.md` (different filename, no path prefix given in
`LICENSE` either). This is a genuine, reproducible broken-reference defect: a reader following `LICENSE`'s own
pointers hits two dead links. Low legal risk (the actual license terms are still present and internally
consistent — Apache-2.0 for code, CC-BY-4.0 for docs/art, both texts inline/adjacent) but a real documentation
defect worth fixing: either create `Documentation/LICENSING.md` + rename/symlink `THIRD_PARTY.md` to
`THIRD_PARTY_NOTICES.md`, or edit `LICENSE`'s two references to point at the files that actually exist.

## SPDX headers

`grep -rl "SPDX-License-Identifier" Sources/` → **0 files**. No per-file SPDX headers exist anywhere in
`Sources/`. Not a defect per se (a repo-root `LICENSE` file is legally sufficient under Apache-2.0), but it
means license provenance for an individual `.swift` file extracted in isolation (e.g. copy-pasted elsewhere)
would not travel with the file. Flag only, no severity assigned (factual inventory, not legal advice).

## Dependency / asset provenance summary (consolidated from existing docs, not invented)

- **Zero external SwiftPM dependencies** (`Package.swift` has no `.package(url:...)` entries) — confirmed
  session 1 architecture inventory and re-confirmed by reading `Documentation/DEPENDENCIES.md` this session.
- **ClamAV (`clamscan`)**: optional, user-installed, GPL-2.0, invoked as an external subprocess only — never
  linked, vendored, or redistributed. Consistent between `THIRD_PARTY.md` and `DEPENDENCIES.md`.
- **System SQLite (`libsqlite3`)**: Apple-provided system library, not bundled.
- **Fonts**: none bundled; system SF Pro only (per `ASSET_PROVENANCE.md`).
- **App icon / design tokens / menu-bar icon**: declared original work generated in-repo, CC-BY-4.0 for the
  visual assets, Apache-2.0 for the generating code — internally consistent split.
- **Screenshots**: incomplete "After" set is an openly-documented completeness gap (`ASSET_PROVENANCE.md`,
  `KNOWN_LIMITATIONS.md`), not a provenance/licensing problem.

## Trademark

`TRADEMARKS.md` exists and explicitly disclaims affiliation with Apple Inc. and MacPaw Inc., and states the
name/logo are excluded from the Apache-2.0/CC-BY-4.0 grants. Internally consistent with `LICENSE`'s carve-out
language.

## Unresolved legal placeholders found this session

1. The two broken `LICENSE` cross-references above (`Documentation/LICENSING.md`, `THIRD_PARTY_NOTICES.md`).
2. No SPDX headers in source files (flag only, not necessarily a defect).

No other placeholder text (`TODO`, `[FILL IN]`, `Lorem ipsum`, `Your Name Here`) was found in `LICENSE`,
`LICENSES/*.txt`, `TRADEMARKS.md`, `Documentation/THIRD_PARTY.md`, or `Documentation/ASSET_PROVENANCE.md`
during this session's reads.

This is a factual inventory only — no legal advice or opinion on enforceability is given.
