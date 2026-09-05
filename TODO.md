# TODO — CoreTend

CoreTend 1.0.0 shipped on 2026-09-03. It is Developer ID signed,
Apple-notarized, stapled, Minisign-signed, and published as a stable GitHub
release. Core functionality is complete; 603 Swift tests pass (post-1.0.0
work — Storage Timeline, then Advisor, then Recovery Plan, then APFS
Intelligence, then Applications Center 2.0, then Developer Center, then
Privacy Lab, then Restore Center — added 261 since the 342 that shipped in
1.0.0). Post-1.0.0 verticals live on local branches only; nothing is merged
to `main` or pushed.

## Release follow-up

Completed 2026-09-04 by maintainer verification: interactive VoiceOver,
keyboard traversal, focus visibility, Dynamic Type, second-Mac/different-macOS
compatibility, and 44-frame native FR/EN × light/dark × every-module visual
matrix. See `Documentation/HUMAN_QA_REPORT.md`.

Release-workflow provenance plumbing is complete for the next release:
`.github/workflows/release.yml` now uses the dedicated signing Mac and applies
Developer ID signing, notarization, stapling, SHA-256, SLSA attestation and
Minisign to the same final bytes. A retrospective SLSA attestation for 1.0.0
would still be false and will not be created.

## Done — Storage Timeline minimal vertical (1.1 "Insight" scope)

"What changed since my last scan?" is now answerable end to end: `Persistence`
schema v6 (`timeline_snapshots` incl. `scope`, `timeline_categories`), a
`TimelineService` layer, a real `StorageTimelineView` (sidebar, under
Storage), and a Dashboard "Since last scan" card. Comparisons never mix scan
kinds — every one is scoped (Cleanup/Duplicates/Leftovers/Privacy today) and
the cross-scope Dashboard card only ever compares a scan against the previous
snapshot of that same scope. Category aggregates only, never file paths.
See `Documentation/FEATURE_MATRIX.md` → "Storage Timeline" and
`Documentation/PERSISTENCE.md` → "Timeline" for the full detail, including
which engines are deliberately not wired yet and why (My Clutter/Large & Old,
Space Lens, Similar Images, Cloud Cleanup).

Follow-up, not blocking the vertical above: wiring more engines as their
scan semantics allow it; richer physical/APFS-aware sizing (planned as its
own "APFS Intelligence" roadmap item); a WidgetKit surface reusing
`TimelineService`.

## Done — CoreTend Advisor minimal vertical

A deterministic, local, read-only explanation layer between scan engines and
UI: `AdvisorFinding`/`AdvisorService`/`AdvisorDetailsView`
(`Sources/CoreTendApp/`). Reuses `SafetyCore.RiskLevel` and `TimelineScope`
rather than inventing parallel taxonomies; adds `AdvisorConfidence`
(exact/high/probable/uncertain) and `AdvisorReversibility`, since neither
existed. Wired and visible in the UI: Cleanup, Duplicates, Leftovers,
Privacy. See `Documentation/FEATURE_MATRIX.md` → "CoreTend Advisor" and
`Documentation/SAFETY_MODEL.md` → "Advisor" for the full mapping and why
Applications/Integrity aren't connected yet.

## Done — Recovery Plan minimal vertical

Goal → eligible findings → conservative plan → review → user selection →
existing safe execution path, working end to end (not plan-only):
`RecoveryPlanEligibility`/`RecoveryPlanBuilder`/`RecoveryPlanService`/
`RecoveryPlanView` (`Sources/CoreTendApp/`). Consumes `AdvisorFinding`
structurally — eligibility is risk/confidence/reversibility/bytes-based, never
a parse of Advisor's display text. Wired: Cleanup, Duplicates (group-level
aggregate, `wastedBytes` only, never the group's full size), Leftovers
(split into exact/ambiguous aggregates), Privacy (cache-only aggregate).
High risk and uncertain confidence are always excluded from automatic
planning; Duplicates and ambiguous Leftovers always require review, never
preselected. See `Documentation/FEATURE_MATRIX.md` → "Recovery Plan" and
`Documentation/SAFETY_MODEL.md` → "Recovery Plan" for the full eligibility
rule, the anti-double-counting decision (`user.caches` always excluded —
it structurally overlaps Privacy and Leftovers on disk), and what's
deliberately not done yet (a Dashboard card; separate integration tests for
Leftovers/Privacy execution beyond the pattern Cleanup/Duplicates already
prove).

## Done — APFS Intelligence minimal vertical (read-only)

"Why don't displayed sizes always match real disk usage?" is now answerable
for Cleanup, plus real volume capacity/availability figures under their own
Apple names: `APFSVolumeInspector`/`APFSMetric<Value>`/
`APFSIntelligenceService` (`Sources/SystemMetrics/`, `Sources/CoreTendApp/`),
zero subprocess usage — Darwin `statfs()` for filesystem type, Foundation
`URLResourceKey`s for everything else. `TimelineCategorySample.physicalBytes`
is now populated for Cleanup snapshots (paired only with that same scan's
logical total, never mixed perimeters); still `nil` for Duplicates/
Leftovers/Privacy and every pre-existing snapshot, and UIs must treat `nil`
as a real state, never `0`. New sidebar screen `APFSIntelligenceView`. Zero
destructive code anywhere in this vertical — no snapshot deletion, no volume
modification — and zero Recovery-Plan eligibility, by construction (no
`AdvisorFinding` is ever created for an APFS concept). See
`Documentation/FEATURE_MATRIX.md` → "APFS Intelligence",
`Documentation/APFS_INTELLIGENCE.md`, and `Documentation/SAFETY_MODEL.md` →
"APFS Intelligence" for the full sub-capability breakdown, including what's
deliberately left `Unavailable`/not started (clone/hard-link storage-sharing
attribution, snapshot listing and individual snapshot size — none of these
have a reliable public-API or no-subprocess path yet) and a pre-existing,
documented-not-fixed hard-link double-counting behavior found in
`ScanEngine`/`SpaceLensEngine`/`AppDiscovery` during this audit.

## Done — Applications Center 2.0 (read-only inspection depth)

Applications Center now explains, per installed app: storage breakdown
("Known associated storage", never "Total"), associated-item confidence
(reusing `AdvisorConfidence`; Group Containers are a vendor-prefix
heuristic, `.probable` at best, flagged `isShared` when more than one app
shares the vendor prefix), installation source vs. update mechanism as two
separate facts (a Sparkle-updated, directly-downloaded app never shows
"Installed via Sparkle"), code signing/provenance (connects the pre-existing
`IntegrityCore.CodeSignInspector`, shown as a plain technical fact, never
reworded as safe/unsafe), architecture including universal-binary slice
sizes via a fail-closed Mach-O parser (no `lipo`), launch items per app
(`IntegrityCore.LoginItemScanner`, associated only by a reliable signal —
in-bundle program path or bundle-id-matching Label, never name resemblance),
and running state (`NSWorkspace`, informational only). New composition:
`ApplicationInspection`/`ApplicationInspectionService`
(`Sources/CoreTendApp/ApplicationInspection.swift`), loaded lazily and
cancellably per app selection — never for the whole app list at launch.
The existing uninstall path and its confirmation are unchanged: Group
Container candidates are shown for visibility only, never selectable. See
`Documentation/FEATURE_MATRIX.md` → "Applications Center 2.0",
`Documentation/APPLICATIONS_CENTER.md`, and `Documentation/SAFETY_MODEL.md`
→ "Applications Center" for the full sub-capability breakdown, including
what's deliberately not started (PKG/receipt provenance beyond the existing
Mac App Store check, search/filter extensions, `FAT_MAGIC_64` universal
binaries) and zero Recovery-Plan eligibility, by construction.

## Done — Privacy Lab: image metadata inspection (read-only first vertical)

Select an image → inspect locally → structured, per-category privacy view.
`ImageMetadataInspector`/`ImageMetadataInspection`/`MetadataField`
(`Sources/SystemMetrics/ImageMetadataInspector.swift`) is a pure ImageIO read
(`CGImageSource` property dictionaries only, `kCGImageSourceShouldCache:
false`, no pixel decode, no subprocess, no network). `PrivacyLabService`/
`PrivacyLabCatalog`/`PrivacyLabSummary` and `PrivacyLabViewModel`/
`PrivacyLabView` (`Sources/CoreTendApp/`) add the off-main-actor hop,
localized "why this can matter" explanations, an honest count-based summary
(**no privacy score**), and a real sidebar screen (system group).

Coverage: location/GPS, capture date, camera make/model, lens model,
software/editor, author, copyright, description/comment, keywords, device/lens
serial number, unique image ID — each reported as **Present / Not detected /
Unavailable** (never "safe"). GPS is coarse in the main UI; exact coordinates
are behind an explicit opt-in, never reverse-geocoded, never persisted.
Formats validated with programmatic fixtures: JPEG, TIFF, PNG, HEIC (when the
host can encode it), plus corrupt/truncated/non-image/missing/directory
failure paths. Stale-result guard: a slower earlier inspection can never
overwrite a newer selection.

Read-only with respect to the user's image: no `CGImageDestination`, no
`FileManager` mutation, no in-place EXIF strip anywhere. Nothing persisted —
no Store, Timeline, activity, log or analytics write. No `AdvisorFinding`, so
not Recovery-Plan-eligible by construction. Photos Library is never scanned
or modified. **Sanitized-copy / metadata stripping is NOT implemented** — the
layering leaves a clean seam for a future *original → read → sanitized copy →
verify → compare → preserve original* flow, which must prefer "create
sanitized copy" over "modify original". See `Documentation/PRIVACY_LAB.md`,
`Documentation/FEATURE_MATRIX.md` → "Privacy Lab", and
`Documentation/SAFETY_MODEL.md` → "Privacy Lab".

## Done — Restore Center (real end-to-end restore)

Move CoreTend-Trashed items back to where they came from. `SafetyCenter
.execute` now captures the real `resultingItemURL` from
`FileManager.trashItem(at:resultingItemURL:)` and emits a
`RestoreManifestRecord` (`Sources/SafetyCore/RestoreManifest.swift`) for
every **successful** Trash move — never the permanent `removeItem` fallback.
The sink is auto-detected (`sink as? RestoreManifestSink`; `Persistence
.Store` conforms), so Cleanup, Developer Center, Applications uninstall,
Recovery Plan, Duplicates, Leftovers and Privacy all capture manifests with
**zero call-site changes and no second execution path**.

DB schema **v7** `restore_manifest` is the one table with real, unredacted
paths (original + Trash location) — one row per Trashed operation item (a
directory root is one row). `safety_log` stays redacted and correlates only
by `operation_id`. Retention: any row >90 days pruned, non-`available` rows
>30 days pruned, on every write. `clearRestoreManifests` ("Forget Restore
History") removes records only and **never empties the Trash**. Excluded from
`DiagnosticReport`, Timeline, and audit exports; local only, never synced.

`RestoreService` (`Sources/CoreTendApp/RestoreService.swift`, actor) does
every move: per item, re-read manifest → recompute live availability (inode +
volume UUID + directory-ness vs the Trash item; parent exists/writable +
destination not occupied) → `RestoreValidator` (`Sources/SafetyCore/`,
destination pinned to the recorded original, never arbitrary; never a
protected root; **collision refused, never overwritten**; source inside a
`.Trash`/`.Trashes` dir) → `FileManager.moveItem` back → mark `restored` +
redacted `.executed` safety event. Per-item, never atomic; one coarse
`.restore` `ActivityRecord` per run with real counts.

`RestoreReversibility.of(_:)` is the sole producer of
`.restorableByCoreTend`, and only for a live `.available` item; emptied Trash
→ `.irreversible`. `AdvisorService` and `RecoveryPlanEligibility` are
unchanged. UI: `RestoreCenterView` (System sidebar, after My Activity) —
operations grouped, per-item state badges (text+icon), full paths behind
disclosure, Refresh, confirm-and-restore, "Forget Restore History" with a
"does not empty the Trash" confirmation. 41 new tests. Real external-volume
restore is `HUMAN VERIFICATION REQUIRED` (model exercised with synthetic
volume identity). See `Documentation/RESTORE.md`,
`Documentation/SAFETY_MODEL.md` → "Restore Center", `Documentation/
PERSISTENCE.md`, `Documentation/FEATURE_MATRIX.md` → "Restore Center".

## Deliberately deferred product scope

- Additional locales beyond English and French.
- Browser history/cookie deletion; cache-only cleaning avoids live-profile DB
  corruption.
- Dedicated safe engines for iOS Simulators, emptying Trash, Mail attachments,
  and broken LaunchAgents. Never implement these as blind file rules.
- Possible privileged helper and Mac App Store edition. Neither is required by
  current features or promised to users.

## Future product ideas — not shipped, not promised

These are recorded proposals only. They require a separate product and safety
review before any implementation:

- Developer cleanup: Xcode DerivedData and iOS Simulator caches, with explicit
  scope and confirmation for every location.
- Universal-binary size analysis: report removable Intel slices first; never
  alter an app without signature-aware validation and a reversible path.
- Complete app uninstall: discover related support files with a reviewed,
  app-specific allowlist rather than broad `~/Library` deletion.
- Expanded native security signals beyond Integrity's current read-only scope.
- Background-item manager: list LaunchAgents, LaunchDaemons and login items;
  any disable action would need explicit review and rollback.
- Sensitive-metadata cleaner: the **inspection** half shipped as Privacy Lab
  (read-only, see the Done section above). Opt-in **removal** is still
  deferred and must be built as a sanitized-copy export, not an in-place
  strip, with a verify/compare step and the original preserved.
- Notification Center widget showing free space and linking to the main app.
- Optional CLI destructive workflows remain deferred; `coretend-cli` now ships
  read-only rule/path inspection with no filesystem mutation.
- Shortcuts actions for inspect/report workflows, with confirmation before any
  destructive action.

Historical TODOs live under `Documentation/Archive/` and
`Documentation/Audits/`. `Documentation/PROJECT_STATE.json` is current machine-
readable state; `Documentation/RELEASE_STATE.md` carries release evidence.
