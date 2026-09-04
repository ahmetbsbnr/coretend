# CoreTend Roadmap

## Current state

CoreTend 1.0.0 is shipped: stable, Developer ID signed, Apple-notarized,
stapled, and independently verifiable with SHA-256 plus Minisign. Product
boundary remains local-first: read-only analysis, reviewed selection, explicit
confirmation, execution-time path validation, and recoverable Trash actions.

## Near-term quality work

- Operate and validate the new dedicated signing-runner release path. It signs,
  notarizes, staples, hashes and attests the same final bytes. Never fabricate
  provenance retrospectively for 1.0.0.
- Preserve interactive VoiceOver/keyboard/Dynamic Type and cross-Mac coverage
  for future UI or minimum-macOS changes. Baseline passed 2026-09-04.
- Refresh approved 44-frame native EN/FR light/dark matrix when UI changes.

## Candidate 1.x improvements

- Surface existing engine metadata where useful: finding category/confidence,
  integrity origin/date, skipped/error activity counts, and release channel.
- Add locales only when demand and review capacity exist.
- Evaluate dedicated safety designs for Simulator cleanup, Trash emptying,
  Mail attachments, and broken LaunchAgents.
- Evaluate Mac App Store distribution separately from direct distribution.

## Explicit non-goals

- Antivirus or malware-detection claims. IntegrityCore reports native
  signature, provenance, and login-item facts; it is not an antivirus.
- Automatic destructive cleanup.
- Browser history/cookie deletion while browsers may own profile databases.
- Telemetry, analytics, accounts, or cloud upload of scan results.
