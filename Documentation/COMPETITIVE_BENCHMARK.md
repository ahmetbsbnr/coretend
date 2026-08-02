# Competitive benchmark

CoreTend measured against CleanMyMac and Disk Space Analyzer: Inspector,
following this project's own rule — measure what's measurable, mark
everything else `non vérifié`, never claim superiority without evidence.

## Method

Everything under "CoreTend (locally measured)" below was run on this
machine, this session (arm64, macOS 26.5.1), using scripts already in this
repo (`Scripts/test.sh`, `Scripts/measure-stability.sh`) — nothing
hand-typed. Neither competitor is installed on this Mac, and installing
either (a purchase for CleanMyMac; downloading closed-source software with
its own telemetry either way) isn't this session's call to make. Every
claim about them is therefore `non vérifié`, sourced only from their own
public marketing/documentation pages — never treated as fact, never used
to claim CoreTend is "better" at something nobody actually timed.

## CoreTend — locally measured

| Metric | Value | Source |
|---|---:|---|
| Cold launch (mean, 10 runs, fresh HOME each) | 24 ms | `Scripts/measure-stability.sh` |
| Idle resident memory (8s after launch) | 91 MiB | same |
| Idle CPU | 0.6% | same |
| Open file descriptors at idle | 52 | same |
| Threads at idle | 4 | same |
| Memory drift over 60s idle | −4 MiB | same |
| Memory drift over 100 launch/quit cycles | +1 MiB | same |
| Stray processes / leaked temp files after 100 cycles | 0 / 0 | same |
| App bundle size | 7.5 MB | `du -sh build/CoreTend.app` |
| Release binary size (unsigned, arm64) | 6.3 MB | `ls -la .build/release/CoreTend` |
| Cleanup scan | 12,000 files in 0.093s | `Scripts/test.sh` stress suite |
| Duplicate detection | 10,200 files / 500 groups in 1.66s | same |
| Similar-images clustering | 157 images (4 at 5000px²) in 0.95s | same |
| Space Lens — wide tree | 5,000 siblings in 0.40s | same |
| Space Lens — deep tree | 60 levels in 0.004s | same |
| Rapid-cancel teardown (Space Lens / scan engine) | 0.17s / 0.0005s | same |
| Local DB: insert / read | 8,000×2 rows in 0.58s / 3×200 rows in 0.007s | same |
| Test suite | 299 tests, 0 failures, ~7.5s | `swift test` |
| Build warnings (debug + release) | 0 | `swift build`, `swift build -c release` |
| Cleanup scan — 100,000 files | first result 3.5ms, total 0.81s | one-off measurement, 2026-07-31 (see note below) |
| Cleanup scan — 500,000 files | first result 44ms, total 15.0s | same |

**Note on the 100k/500k row:** measured by temporarily adding a test to
`Tests/ScanCoreTests/StressTests.swift` that generates real files under a
temp `HOME` and runs the real `ScanEngine` over them, run once via
`swift test --filter`, then reverted — not left in the permanent suite,
because writing 600k real files on every `swift test` run would slow CI for
everyone to re-derive a number that doesn't change. The 12k/10.2k fixtures
above stay permanent because they're cheap enough to run every time and
guard against a regression; 100k/500k are for this document, not a
regression gate.

### Scenarios from the request not measured this session

| Scenario | Status |
|---|---|
| Unicode filenames, deep trees | `non testé cette session` — the engine has no filename-encoding-specific code path, so failure here would be a filesystem-layer issue, not app logic, but this wasn't verified with an actual run |
| Symlinks | Covered indirectly: `Tests/ScanCoreTests/` "Scan root isolation" suite includes `symlinkedDirectoryNotDescended` — symlinked directories are never descended into (real test, real assertion), but a dedicated large-scale symlink stress run wasn't done this session |
| Hard links | Covered: the 10k-duplicate stress test above includes 100 real hard-link pairs and asserts they collapse to zero duplicate groups (same device+inode), not that they're merely "handled" |
| Permissions partially denied | `non testé cette session` |
| External volume, mounted DMG | `non testé cette session` — this machine has no external volume attached and mounting a DMG specifically to benchmark against felt like manufacturing a scenario rather than measuring a real one |
| Unmount mid-scan | `non testé cette session` |
| CPU/memory during a 100k+/500k+ scan (not just at idle) | `non testé cette session` — `measure-stability.sh` measures idle only; the stress tests above measure wall-clock, not CPU/RSS during the scan |

## CleanMyMac — `non vérifié`, from public sources only

| Claim | Status |
|---|---|
| Commercial, subscription pricing | Publicly stated on their site — not independently verified here |
| Requires an account for full functionality | Per public documentation — not tested |
| Includes a "Smart Care" one-click scan concept | Publicly documented feature name — CoreTend's own "Smart Care" module name predates any comparison and was not chosen to imitate it |
| Malware/antivirus module | Publicly advertised — no hands-on comparison performed |
| Telemetry / usage analytics | Not independently audited here — no claim made either way beyond what's publicly stated |

## Disk Space Analyzer: Inspector — `non vérifié`, from public sources only

| Claim | Status |
|---|---:|
| Free/paid tiers | Per App Store listing — not independently verified here |
| Visualization style (treemap-like) | Per public screenshots — not run side-by-side with CoreTend's Space Lens |
| Sandboxed / Mac App Store distribution | Per App Store presence — not independently audited |

## Where CoreTend's own design choices are structural, not a speed claim

These aren't "faster/better than X" — they're things true about CoreTend's
architecture, independently of any competitor, verifiable by reading the
source:

- **No telemetry, no account, no network calls except an opt-in,
  never-auto-triggered update check** (`Sources/CoreTendApp/UpdateChecker.swift`)
  that never downloads or installs anything itself.
- **No scanning engine for "Integrity"** — reads signals macOS already
  records (`Sources/IntegrityCore/`), not a signature database.
- **Review and explicit confirmation** guard every destructive module
  (Cleanup, Duplicates, Space Lens, Smart Care, Applications, Leftovers and
  Privacy Cleaner), enforced by the repository safety gate.
- **Eligible removals go to Trash**, never a permanent delete, across every
  module that moves anything.
- **Open source** — every claim in this document, and every number in the
  table above, can be checked against `Sources/` and `Scripts/` directly.

## What this document is not

Not a claim that CoreTend is faster, safer, or better-designed than either
competitor as a whole product — that would require the same rigor applied
to them that's applied to CoreTend above, which wasn't done here. It's a
factual record of what CoreTend itself measures to, so a future comparison
(if either competitor is ever actually installed and measured) has a real
baseline to compare against instead of starting from zero.
