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
