# Deep Scan — Full Disk Access QA

Spec §22 / §24. How Deep Scan behaves with and without Full Disk Access (FDA),
and what the UI must (and must not) claim.

## The four states

`DeepScanPermissionProbe.probe()` (read-only: tries to list a few TCC-gated
locations — `~/Library/Application Support/com.apple.TCC`, `~/Library/Mail`,
`~/Library/Safari`) resolves one of:

| State | Meaning | UI copy |
|---|---|---|
| **Full Disk Access** | every probed gated location is readable | "Full Disk Access is on — the whole home volume can be analysed." |
| **Partial Access** | some probed locations exist but are not readable, or none could be probed | "Partial access — some folders are hidden by macOS. Grant Full Disk Access in System Settings › Privacy & Security for a complete picture." |
| **Protected by macOS** | locations exist but are OS-protected | "Some locations are protected by macOS and will be reported as such." |
| **Scan error** | the last scan hit an I/O error mid-read | "The last scan hit an error reading part of the disk." |

The scan **always runs** regardless of state; it degrades, it does not refuse.

## Engine behaviour per state

`DeepScanEngine` records, per node, a `ScanCompleteness`:

- **complete** — directory listed, every child observed.
- **permissionDenied** — `contentsOfDirectory` / `lstat` refused. Bytes are
  **0** (never guessed). The node's canonical path is added to
  `DiskGraph.deniedRoots`.
- **partial** — a parent whose subtree is not fully `complete` (rolls up).
- **notEnumerated** — discovered but not descended (depth cap, mount boundary,
  cancel/timeout).

`DiskGraph.subtreeFullyObserved(path)` is `false` whenever any descendant is
not `complete`, which forces:

- `CONFIRMED` confidence is impossible (RiskConfidenceModel hard rule).
- The candidate carries `subtreeIncomplete` evidence ⇒ can never enter the
  executable subset, can never be default-selected.

So **a partial scan can never produce an auto-actioned deletion.**

## Measured on the maintainer Mac (read-only)

`DeepScanQA` over `~/.claude ~/.codex ~/.cache ~/Library/Caches ~/Developer
~/Downloads ~/Library/LaunchAgents`, current FDA state on this machine:

| Metric | Value |
|---|---|
| Permission state reported | Partial Access (Terminal has no FDA here) |
| Nodes observed | 125,670 |
| Permission-denied nodes | 9 |
| Roots reported unreadable (`deniedRoots`) | `~/Library/Caches/CloudKit`, `…/com.apple.Safari`, `…/com.apple.HomeKit`, `…/com.apple.containermanagerd`, `…/com.apple.homed`, and similar Apple-daemon caches |
| Candidates flagged in those denied roots | 0 (bytes 0, not guessed) |
| Safety self-check | 0 protected / unknown / `~/.claude`-memory pre-selected |

With FDA granted, the same run would additionally read the Apple-daemon cache
subtrees above (a few MB each) and the `com.apple.*` container internals — none
of which change the candidate set, because `com.apple.*` is excluded from the
orphaned-leftover detector by design.

## UI rules verified in code

- The results header shows `deniedRoots.count` as "N folders blocked by
  permissions" during the scan and the count persists into the results — the
  UI **never** presents a partial scan as complete.
- `DeepScanProgressModel.isPartial` is set on cancel/timeout and the results
  are labelled reduced-confidence.
- The entry-screen banner is shown **before** the user starts a scan so the
  expectation is set up front.

## HUMAN VERIFICATION REQUIRED

- Toggling FDA for CoreTend.app in System Settings and confirming the banner
  switches Full ⇄ Partial live.
- The exact wording/discoverability of the "grant FDA" guidance in the running
  app.
- Behaviour on a Mac where `~/Library/Mail` etc. genuinely do not exist (the
  probe treats "nothing to probe" as Partial — conservative, but should be
  eyeballed).
