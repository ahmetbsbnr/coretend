# CHANGELOG

## 0.8.1 — 2026-07-25 « CoreTend Rebrand & Workspace Migration »

The product is now **CoreTend**. This release is a rename and a reorganisation,
not a feature release — nothing about what the app does changed.

**Renamed everywhere.** Sources, SwiftPM package and targets, executable, app
bundle, resources, both localisations, scripts, CI workflows, documentation,
website, and legal metadata. The bundle identifier moved from
`local.maccare.app` to `com.ahmetbsbnr.coretend`. Four categories deliberately
keep the old name because rewriting them would falsify a record or break a
migration: rename history, historical release artifacts, user-data
compatibility, and the Apache-2.0 licence text.
`Scripts/check-legacy-brand-references.sh` fails on any other occurrence, and an
allowlist entry only counts if it states its reason.

**Your data comes with you.** Renaming a macOS app orphans two independent
classes of local data: the Application Support directory (named by the app) and
the `UserDefaults` domain (named by the OS, keyed to the bundle identifier).
Both migrate on first launch. The migration is copy-only — the previous
version's folder is never modified, renamed, or deleted — which is what makes it
reversible, resumable after an interruption, and safe to run twice. Existing
data under the new identity always wins, so a reinstall over real usage cannot
be clobbered. Failures are reported in Settings, never swallowed. Twenty tests
cover the normal path, the interrupted path, corrupt and unreadable files,
permission failures, rollback, and preference collisions.

**The uninstallers know about both identities.** They leave pre-rename data
alone unless you pass `--include-legacy`, because after a migration that folder
may be your only intact copy.

**Living System.** The palette is now named at its definition, with the
canonical brand values used on dark surfaces and darkened siblings on light
ones — several canonical values measure under 4.5:1 on a near-white surface, and
contrast tests enforce the floor in both directions. A complete asset set is
generated from one set of numbers shared with the app's own Core Bloom
geometry: icon 16–1024, menu-bar templates, favicons, horizontal and compact
lockups in light/dark/single-ink, onboarding hero, Open Graph card, DMG
background, and SVG plus PDF vector sources.

**The site is a real product site.** Bilingual, static, responsive,
keyboard-navigable, light and dark, and it makes **zero external requests** — no
webfont, no CDN, no analytics, no cookies, and after this release no JavaScript
at all. `Scripts/check-website.sh` enforces that, plus locale parity, internal
link integrity, an accessibility floor, and an editorial bar that reads
sentences rather than files so the copy can honestly deny a claim it must not
make.

**Workspace.** Both repositories now live under a shared `WEBSITE/` folder as
two fully independent git repositories, with a gate proving they stay that way.

**Still blocked from publication**, by design and not by omission: no trademark
search has been run for the new name, `legalReviewStatus` is `pending`, and the
legal identity and security contact are undefined.
`Scripts/check-brand-clearance.sh --publication` fails until all three change.

## 0.8.0 — 2026-07-24 « Functional Completion »

Feature-completion phase closing every automatable item in the 21-step
functional-completion plan (`Documentation/FUNCTIONAL_COMPLETION_EXECUTION_PLAN.md`).
Cleanup finalized at 10 built-in rules (caches/logs/crash-reports/DerivedData/
incomplete-downloads/DeviceSupport/iOS-backups/old-installers/old-archives/
Xcode-Archives), with iOS Simulator data, Trash-emptying, Mail attachments, and
broken-LaunchAgent removal deliberately kept out of scope and documented with a
safety rationale rather than shipped as blind extension/age rules
(`REQUIREMENTS_DECISION_HISTORY.md`). The optional Protection FSEvents watch
(debounce/coalesce/dedup/rate-limit, off by default, never auto-quarantines) had
its full 14-scenario test matrix closed. My Clutter gained name search, real
volume awareness (stable `.volumeIdentifierKey`-based identity, never the
display name two drives can share), and UI-exposed exclusions across Large &
Old, Duplicates, and Similar Images — all routed through the existing Store
exclusions table, not a second system. Space Lens and Cloud Cleanup testability
work (navigation logic, provider detection, sync-state classification) and
macOS-14-floor compatibility audit, 9 synthetic stress fixtures, a code-level
accessibility audit, the 8-step first-run wizard, and an animation-safety
verification pass all landed and are documented per-module (new
`APPLICATIONS.md`/`CLOUD_CLEANUP.md`/`MY_CLUTTER.md`/`SETTINGS.md`/
`SPACE_LENS.md`/`FIRST_RUN_STATE_MACHINE.md`/`INSTALLER_EXPERIENCE.md`). Fixed
the last Sendable concurrency warning (0 project warnings in Debug or Release).
215→250 tests. Remaining gaps are honestly tracked, not hidden: interactive
VoiceOver verification and a full FR/EN × light/dark × every-module visual-QA
capture campaign are BLOCKED_ENVIRONMENT (a real display is available and one
verification capture succeeded this phase, but the sidebar-navigation capture
path needs a follow-up fix); public legal identity, security contact, domain,
and code signing/notarization stay BLOCKED_HUMAN. Local version bump only — no
push, no deploy, no public release.

## 0.7.1 — 2026-07-21 « Compliance Hardening »

Audit-and-package repair phase, no feature scope beyond hardening. Real HEAD/commit
fields separated (no more single reused `auditedSourceCommit`); removed a full-desktop
screenshot that had been committed by mistake, recaptured window-only, added a packaging
control script that rejects any screenshot outside its approved manifest; SafetyCore's
audit log is now persisted to SQLite (append-only) instead of in-memory only; Quarantine
records richer metadata (permissions/size/hash/volume) and handles missing
parent/volume/collision/permission-denied cases without ever silently overwriting;
ClamAV wrapper gained a configurable timeout, real cancellation, and an honest
scanned-file count parsed from clamscan's own summary; Privacy Cleaner now disables
cleaning per-profile while that profile's browser is running, with a close-and-rescan
action; fixed three raw, non-adaptive Space Lens colors and consolidated repeated icon
size literals into tokens; added real accessibility support (labels/grouping across 5
previously-unannotated views, Increase Contrast, Differentiate Without Color, and
verified Reduce Transparency) to the design system; CI split into a normal (always-green)
path and a separate manual publish-readiness gate, fixed two real bugs that were
failing CI (a private-data-scan false positive, a dangerous-command-scan false positive),
pinned GitHub Actions to full commit SHAs; corrected a stale feature-inventory summary
that had drifted from the underlying data and made regeneration automatic
(`Scripts/generate-feature-inventory.py`); fixed 4 broken README links and added a
recursive Markdown link validator (0 broken internal links).

## 0.7.0 — 2026-07-20 « Public Distribution »

Full public-distribution gate independently re-verified this session
(all 24 checklist items), not just re-read from prior notes: rebuilt
ZIP/DMG from scratch, extracted/mounted outside the repo, launched and
quit cleanly each; regenerated `Release/SHA256SUMS` and
`Release/latest.json` to match the actual rebuilt artifacts (stale
`sourceCommit` updated to the current HEAD); fixed a real false-positive
in `Scripts/check-private-data.sh` (it was matching its own username
regex pattern as a "leak") and redacted a literal username mention in
`Documentation/PUBLIC_RELEASE_READINESS.md`; re-ran
`test-distribution.sh`, `test-release-manifest.sh`, `test-uninstall.sh`,
`check-version-consistency.sh`, `check-licenses.sh`,
`check-placeholders.sh`, the diagnostic-report redaction test, and the
full 86-test Swift suite — all green. `swift build -c release`: 0
warnings.

- Centralized public release metadata in
  `Configuration/PublicIdentity.example.json` (name/version/bundle-ID/
  repo/site/maintainer/signed/notarized, with bracket-placeholder tokens
  for unknowns) and `Scripts/check-version-consistency.sh`.
- Compatibility audit: `Documentation/COMPATIBILITY.md`,
  `API_AVAILABILITY_AUDIT.md`, `SUPPORTED_MACS.md`,
  `MACOS_VERSION_POLICY.md`. Verified every API used against the macOS
  14.0 deployment target by grepping every import and SwiftUI/
  Observation symbol against known introduction versions — `@Observable`
  (16 files) is the binding constraint, nothing above 14.0 floor found
  in use, no `@available` guards needed. Explicitly documents that only
  one physical Mac (macOS 26.5.1, arm64) is available in this
  environment, so this is a static audit, not multi-OS verification.
- Unsigned ZIP artifact: `Scripts/package-zip.sh` (extends
  `package-local.sh`), produces `CoreTend-0.7.0-arm64-unsigned.zip`
  with LICENSE/NOTICE/THIRD_PARTY_NOTICES.md alongside the app. Verified
  arm64-only, ad-hoc signed, launches and quits cleanly from an
  unrelated extraction path, no user data/logs/quarantine data included.
  Found (not fixed, tracked): the binary still embeds an absolute
  `.build` fallback path from SwiftPM's `Bundle.module` codegen — harmless
  at runtime since the real resource bundle ships alongside it, but a
  known cosmetic leak of the local build machine's username.
- Unsigned DMG artifact: `Scripts/package-dmg.sh`, plain functional DMG
  (no custom background art — no guaranteed display to author one
  safely). Verified full mount → copy → eject → launch round-trip.
- Checksums: `Release/SHA256SUMS` (ZIP + DMG + manifest),
  `Scripts/verify-download.sh <file> <sha256>` (tested against both a
  matching and deliberately wrong checksum).
- Release manifest `Release/latest.json` for 0.7.0: signed=false,
  notarized=false, prerelease=true, telemetry=false,
  accountRequired=false, sourceCommit pinned to the actual commit, no
  downloadURL (no public release exists).
- Bilingual release notes `Release/Notes/0.7.0.{en,fr}.md`.
- Manual-only GitHub Actions workflow `.github/workflows/release-draft.yml`
  (`workflow_dispatch` trigger only): builds/tests/packages, generates
  and self-verifies checksums, hard-fails if the manifest ever claims
  signed/notarized true, uploads artifacts with 14-day retention. Does
  not publish a release, move a tag, or need an Apple secret.
- `Documentation/INSTALL_UNSIGNED.md`: verify-before-open install guide;
  explicitly tells users never to use `spctl --master-disable`, disable
  SIP, or run `xattr -cr` routinely.
- `Documentation/HUMAN_BLOCKERS.md`: maintainer handle, planned repo, and
  planned domain moved to RESOLVED/KNOWN (they're facts already
  centralized in `PublicIdentity.example.json`); the irreversible actions
  that use them (create repo, push, deploy) remain OPEN, along with
  security contact, legal identity/address, publisher of record, final
  screenshots, and multi-Mac testing.
- 83/83 tests passing throughout; `swift build -c release` at 0 warnings
  after every chunk.

## 0.6.0 — 2026-07-20 « Open Source Foundation »
- Full open source foundation: LICENSE/LICENSES/NOTICE/COPYRIGHT/
  TRADEMARKS.md/THIRD_PARTY_NOTICES.md, public README, SECURITY.md,
  CODE_OF_CONDUCT.md, CONTRIBUTING.md, GOVERNANCE.md, SUPPORT.md,
  DEPENDENCIES.md, CLAMAV.md, PROTECTION_LIMITATIONS.md, full user and
  developer documentation, `.github/` community files, CI + security
  workflows, and public `Scripts/` (bootstrap, doctor, repository-doctor,
  clean, uninstall-local, check-licenses, check-private-data,
  check-placeholders).
- Reproducible clean-clone build verification: `git archive HEAD` extracted
  into a throwaway `mktemp -d` directory, then `doctor.sh`, `test.sh`
  (83/83), debug build, release build, `package-local.sh`, and a live
  launch of the packaged `.app` all run and pass from that clean copy.
  Found and fixed a real bug: `package-local.sh` never copied the
  SwiftPM-generated resource bundle (localization strings) into the `.app`,
  so the packaged app silently fell back to an absolute `.build` path
  baked into the binary at compile time — a machine-specific dependency.
  Fixed by copying `.build/release/*.bundle` into `Contents/Resources/`.
  Full writeup in `Documentation/PUBLIC_RELEASE_READINESS.md`.
- Added repo-root `PRIVACY.md` (was linked from README, was missing).
- New `Website/` — bilingual (en/fr) static site foundation: 13 pages per
  locale (Home, Features, Download, Documentation, Open Source, Roadmap,
  Changelog, FAQ, Privacy, Security, Licenses, Legal, 404), generated by
  a single stdlib-only Python script (`Website/generate.py`), styled with
  the app's Orbital Ecology color tokens, zero analytics/trackers/cookies.
  Homepage states local-only operation, open source, no account, no
  telemetry, Apple Silicon target, explained actions, Trash-by-default
  deletions, and pre-1.0 status plainly. Download page shows
  "in preparation" only — no fake release. Not deployed anywhere.
- Version bumped to 0.6.0 (`Package.swift` tools version unchanged;
  `Resources/Info.plist` bundle version, `Documentation/PROJECT_STATE.json`).
- Real, unresolved human blockers remain before any public push: see
  `Documentation/HUMAN_BLOCKERS.md` (maintainer handle, repository URL,
  security contact, legal identity, production domain, first signed
  release, production website deploy). No public push occurred.

## 0.5.0 — 2026-07-20 « Visual Completion »
- Step D final audit: all 10 module visual identities (Step B) confirmed
  code-complete by direct inspection, not just by prior notes — `MCMeshView`
  (Protection), `MCFragmentView` (Cleanup), `MCOverlapStack` (My Clutter),
  `matchedGeometryEffect` continuity (Space Lens, Applications), day-grouped
  timeline (My Activity), filled/outline sync state (Cloud Cleanup).
- New regression test `independentConsumersSeeIdenticalTotals`
  (`Tests/ScanCoreTests/ScanEngineTests.swift`): proves two independent
  readers of one `ScanEngine.run(...)` stream (mirroring Smart Care and
  Cleanup) get identical totals, re-verifying the v0.4.1 fix on fresh code
  rather than trusting old notes. 83/83 tests green.
- Release bundle rebuilt and packaged (`Scripts/package-local.sh`), launched
  live twice — default locale and `AppleLanguages (fr-FR)` — both stable, no
  crash, confirming Step C's French localization still holds end to end.
- `swift build -c release`: 0 warnings.
- Screenshot capture for Documentation/VisualAudit/After remains blocked by
  this sandbox's standing no-attached-display limitation (unchanged since
  v0.3.0, not a regression) — see KNOWN_LIMITATIONS.md and DECISIONS.md D6.
  Everything else that can be verified without a physical screen was
  verified this cycle.
- Version bumped 0.4.1 → 0.5.0 (`Resources/Info.plist`).

## 0.4.1 — 2026-07-20 « Totals & scope audit »
- Audit du scope de scan (ScanEngine/ScanRule): confirmé déjà correct —
  chaque règle déclare ses propres racines, exclusions filtrées avant
  descente (`skipDescendants`), symlinks jamais suivis, chemins canonicalisés.
  Ajout de tests de régression (`Scan root isolation`) prouvant qu'un scan
  Downloads-only ne touche jamais Music/Documents/Library, et qu'un run
  multi-règles (style Smart Care) ne visite que les racines de ses règles.
- Correction des totaux Smart Care / Cleanup: `totalFoundBytes` de Smart Care
  était calculé sur la liste `findings` plafonnée à l'affichage (5000), ce qui
  pouvait diverger du total réel affiché dans l'état "done" du module. Les
  deux vues exposent maintenant `totalFindingCount`/`totalFoundBytes` accumulés
  pendant le streaming (jamais depuis la liste plafonnée), avec indicateur de
  troncature honnête ("N of M shown") quand un scan dépasse 5000 résultats.
- Nouveau test `ScanCoreTests`: 5001 résultats synthétiques, confirme que le
  moteur ne plafonne jamais en interne (le cap est strictement un choix UI).
- 60 tests verts (57 → 60), 0 warning.

## 0.4.0 — 2026-07-20 « Visual Foundation »
- Direction artistique « Orbital Ecology »; signature Core Bloom (noyau + 3 arcs
  asymétriques) partagée logo/icône/héro (MCBloomGeometry).
- DesignSystem refondu: MCColor adaptatif clair/sombre (Core Mint, Ion Violet,
  Solar Amber, Pulse Coral + rôles), MCSpacing/MCRadius/MCSize/MCMotion/MCOpacity,
  MCFont, composants (MCCard+, MCSectionHeader, MCStatusBadge, MCMetricCard,
  MCEmptyState/MCErrorState, MCModuleIdentity, CoreBloomMark, OrbitalProgressView,
  MCHeroCoreView). Reduce Motion/Transparency respectés à la source.
- Icône macOS générée nativement (CoreGraphics → iconset → icns, 16→1024 px),
  icône barre des menus template; assets copiés dans le bundle (plus de
  dépendance au dépôt). Version 0.4.0.
- Sidebar groupée (Soin/Espace/Optimiser/Protéger/Activité), fenêtre min 860×580,
  tint Core Mint.
- Smart Care recomposé: Hero Core lié aux états réels (idle/scanning/review/
  executing/success), microcopy honnête, footer dédupliqué.
- Performance: MCMetricCard (fini les troncatures), graphe CPU grille+aire+état vide.
- Onboarding 4 étapes, skippable, reprenable (étape persistée), FDA honnête.
- Tests design system (tokens, géométrie, couleurs adaptatives, ressources): 57 verts.
- Docs: VISUAL_DIRECTION, BRAND_SYSTEM, DESIGN_TOKENS, MOTION_SYSTEM,
  VISUAL_AUDIT, VISUAL_QA, VISUAL_TOOLING, ASSET_PIPELINE; captures Before/After.
- Bugs données consignés (prompts TCC média pendant scan; totaux plafonnés 5000)
  → prochain audit fonctionnel.

## 0.1.0 — 2026-07-19
- SwiftPM foundation, SafetyCore, ScanCore, FileRules (4 user cleanup rules),
  DesignSystem tokens, SwiftUI shell with working Cleanup module
  (scan → review → dry-run/Trash), 24 tests green, packaging script.

## 0.2.0 — 2026-07-19
- Persistence SQLite (actor, migrations), My Activity, Settings (+exclusions honorées par les scans).
- Smart Care orchestrateur dry-run; Cleanup regroupé par règle, 3 nouvelles règles.
- My Clutter: Large & Old, Doublons (hachage étagé, hard links, gardien suggéré,
  garantie de survivant), Images similaires (Vision, vignettes à la demande).
- Space Lens (treemap + liste), Applications (inventaire, désinstallation Corbeille,
  leftovers conservateurs), Performance (métriques live + LaunchAgents),
  Protection (ClamAV + quarantaine, état honnête), Cloud Cleanup (empreinte locale),
  barre de menus, onboarding avec sonde FDA réelle.
- 46 tests verts, 0 warning, paquet Release arm64.

## 0.3.0 — 2026-07-19
- Protection: onglet Privacy (profils navigateurs, nettoyage caches uniquement,
  avertissement navigateur ouvert; historique/cookies affichés mais non modifiés).
- Applications: onglet Updates (canal de mise à jour par app, aucun téléchargement).
- Accessibilité: labels VoiceOver sur les cases de sélection.
- Script create-test-volume.sh (image APFS isolée pour tests destructifs).
