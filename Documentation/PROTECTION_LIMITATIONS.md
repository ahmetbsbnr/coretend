# Integrity — honest limitations

CoreTend's Integrity tab is **not** an antivirus and is **not** a security
guarantee. This page states plainly what it does and does not do, so users
can make an informed decision.

## What Integrity actually is

- Three read-only inspections of signals macOS already records: download
  provenance, code-signature tier, and login items. See
  [PROTECTION.md](PROTECTION.md) and
  [`Sources/IntegrityCore/IntegrityCore.swift`](../Sources/IntegrityCore/IntegrityCore.swift)
  for exactly what each one reads.
- A privacy-cleaner sub-tab (Privacy Cleaner) unrelated to any of the above.

## What it is not

- **Not an antivirus / EDR.** No scanning engine, no signature database, no
  file-content inspection, no real-time/on-access protection, no behavioral
  or heuristic malware detection, no network protection, no exploit
  mitigation.
- **Not a security guarantee.** A code signature reading "Apple-signed" or
  "team-signed" means the binary's signature validates against that
  identity — nothing more. An unsigned or ad-hoc binary is not necessarily
  malicious, and a validly-signed one is not necessarily safe; signature
  tier is provenance information, not a verdict.
- **Not a replacement for Apple's built-in protections** (Gatekeeper,
  XProtect, notarization, SIP). Those remain active and should never be
  disabled to work around CoreTend.
- **Not real-time.** Each check runs on demand when you open its tab; there
  is no background watcher and nothing runs on a schedule.

## Why this replaced a ClamAV-based design

An earlier version of this tab wrapped a user-installed `clamscan` binary
(ClamAV) plus a local quarantine mechanism. Both required the user to open
Terminal and run `brew install clamav` — a hard violation of this
project's own bar for this feature ("never Terminal, never Homebrew").
Building a fully in-app installer/updater for a third-party GPL-licensed
scanning engine was a real distribution and licensing undertaking this
project had not had legal review for, so the feature was retired rather
than shipped as a Terminal-dependent version of itself. Full rationale,
including what the removed code covered, in
[CLAMAV_DECISION.md](CLAMAV_DECISION.md).

## If you need real malware protection

Use a maintained, purpose-built security product, and keep macOS itself
(Gatekeeper, XProtect, software updates) enabled. Integrity is provenance
information you already had access to somewhere in macOS, surfaced in one
place — not a substitute for dedicated security software.
