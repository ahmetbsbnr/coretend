<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Legal & License Status

Licence audit for the 0.9.0 public beta. Factual inventory only — **no legal
advice and no opinion on enforceability is given.**

Last verified: 2026-07-27, on the 0.9.0 release commit.
Evidence: `git ls-files`, `git grep`, `Scripts/check-licenses.sh`,
`Package.swift`, and direct reads of every file named below.

## 1. Project licence

The repository is multi-licensed by content type. This is deliberate and is
declared in `LICENSE`, which carries the full Apache-2.0 text inline.

| Content | Licence | Full text |
|---|---|---|
| Source code (`*.swift`, `*.sh`, `*.py`, build configuration) | Apache-2.0 | `LICENSES/Apache-2.0.txt`, and inline in `LICENSE` |
| Original documentation and illustrations | CC-BY-4.0 | `LICENSES/CC-BY-4.0.txt` |
| The name "CoreTend" and its logo | **Not granted** by either licence | `TRADEMARKS.md` |

The licence type has not been changed by this audit and must not be changed
without the owner's explicit instruction.

Declaration files present at the repository root, all verified to exist:
`LICENSE`, `NOTICE`, `COPYRIGHT`, `THIRD_PARTY_NOTICES.md`, `TRADEMARKS.md`,
and the `LICENSES/` directory. `Scripts/check-licenses.sh` gates their
presence and passes.

## 2. Dependencies

**Zero external SwiftPM packages.** `Package.swift` declares no
`.package(url:…)` entry; every target is first-party code in this repository.
`check-licenses.sh` asserts this and will start failing on purpose if a
dependency is ever added without `Documentation/DEPENDENCIES.md` being updated.

| Component | Relationship | Licence | Redistributed here? |
|---|---|---|---|
| Apple system frameworks (SwiftUI, Foundation, AppKit, Vision, IOKit, …) | Linked at build time, ship with macOS | Apple platform terms | No |
| System SQLite (`libsqlite3`) | Linked system library provided by macOS | Public domain upstream; Apple-provided build | No |
| ClamAV (`clamscan`) | **Optional.** Invoked as a separate subprocess if the user installed it themselves | GPL-2.0, by the ClamAV project | **No** — not linked, not vendored, not bundled, signature database never shipped |

The ClamAV relationship is the only one with licence-compatibility
significance, and it is the reason the distinction matters: CoreTend does
**not** link `libclamav`. It executes a user-supplied binary through `Process`
with an argument array and parses its output. GPL-2.0 copyleft attaches to
linking and distribution; neither occurs here, and nothing GPL-licensed is
distributed by this project. See `Documentation/CLAMAV.md` and
`Documentation/DEPENDENCIES.md`.

Compatibility conclusion: Apache-2.0 for the distributed work is consistent
with every component above, because the only copyleft component is neither
linked nor distributed.

## 3. Attribution obligations

- **Apache-2.0 §4(d):** `NOTICE` exists and is included in the distributed
  artifacts — `unzip -t` on the 0.9.0 ZIP lists `NOTICE` and
  `THIRD_PARTY_NOTICES.md` among its entries.
- **CC-BY-4.0:** requires attribution for the documentation and illustrations.
  All such material is original to this project, so the obligation runs to
  downstream reusers, not to this repository.
- **ClamAV:** no attribution obligation arises, because nothing of ClamAV's is
  redistributed. `NOTICE` and `THIRD_PARTY_NOTICES.md` nonetheless state the
  optional relationship and disclaim affiliation.
- **Apple / MacPaw:** `NOTICE`, `COPYRIGHT` and `TRADEMARKS.md` each state that
  the project is not affiliated with, sponsored by, or endorsed by either.

## 4. Assets

No third-party stock imagery, icon pack, or font is bundled anywhere in the
repository.

| Asset class | Origin | Status |
|---|---|---|
| Brand assets (app icon 16–1024 + `.icns`, menu-bar templates, favicons, lockups, Open Graph card, DMG background, SVG/PDF sources) | Generated in-repo from project-authored geometry, per `Documentation/ASSET_PIPELINE.md`; `Scripts/check-brand-assets.sh` gates this and passes | Original work |
| Screenshots (`Documentation/VisualAudit/`) | Captured from the app itself | Original work; the "After" set is incomplete because this environment has no display session — a completeness gap, not a provenance one |
| Fonts | **None bundled.** The app uses the macOS system font via SwiftUI defaults; the website uses only system font stacks (`-apple-system`, `ui-monospace`, …) | Nothing redistributed, so no font licence obligation arises |
| Website external requests | **Zero.** Every URL in the generated HTML is on the site's own domain; `Scripts/check-website.sh` enforces this | No third-party asset delivery, no CDN, no webfont |

## 5. Items whose origin is unknown

**None identified.** Every tracked non-code asset traces to either project code
that generates it or the app itself. This is a statement about what the audit
found, not a guarantee that no unknown-origin file can exist.

## 6. Findings and risks

| # | Finding | Severity | Status |
|---|---|---|---|
| 1 | `COPYRIGHT`, `NOTICE` and `THIRD_PARTY_NOTICES.md` pointed at `Documentation/LICENSING.md` and `Documentation/THIRD_PARTY_AUDIT.md`, neither of which has ever existed. A reader following the project's own licence pointers hit dead references. | Low legal risk — the operative terms were always present and internally consistent — but a real defect | **Fixed** in this audit; all three now point at files that exist. `LICENSE` itself was already correct. |
| 2 | SPDX per-file headers are sparse and inconsistent: 2/86 `.swift`, 5/44 `.sh`, 0/4 `.py`. | Not a defect under Apache-2.0, which is satisfied by the root `LICENSE`. The consequence is narrow: a single file copied out of the repository in isolation carries no licence marker with it. | **Open, accepted for 0.9.0.** Recorded rather than fixed, because mass-adding headers is churn unrelated to this release. Worth completing before encouraging code reuse. |
| 3 | Historical audit documents still name `LICENSING.md` and `THIRD_PARTY_AUDIT.md` when recording finding #1. | None | **Intentional.** Those documents record the defect; rewriting them would falsify the record. |
| 4 | `Scripts/check-markdown-links.py` validates Markdown inline links only, so bare in-prose file references — which is exactly how finding #1 was written — are not gated. | Low | **Open.** A gate was not added: many documents legitimately name files that no longer exist when recording history, so such a check would fight the archive rather than protect it. |
| 6 | The website's Licenses page named no licence. It pointed at `LICENSE`, `LICENSES/`, `NOTICE` and `THIRD_PARTY_NOTICES.md` as bare filenames, without stating that the code is Apache-2.0 and the documentation CC-BY-4.0, and without linking to the repository where those files can actually be read. A visitor could not learn the licence from the licences page. | Medium for a public site | **Fixed** — see `WEBSITE_AUDIT.md`. |
| 5 | Trademark: `COREXTEND` (MIPS Tech, live in class 9) is one letter from CoreTend. | Watch | **Open by design.** Not a bar to a free beta. Attorney review is required before any trademark filing or commercial use. See `CORETEND_TRADEMARK_SCREENING.md` and `BRAND_CONFLICT_REGISTER.md`. No definitive legal clearance is claimed. |

## 7. What was checked and found clean

Root licence files present and consistent; `LICENSES/` contains both referenced
texts in full; `README.md` names both licences and links to their texts;
`NOTICE`, `LICENSE` and `THIRD_PARTY_NOTICES.md` all ship inside the release ZIP
(verified with `unzip -l`); zero external SwiftPM dependencies;
no bundled fonts; no third-party imagery; no external network requests from the
website; no placeholder text (`TODO`, `[FILL IN]`, `Lorem ipsum`,
`Your Name Here`) in any licence or trademark file.
