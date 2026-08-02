# KNOWN LIMITATIONS

*Last re-verified against the v0.9.1-rc.4 release candidate, 2026-08-02.
Historical descriptions remain below only where they explain a regression gate;
the bullets at the top describe the current product.*

- The public candidate is ad-hoc signed, unsigned by a Developer ID and not
  notarized. Gatekeeper's rejection is expected and the documented recovery is
  System Settings → Privacy & Security → Open Anyway.
- SwiftPM emits `CoreTendUITests` as a unit-test bundle, so its eight
  `XCUIApplication` contracts skip with an explicit reason. Artifact UI is
  exercised with the isolated live capture harness; a native Xcode UI-test
  target remains future work.
- Cleanup/Smart Care review list caps *display* at 5000 findings (memory bound); totals
  (bytes/count) are computed from the uncapped `ScanEngine` stream, not the capped list —
  regression-tested (`independentConsumersSeeIdenticalTotals`, `ScanEngineTests.swift`).
- Symlinks are skipped by scans, not followed.
- Integrity is a first-party local provenance and login-item inventory. It is
  not an antivirus scanner and makes no malware-detection claim. The former
  ClamAV/MalwareEngine integration was removed before rc.4.
- Privileged helper not shipped (blocked: no Developer ID signing available in this
  environment).
- **Visual QA capture: PARTIAL_BLOCKED_ENVIRONMENT** (headline corrected in the
  0.8.1 resync). A real display **is** available and a plain
  `Scripts/capture.sh` launch capture works; what remains blocked is the
  module-targeted capture path (intermittent AppleScript `-1719`) and therefore
  the full FR/EN x light/dark x every-module campaign. The original
  "no attached display" claim below is **stale as written** and preserved only
  as the historical record it is, with its own dated updates that already walk
  it back. Read the 2026-07-24 and 2026-07-25 updates, not the headline.

  ~~**No attached display in this sandbox, standing across every session to date
  (v0.3.0 through v0.5.0)**~~: `Scripts/capture.sh` fails headlessly
  (`System Events` error -1719, cannot control process without an active display/
  Accessibility TCC grant). This blocks *capturing* new screenshots for
  Documentation/VisualAudit/After — it does not block anything else. All Step B
  (visual identity) and Step C (French localization) work was verified at the code
  level and via non-visual live-launch checks (process stays up, no crashed/faulted
  log entries, `ps` confirms the bundle runs under `AppleLanguages (fr-FR)`) instead
  of via screenshot comparison. Anyone with a machine that has a real display should
  run `Scripts/capture.sh` per Documentation/VISUAL_QA.md to fill in the still-pending
  captures; this is an environment fact, not a product defect, and does not block
  shipping.
  **Update, audit session 3 (2026-07-20):** this "no display" fact is
  environment-dependent, not universal — in this session's sandbox, `screencapture -x`
  successfully captured the live desktop (confirmed a real, non-trivial PNG). Did not
  proceed to run `Scripts/capture.sh` this session (the live screen showed unrelated
  foreground content, and driving the real desktop via AppleScript for a fresh capture
  was judged out of scope for a non-interactive audit pass) — so `VisualAudit/After/`
  is still the v0.4.0-era set, not refreshed. Future sessions should re-check display
  availability rather than assuming this limitation still applies; see
  `Documentation/PROJECT_COMPLETE_AUDIT.md` §15 and `AUDIT_EVIDENCE.md`
  EVIDENCE-ENV-001.
  **Update, 0.8.0 Functional Completion phase (2026-07-24):** confirmed
  again — a real display is available in this sandbox (`screencapture -x`
  and `System Events` process automation both work with no TCC prompt).
  Rebuilt the app (`Scripts/package-local.sh`), launched it, and captured
  one real window-only screenshot of the Smart Care idle screen via
  `Scripts/capture.sh` with no module argument — confirms the app renders
  correctly (Core Bloom idle state, honest "not yet available" labels on
  Protection/Performance/Applications matching `FEATURE_MATRIX.md`) and
  that this session's My Clutter changes didn't break the build visually.
  The module-argument path (`capture.sh <out> "<Sidebar Row Name>"`, which
  drives the sidebar via AppleScript `System Events` before capturing) hit
  a flaky `-1719` "window 1 of process ... Index non valable" error on a
  second invocation immediately after the first successful one — window
  count reported 1 but indexed access failed. Not root-caused this pass
  (AppleScript AXWindow timing quirk, most likely) — logged here rather
  than worked around, since a full FR/EN × light/dark × every-module
  capture campaign is a separate, larger pass than this documentation
  slice. Step 15 status: `READY_FOR_MANUAL_QA`, not
  `FULLY_VISUALLY_VERIFIED` — the mechanism works for a plain launch
  capture, module-targeted capture needs a follow-up debugging session.
- **RESOLVED and hardened (rc.4, 2026-08-02) — built binary discloses neither the
  repo checkout nor the build account.** `Scripts/package-local.sh` strips
  Swift's N_OSO/debug records before sealing the bundle, and
  `Scripts/test-distribution.sh` searches the raw Mach-O for both the checkout
  and `/Users/<build-account>/`. The exact packaged executable reports zero
  occurrences. The description below is
  kept because it explains *why* the check exists and must not be deleted as
  "noise" — but the condition it describes is no longer present in the 0.8.1
  artifacts. The 2026-08-02 gate found that release symbol records had
  reintroduced the source checkout; stripping them before code signing is the
  root-cause fix and the raw-binary gate catches regression. Historical
  description follows:

  **Built binary embeds the repo checkout's absolute build path as a dead fallback
  string** (SwiftPM limitation, discovered by `Scripts/test-distribution.sh`):
  the compiler-generated `Bundle.module` accessor (`resource_bundle_accessor.swift`)
  hardcodes both `Bundle.main`'s expected resource path and a `.build/...` absolute
  path as a fallback if the first lookup fails. In the packaged app the first path
  always resolves (resources are copied into `Contents/Resources` by
  `package-local.sh`), so the fallback string is never *read* at runtime — but the
  string itself is still present in the binary's data section (`strings` finds it).
  This is a build-tool artifact, not a tracked-file leak or a runtime behavior; it
  does not expose the developer's username since the path is a project-relative
  checkout location, not `$HOME`. No fix available without moving off SwiftPM
  resource bundles (e.g. an Xcode-project build) or a post-build binary string
  patch, both out of scope for this distribution slice. `test-distribution.sh`
  reported this as a gap at that time; it is not a description of the rc.4
  artifact.

## Added by the 0.8.1 Final Canonical Audit Resync (2026-07-25)

- **RESOLVED (0.9.0 launch phase, 2026-07-25) — the distribution smoke test is
  now isolated from real user data, and the isolation is measured.**
  `TestStoreOverride` (`Sources/Persistence/TestStoreOverride.swift`) redirects
  the store to a throwaway directory when two agreeing environment variables are
  present, and the same marker suppresses the legacy-data migration so the test
  cannot read real pre-rename data. `Scripts/test-distribution.sh` fingerprints
  every file under the real store before and after the launch and fails on any
  change; `Scripts/check-test-isolation.sh` statically enforces the whole shape,
  with 9 self-tests. 22 unit tests cover the validation rules. The real store was
  verified untouched across a full run.

- **RESOLVED (0.9.0 launch phase, 2026-07-25) — the release-manifest gate no
  longer has a circular requirement.** `Release/latest.json` and
  `Release/SHA256SUMS` are no longer tracked: they are generated into `dist/`
  from the tracked, hand-authored `Release/latest.template.json`. Because
  nothing is committed, `sourceCommit` names the commit that was actually
  packaged and stays true permanently, and the gate no longer rebuilds the
  artifacts as a side effect of being run. `build-release.sh` now refuses a
  dirty tree outright. Proven by 15 shell tests in
  `Scripts/test-release-provenance.sh` and documented in
  `Documentation/RELEASE_PROVENANCE.md`. The publication gate has been shown
  green on an exact tag with nothing committed after it.

  Historical description of the defect follows, kept because it explains why the
  provenance design is shaped the way it is:

  ~~**The release-manifest gate cannot be satisfied at the commit it describes.**~~
  `Scripts/test-release-manifest.sh` rebuilt the artifacts and then asserted
  `Release/latest.json`'s `sourceCommit` equalled `git rev-parse HEAD`. Since
  `latest.json` was itself a tracked file, committing it necessarily created a new
  HEAD that the just-written `sourceCommit` could not name.

- **Migration executed on exactly one machine, once, on the happy path.** See
  `Documentation/CORETEND_DATA_MIGRATION_REPORT.md` §5. The failure, skip,
  rollback and interrupted-resume paths are covered only by unit tests against
  temporary directories; no real failing migration on real user data has ever
  been observed.

- **Manual QA is partially blocked by the environment, not complete.** A real
  display is available and a plain launch capture works, but the
  module-targeted capture path (`Scripts/capture.sh <out> "<Sidebar Row>"`)
  still hits an intermittent AppleScript `-1719` error, and the DMG's saved icon
  positions need Finder automation this environment refuses. The full
  FR/EN x light/dark x every-module campaign and interactive VoiceOver passes
  remain unrun. Status: `PARTIAL_BLOCKED_ENVIRONMENT`.
