# CoreTend Agent Handoff

## Git
- Current branch: `feat/privacy-lab` (created from `feat/developer-center` HEAD `6d5ad2e`)
- Current HEAD: `d729118`
- Commits on this branch: `c4ea82f` (feat), `7151e19` (test), `d729118` (docs)
- Working tree: clean for tracked files. Pre-existing untracked agent
  scaffolding (`AGENTS.md`, `CLAUDE.md`, `.agents/`, `.codex/`,
  `.agent-setup-backups/`, `Documentation/AGENT_HANDOFF.md`,
  `Documentation/AGENT_OPERATING_CONTRACT.md`) predates this session and was
  not created or committed here.
- Not pushed. Not merged. `main` untouched. No history rewrite.
- `feat/developer-center` preserved unchanged as a checkpoint.

## Completed — Privacy Lab minimal vertical (read-only image metadata inspection)
- `Sources/SystemMetrics/ImageMetadataInspector.swift` — pure ImageIO domain
  (`ImageMetadataInspector`, `ImageMetadataInspection`, `MetadataField`,
  `MetadataFinding`, `MetadataPresence`, `PreciseLocation`,
  `ImageMetadataCategory`).
- `Sources/CoreTendApp/PrivacyLabService.swift` — `PrivacyLabService.live`
  (detached utility task), `PrivacyLabCatalog` (localized titles/why),
  `PrivacyLabSummary` (counts, no score).
- `Sources/CoreTendApp/PrivacyLabView.swift` — `PrivacyLabViewModel`
  (generation-token stale guard) + `PrivacyLabView`.
- Navigation: `ModuleID.privacyLab` in `CoreTendApp.swift` (system sidebar
  group, before `.protection`); `MCModuleIdentity.privacyLab` in
  `DesignSystem/Components.swift`.
- Localization: 61 keys added to both `Base.lproj` and `fr.lproj`
  (`module.privacy_lab` + 60 `privacylab.*`). Parity verified (878 == 878).
- Tests: `Tests/SystemMetricsTests/ImageMetadataInspectorTests.swift` (21),
  `Tests/CoreTendAppTests/PrivacyLabTests.swift` (9),
  `Tests/CoreTendAppTests/PrivacyLabLocalizationTests.swift` (3);
  `CommandPaletteTests` expected-order updated.
- Docs: new `Documentation/PRIVACY_LAB.md`; updated `SAFETY_MODEL.md`,
  `FEATURE_MATRIX.md`, `PRIVACY.md`, `Documentation/PRIVACY.md`, `TODO.md`,
  `PROJECT_STATE.json` (tests 562; Developer Center entry backfilled).

## In progress
- None.

## Not started (intentionally out of scope for this vertical)
- Sanitized-copy / metadata-strip export. The layering leaves a clean seam
  (`original → read → sanitized copy → verify → compare → preserve
  original`) but no mutation exists. A future op must prefer "create
  sanitized copy" over "modify original".
- XMP packet parsing, batch/folder inspection, exhaustive per-format tag
  dumps.

## Architecture decisions made
- Read-only technical facts get **no** `RiskLevel` and **no**
  `AdvisorFinding` — same principle APFS Intelligence established. Not
  Recovery-Plan-eligible by construction.
- Three-state `MetadataPresence` (present / notDetected /
  unavailable(reason)); "not detected" is never rendered as "safe".
- No privacy score — `PrivacyLabSummary` is counts + honest headline.
- GPS: coarse in main UI; exact coords behind opt-in; no reverse geocoding;
  never persisted.
- Domain lives in `SystemMetrics` (alongside `APFSVolumeInspector`), pure,
  SwiftUI-free.

## Contracts that must not change
- See `Documentation/AGENT_OPERATING_CONTRACT.md` and
  `Documentation/SAFETY_MODEL.md` → "Privacy Lab".
- Privacy Lab stays entirely read-only w.r.t. the user's image.
- Nothing from Privacy Lab is persisted or logged.
- Developer Center + all prior verticals' contracts unchanged.

## Verification (at HEAD d729118)
- Build: `Scripts/build.sh` (debug) and `Scripts/build.sh release` — both
  `Build complete!`, no warnings.
- Tests: `Scripts/test.sh` — 562 passed, 0 failing.
- Repository doctor: `Scripts/repository-doctor.sh` — all checks passed.

## Known limitations / HUMAN VERIFICATION REQUIRED
- Interactive VoiceOver / keyboard / focus-order / Dynamic Type on the live
  Privacy Lab screen: **HUMAN VERIFICATION REQUIRED** — structural semantics
  are in place (headers, identifiers, `MCStatusBadge` text+icon, standard
  controls, opt-in `Toggle`) but not interactively exercised here.
- PNG GPS/Exif round-trip depends on the host OS ImageIO version; the test
  asserts graceful "Not detected" when it does not survive.
- HEIC fixture is skipped on hosts without an HEVC encoder.

## Next concrete action
- None required for this vertical. If continuing: a future Restore Center is
  analyzed (not implemented) at the end of the final report; and a
  sanitized-copy export would build on the seam noted above.
