# Protection module — honest limitations

CoreTend's Protection tab is **not** a full antivirus product and is
**not** a security guarantee. This page states plainly what it does and does
not do, so users can make an informed decision.

## What Protection actually is

- An optional, opt-in wrapper around a user-installed `clamscan` binary
  (ClamAV). See `Documentation/CLAMAV.md` for the technical details.
- A local quarantine mechanism (move + restore), not a removal or repair
  tool.
- A privacy-cleaner sub-tab unrelated to malware scanning.

## What it is not

- **Not a full antivirus / EDR.** No real-time/on-access protection, no
  behavioral or heuristic detection beyond what ClamAV's signature engine
  provides, no network protection, no exploit mitigation.
- **Not a security guarantee.** A clean scan result means "ClamAV's current
  signature database found no known match in the scanned paths" — nothing
  more. It does not mean a Mac is free of malware, especially zero-day or
  targeted threats that predate signature coverage.
- **Not maintained by CoreTend.** ClamAV, its signature database, and
  its update cadence (`freshclam`) are entirely outside this project's
  control. CoreTend does not vet, curate, or guarantee the accuracy or
  freshness of ClamAV's signatures.
- **Not always installed.** ClamAV is optional third-party software the
  user installs separately (e.g. `brew install clamav`). CoreTend
  never installs it automatically and never bundles it.
- **Not a replacement for Apple's built-in protections** (Gatekeeper, XProtect,
  notarization, SIP). Those remain active and should never be disabled to
  work around CoreTend.

## Scan scope

`clamscan --recursive` scans only the paths the user explicitly selects for
a scan. It does not scan the entire disk automatically and does not run in
the background or on a schedule unless the user initiates it.

## Quarantine, not remediation

Quarantining a file moves it locally and strips execute permission; it does
not "clean," "repair," or "disinfect" an infected file, and it does not
undo any damage the file may have already caused before detection.

## If you need real protection

For anything beyond casual, opt-in signature scanning, use a maintained,
purpose-built security product and keep macOS itself (Gatekeeper, XProtect,
software updates) enabled. CoreTend's Protection tab is a convenience
layer on top of a tool you already trust and install yourself — not a
substitute for one.
