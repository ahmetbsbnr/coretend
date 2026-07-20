# KNOWN LIMITATIONS
- Built with CommandLineTools only: ad-hoc signature, no notarization, no UI tests.
- Cleanup/Smart Care review list caps *display* at 5000 findings (memory bound); totals
  (bytes/count) are computed from the uncapped `ScanEngine` stream, not the capped list —
  regression-tested (`independentConsumersSeeIdenticalTotals`, `ScanEngineTests.swift`).
- Symlinks are skipped by scans, not followed.
- Protection (malware scanning) requires ClamAV installed locally; when absent the UI
  states this honestly rather than pretending to scan.
- Privileged helper not shipped (blocked: no Developer ID signing available in this
  environment).
- **No attached display in this sandbox, standing across every session to date
  (v0.3.0 through v0.5.0)**: `Scripts/capture.sh` fails headlessly
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
- **Built binary embeds the repo checkout's absolute build path as a dead fallback
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
  reports this as a FAIL rather than hiding it — treat it as a known, low-severity
  gap, not a green light to claim "no repo-path leakage" in release docs.
