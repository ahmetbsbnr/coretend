# Protection

Protection is an on-demand local malware scan backed by ClamAV, plus a
reversible quarantine — not a real-time antivirus and not a security
guarantee. See [PROTECTION_LIMITATIONS.md](PROTECTION_LIMITATIONS.md) and
[CLAMAV.md](CLAMAV.md) for exactly what it can and cannot catch.

## How scanning works

`ClamAVScanner` (`Sources/MalwareEngine/MalwareEngine.swift`) looks for a
local `clamscan` binary at common Homebrew/MacPorts install paths
(`/opt/homebrew/bin/clamscan`, `/usr/local/bin/clamscan`,
`/opt/local/bin/clamscan`). If none is found, Protection reports that
clearly instead of silently doing nothing — ClamAV is a user-installed
dependency, not bundled (see [CLAMAV.md](CLAMAV.md) for install steps).

A scan runs `clamscan` over the paths you choose and parses its output into
findings (`MalwareFinding`: path + signature name). Exit code 0 = clean, 1
= finding(s), 2 = an error running the scan.

## Phases (`Sources/CoreTendApp/ProtectionView.swift`)

`idle → scanning → results` (or `failed` if clamscan errored/was missing).

## Acting on a finding

Nothing is deleted automatically. For each finding you choose:
- **Quarantine** — moves the file to the app's local quarantine folder
  (reversible). See [QUARANTINE.md](QUARANTINE.md).
- Later, from the quarantine list: **Restore** (puts it back) or **Delete
  Permanently** (irreversible, a separate explicit action).

## What Protection does not do

It does not scan in the background or in real time, does not phone home
signatures automatically (updating ClamAV's database is a manual step —
see [CLAMAV.md](CLAMAV.md)), does not replace macOS's built-in
XProtect/Gatekeeper, and is not a substitute for a dedicated
endpoint-security product.
