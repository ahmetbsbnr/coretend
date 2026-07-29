<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Licensing

The licence map for this repository. `LICENSE` at the root is the verbatim,
unmodified Apache-2.0 text and nothing else, so automated detectors — GitHub's
included — identify the project's principal licence correctly. The preamble
that used to sit above that text lives here instead.

**Nothing was relicensed when this moved.** Every licence and every scope below
is exactly what was already declared. The change is presentational.

## What applies to what

| Content | Licence | Full text |
|---|---|---|
| Source code — `*.swift`, `*.sh`, `*.py`, build configuration | **Apache-2.0** | `LICENSE`, and `LICENSES/Apache-2.0.txt` |
| Original documentation — `Documentation/`, `*.md` authored here | **CC-BY-4.0** | `LICENSES/CC-BY-4.0.txt` |
| Original illustrations and brand assets — app icon, menu-bar templates, favicons, lockups, Open Graph card, DMG background, SVG/PDF sources | **CC-BY-4.0** | `LICENSES/CC-BY-4.0.txt` |
| Screenshots in `Documentation/VisualAudit/` | **CC-BY-4.0** | `LICENSES/CC-BY-4.0.txt` |
| Generated data files — `Documentation/*.json`, `*.csv` produced by scripts in `Scripts/` | Same licence as the script that generates them: **Apache-2.0** | `LICENSE` |
| The name "CoreTend" and its logo | **Not granted by either licence** | `TRADEMARKS.md` |
| Third-party components | Their own upstream licences | `THIRD_PARTY_NOTICES.md`, `Documentation/DEPENDENCIES.md` |

Unless a file states otherwise, source code is under Apache-2.0.

## Third-party position

There is no bundled third-party code. `Package.swift` declares **zero external
package dependencies**, so nothing is vendored and nothing is redistributed.

The one external component is **ClamAV**, and it is not bundled: if a user
installs it themselves, CoreTend can execute the `clamscan` binary as a separate
process. It is never linked, its signature database is never shipped, and
GPL-2.0's copyleft therefore does not reach anything this project distributes.
See `Documentation/CLAMAV_DECISION.md`.

Apple system frameworks and the system SQLite are linked from the OS and are
not redistributed here.

## Files whose licence status is unknown

**None identified.** Every tracked asset traces either to project code that
generates it or to the application itself.

No licence has been invented for any file. If a file of genuinely unknown
origin is ever added, it must be recorded here as unknown rather than assigned
a plausible licence.

## SPDX identifiers

SPDX headers are present where their scope has been verified, and are not added
speculatively. Coverage is currently partial and is tracked as an open finding
in `Documentation/LEGAL_AND_LICENSE_STATUS.md` — Apache-2.0 is satisfied by the
root `LICENSE`, so the absent headers are a convenience gap, not a compliance
one. A file carrying a header states its own licence; a file without one falls
under the table above.

## Attribution

Apache-2.0 §4(d) requires `NOTICE` to travel with redistributed copies. It ships
inside the release ZIP alongside `LICENSE` and `THIRD_PARTY_NOTICES.md`, which
the final launch gate verifies on every run.

CC-BY-4.0 requires attribution for the documentation and illustrations. All of
that material is original to this project, so the obligation runs to downstream
reusers rather than to this repository.

## See also

- `LICENSE` — verbatim Apache-2.0
- `LICENSES/` — full texts, named by SPDX identifier
- `NOTICE`, `COPYRIGHT` — attribution and copyright statements
- `TRADEMARKS.md` — name and logo, excluded from both licence grants
- `Documentation/LEGAL_AND_LICENSE_STATUS.md` — the licence audit, its findings and open risks
- `Documentation/DEPENDENCIES.md` — dependency matrix
