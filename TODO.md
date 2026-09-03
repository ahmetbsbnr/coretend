# TODO — CoreTend

CoreTend 1.0.0 shipped on 2026-09-03. It is Developer ID signed,
Apple-notarized, stapled, Minisign-signed, and published as a stable GitHub
release. Core functionality is complete; 342 Swift tests pass.

## Release follow-up

1. Perform interactive VoiceOver, keyboard traversal, focus visibility, and
   Dynamic Type QA. Automated labels, contrast, and Reduce Motion checks pass,
   but automation cannot replace assistive-technology observation.
2. Expand compatibility testing beyond the current Apple-silicon Mac and
   macOS environment when another supported machine/OS is available.
3. Complete the native-app FR/EN × light/dark × every-module screenshot
   campaign. This is visual-regression coverage, not a 1.0 correctness blocker.
4. For the next release, create provenance in the same trusted workflow that
   produces or receives the signed final bytes. A retrospective SLSA build
   attestation for 1.0.0 would falsely identify a downloader as the builder;
   1.0.0 instead carries Developer ID/notarization, SHA-256, and Minisign.

## Deliberately deferred product scope

- Additional locales beyond English and French.
- Browser history/cookie deletion; cache-only cleaning avoids live-profile DB
  corruption.
- Dedicated safe engines for iOS Simulators, emptying Trash, Mail attachments,
  and broken LaunchAgents. Never implement these as blind file rules.
- Possible privileged helper and Mac App Store edition. Neither is required by
  current features or promised to users.

Historical TODOs live under `Documentation/Archive/` and
`Documentation/Audits/`. `Documentation/PROJECT_STATE.json` is current machine-
readable state; `Documentation/RELEASE_STATE.md` carries release evidence.
