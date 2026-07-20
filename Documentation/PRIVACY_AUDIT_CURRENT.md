# Privacy Audit — Session 2

Evidence: `grep -rniE "URLSession|Network framework|socket\(|NWConnection|http://|https://|analytics|gtag|mixpanel|sentry|crashlytics"` over `Sources/` and `Website/`. Commit at session start `f1ec7d4`.

## Result: zero network calls found in `Sources/`

`grep -rn "URLSession" Sources/` returns **no matches**. No `Network.framework` (`NWConnection`/`NWListener`),
no raw `socket()` calls, no HTTP client of any kind found anywhere in the Swift source tree. This is consistent
with `Documentation/DEPENDENCIES.md`'s claim of zero external SwiftPM dependencies and the architecture
inventory's finding of exactly one `Process()` call (a local subprocess, not network I/O).

- **required-network**: NONE FOUND.
- **optional-network**: NONE FOUND. (Note: `AppUpdatesView.swift:38-40` opens `macappstore://showUpdatesPage`
  via `NSWorkspace.shared.open` — this hands off to the macOS App Store app via a URL scheme; it is the *system*
  App Store app that would make network calls, not MacCare Local itself. MacCare Local performs no network
  request of its own here.)
- **no-network**: every scan/cleanup/malware/metrics/persistence feature audited in `FEATURE_INVENTORY.md` this
  session operates on local `FileManager`, Mach/sysctl (`SystemMetrics.swift`), Vision (on-device,
  `SimilarImagesEngine.swift`), and SQLite (`Persistence/Database.swift`) — all local.
- **planned-but-not-implemented**: none found (no TODO/network stub comments turned up in the grep).

## Telemetry / analytics / crash reporting / accounts

- **No telemetry**: no analytics SDK, no event-tracking calls, no `os_signpost`-to-remote pattern found.
- **No account system**: no auth/login/session code found anywhere in `Sources/`.
- **No remote crash reporter**: no Sentry/Crashlytics/Bugsnag-style symbol or API key found.
- **No uploads**: `DiagnosticReport.swift` (session-1-verified redaction) produces a local export file the user
  must manually attach to a bug report — it is not auto-submitted anywhere; confirmed by the absence of any
  network call in `Sources/` (this session's grep) combined with the diagnostic flow's `.task`/sheet-preview
  UI pattern (`SettingsView.swift:188`, session-1 finding).

## Website (`Website/*.html`)

`grep -rniE "URLSession|fetch\(|XMLHttpRequest|analytics|gtag|google-analytics|plausible|mixpanel|sentry"
Website/*.html` returned **zero matches** — no tracker/analytics script tags found in the 27 tracked HTML
files at a text-search level. This is a shallow check (string search only, not a rendered-DOM/network-request
audit); a full website audit (deployment status, external resource loading, real vs placeholder content) is
still queued for session 3 per the orchestrator's explicit scope.

## Conclusion

MacCare Local's local-only-data claim holds up under this session's evidence: no network stack anywhere in
`Sources/`, no telemetry, no accounts, no remote crash reporting, no automatic uploads. The one external-facing
action found (`macappstore://` deep link) is a user-initiated system handoff, not the app's own network call.
