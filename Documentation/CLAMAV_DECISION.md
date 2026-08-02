# Why ClamAV was retired for Integrity

## Decision

CoreTend no longer ships, links, vendors, or invokes ClamAV or any
`clamscan` binary in any way. The `Sources/MalwareEngine` module (the
ClamAV process wrapper, output parser, watcher, and quarantine mechanism)
was deleted in `eac408c` (`refactor(protection): retire ClamAV, replace
with native Integrity signals`) and replaced by `Sources/IntegrityCore`,
described in [PROTECTION.md](PROTECTION.md). There is no user-installed,
optional, or otherwise reachable ClamAV code path left in the product —
this is a full removal, not a change of default.

## Why

The prior Protection tab wrapped a user-installed `clamscan` binary
(ClamAV). Using it required the user to open Terminal and run
`brew install clamav` — a hard violation of this project's own bar for
every feature ("never Terminal, never Homebrew"). Building a fully in-app
installer/updater for a third-party GPL-2.0-licensed scanning engine was a
real distribution and licensing undertaking this project had not had legal
review for. Rather than ship a Terminal-dependent version of itself, or
take on unreviewed GPL distribution risk, the feature was retired outright.

## What replaced it

Integrity (`Sources/IntegrityCore/IntegrityCore.swift`,
[PROTECTION.md](PROTECTION.md)) reads signals macOS already records —
download-quarantine metadata, code-signature tier via the Security
framework, and login items — with no scanning engine, no signature
database, no third-party binary, and nothing downloaded. It is explicitly
not a malware scanner and does not claim to be one; see
[PROTECTION_LIMITATIONS.md](PROTECTION_LIMITATIONS.md).

## What was removed

Full accounting of every test removed or changed by this refactor is in
[CLAMAV_TEST_AUDIT.md](CLAMAV_TEST_AUDIT.md): 34 tests net (40 ClamAV/
MalwareEngine/quarantine/watcher tests removed, 6 added for the new
IntegrityCore surface), verified by diffing `Tests/` and counting `@Test`
occurrences across `eac408c~1` and `eac408c`. [QUARANTINE.md](QUARANTINE.md)
keeps the old quarantine mechanism's behavior on record, verbatim, marked
historical.

## Historical mentions elsewhere

Older audit documents under `Documentation/Archive/` and point-in-time
baselines such as `MASTER_REQUIREMENTS_BASELINE.md` (audited against a
commit prior to `eac408c`) may still describe the retired, optional
"user-installs-ClamAV-and-CoreTend-shells-out-to-it" design as if current.
That description was accurate at the commit those documents audit; it is
not accurate for the current product. `Sources/`, `Resources/`, and
`Website/` contain zero references to ClamAV or `clamscan` as of this
writing — verified by `grep -rli clamav\|clamscan Sources/ Resources/
Website/`.
