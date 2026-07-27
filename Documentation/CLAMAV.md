# ClamAV integration

CoreTend's Protection module can optionally scan files with **ClamAV**,
a third-party open-source antivirus engine. This document describes exactly
how that integration works, verified against `Sources/MalwareEngine/MalwareEngine.swift`.

## What is and isn't bundled

- **libclamav is never linked.** `Package.swift` declares zero external
  dependencies — `MalwareEngine` is a pure Swift target with no C library,
  no `.package()` entry, no `systemLibrary`, no linker flags referencing
  ClamAV.
- **No ClamAV binaries or virus-definition databases (`.cvd`/`.cld`) ship in
  the app bundle or the repository.** The engine does not download, cache,
  or embed signatures at build or run time.
- The app **shells out** to a `clamscan` executable that the user installs
  and manages themselves (e.g. via Homebrew: `brew install clamav`).

## How it works (`ClamAVScanner`)

1. At init, `ClamAVScanner` looks for `clamscan` at a fixed list of known
   install paths: `/opt/homebrew/bin/clamscan`, `/usr/local/bin/clamscan`,
   `/opt/local/bin/clamscan` (Homebrew arm64/intel, MacPorts). A custom path
   can also be passed explicitly.
2. `isAvailable` is simply "was an executable file found at one of those
   paths." If not, the scanner reports itself unavailable — nothing is
   installed, downloaded, or silently substituted.
3. `scan(paths:)` runs `clamscan --no-summary --infected --recursive <paths>`
   via `Process`, passing each path as a discrete argument (never through a
   shell), so there's no shell-injection surface. Output is parsed from
   stdout; exit codes 0 (clean) and 1 (infected) are treated as success,
   anything else is a scan failure.
4. Findings (`path`, `signature`) are surfaced in the Protection UI. Nothing
   is deleted automatically — flagged files are only moved into the app's
   local `Quarantine` (see below) after an explicit user action.

## What ClamAV's signature database can and can't catch

ClamAV is a signature-based scanner. It updates its own database with
`freshclam`, entirely outside CoreTend's control. CoreTend does
not manage, verify, or guarantee freshness of that database — see
`Documentation/PROTECTION_LIMITATIONS.md`.

## Quarantine, not deletion

`Quarantine` (same file) moves a flagged item into
`~/Library/Application Support/CoreTend/Quarantine`, strips its execute
permission, and records the original path in a local JSON manifest so it can
be restored. Files are never executed, modified in place, or permanently
deleted except by explicit user action (`delete(_:)`).

## Behavior without ClamAV installed

Verified in `Sources/CoreTendApp/ProtectionView.swift`: when
`scanner.isAvailable` is `false`, the Protection tab renders an honest
"unavailable" state (`unavailableCard`) — a warning icon, an explanation,
and install instructions — instead of a scan UI. `scan(paths:)` itself
also no-ops (`guard scanner.isAvailable else { return }`) if invoked
without ClamAV present. The rest of the app (Smart Care, cleaning,
duplicates, Space Lens, etc.) builds, launches, and functions fully with or
without ClamAV — Protection's malware tab is the only surface affected.
