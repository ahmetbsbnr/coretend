# APFS Intelligence

Read-only vertical answering two questions: "why don't displayed sizes always
match real disk usage?" and "how is my APFS storage really used?". See
`Documentation/FEATURE_MATRIX.md` → "APFS Intelligence" for the sub-capability
status table and `Documentation/SAFETY_MODEL.md` → "APFS Intelligence" for why
it can never become a destructive or Recovery-Plan-eligible surface.

## Guiding principle: Measured > Estimated > Unknown

Every value CoreTend shows here is either a real number read from a real API,
or an explicit "Unavailable" with the reason. Nothing in this vertical
estimates, derives-by-subtraction, or interpolates a number and presents it as
measured. `APFSMetric<Value>` (`Sources/SystemMetrics/APFSVolumeInspector.swift`)
encodes exactly two states — `.measured(Value)` and `.unavailable(reason:)` —
deliberately no `.estimated` case exists, because nothing in this vertical
computes one. If a future capability genuinely needs a derived estimate, it
must add and clearly label that case rather than silently dressing an
estimate up as `.measured`.

## Logical size vs. physical (allocated) size

**Logical size** is the size of a file's content — `URLResourceValues
.fileSize` / `.totalFileSize`. **Physical (allocated) size** is what the
filesystem actually reserves for it — `URLResourceValues
.totalFileAllocatedSize`, backed by `totalFileAllocatedSizeKey`. They differ
in both directions: sparse files make physical far smaller than logical;
block-size rounding can make physical slightly larger.

Verified directly against the real filesystem in
`Tests/SystemMetricsTests/LogicalVsPhysicalSizeTests.swift` (7 tests): a
normal file, a zero-byte file, a real sparse file (created with
`FileHandle.truncate(atOffset:)`, ~50 MB logical vs. a few KB physical —
genuine APFS behavior on the development machine, not simulated), a hard
link, a symlink, a directory (no meaningful file size), and an inaccessible
path (throws rather than fabricating a number).

### The pairing rule

A physical total is only ever paired with a logical total that describes the
**exact same file set**. `TimelineCategorySample.physicalBytes` (Persistence
schema v6+) is populated **only** from `[ScanFinding]
.totalAllocatedSizeIfFullyKnown` (`Sources/ScanCore/ScanCore.swift`) computed
over the identical findings whose logical bytes were already being recorded
for that same category — never a different scan's total, never a whole-volume
figure mixed with a scan's subtotal. That extension returns `nil` — not `0` —
the moment even one finding in the set lacks an allocated-size measurement, so
a partial total can never silently pass as complete; an empty finding set
(nothing found) is a genuine measured zero, not "unavailable".

Only **Cleanup** feeds `physicalBytes` today. It is the only wired Timeline
scope whose scan (`ScanEngine`) already captures both `logicalSize` and
`allocatedSize` per finding from the same enumeration pass. Duplicates,
Leftovers, and Privacy each report only one dimension internally (Duplicates:
logical bytes from `DuplicateEngine`; Leftovers/Privacy: `AppDiscovery`'s
already-blended size), so extending physical-size reporting to them would mean
adding a second filesystem walk per scan purely for this feature — rejected
per the performance constraint below. `physicalBytes` is `nil` for every
Duplicates/Leftovers/Privacy category, on every snapshot, old and new alike.

### Timeline compatibility

Snapshots recorded before this feature have `physicalBytes = nil` for every
category (the column did not exist to populate). Snapshots recorded after
have it populated for Cleanup, `nil` for the other three scopes. A comparison
UI must treat all four of these as valid, ordinary states — never coerce
`nil` to `0` — and only render a physical-size comparison when **both**
compared points have a non-nil value for that category. No UI comparing
physical bytes across snapshots exists yet in this pass (the new APFS screen
shows only the latest Cleanup snapshot's own logical/physical pair, not a
delta), so this constraint is currently enforced by construction (nothing
computes such a delta) rather than by a runtime guard — a future feature
adding that comparison must add the guard itself.

### Why "Files analyzed" doesn't re-scan

`APFSIntelligenceService.filesAnalyzed(store:)` reads the most recent
`cleanup`-scope Timeline snapshot already recorded by a real Cleanup scan; it
never triggers a new filesystem walk. Running a second full disk scan just to
power this screen would duplicate Cleanup's own cost for no new information.
The tradeoff is disclosed, not hidden: if no Cleanup scan has ever run, the
screen says so and links to Cleanup rather than showing a fabricated number.

### Performance: why `totalFileAllocatedSizeKey` is not requested everywhere

`ScanEngine` (Cleanup) already requested `.totalFileAllocatedSizeKey` before
this feature (`ScanFinding.allocatedSize` predates this pass); this feature
only adds the aggregation on top, not a new resource-key request, so Cleanup's
scan cost is unchanged. `SpaceLensEngine` and `AppDiscovery` already request
the same key for their own (different) purposes. No scanner had a new
resource key added specifically for APFS Intelligence, so no benchmark was
needed to justify a new per-file cost — there isn't one.

## Volume capacity and availability semantics

`APFSVolumeInspector.inspect(path:)` reads, per Apple's own definitions,
without renaming any of them:

| CoreTend label | `URLResourceKey` | Meaning (Apple's, not CoreTend's) |
|---|---|---|
| Capacity | `volumeTotalCapacityKey` | Total volume capacity |
| Available | `volumeAvailableCapacityKey` | Available capacity, conservative |
| Available for important usage | `volumeAvailableCapacityForImportantUsageKey` | Available capacity if the app deletes purgeable content it doesn't need and other apps cooperate similarly, for a use the user is actively waiting on |
| Available for opportunistic usage | `volumeAvailableCapacityForOpportunisticUsageKey` | Available capacity for a use that can wait, i.e. before other apps' purgeable content is evicted |

None of these is labeled "Purgeable Space" anywhere in CoreTend. Apple's own
important/opportunistic-usage keys are not a direct, stable measurement of
"how much purgeable data exists" — they answer "how much could become
available under certain conditions", which is a different question. Renaming
`volumeAvailableCapacityForImportantUsageKey` to "Purgeable" would assert a
semantic the API does not actually guarantee.

CoreTend does **not** assert `Capacity = Available + Used` anywhere, because
APFS container-level space sharing between volumes does not guarantee that
identity. Each figure is shown with its own definition; there is no derived
"Used" figure computed as a subtraction.

Filesystem type is read via Darwin's `statfs()`/`f_fstypename` — a stable,
non-localized C API — rather than a subprocess or a localized description
string. `isAPFS` is a plain `fsType == "apfs"` check.

## Storage sharing (clones and hard links) — deliberately unavailable

APFS lets files share underlying storage (clones from `cp` / `Duplicate`, or
copy-on-write behavior) or link multiple directory entries to the same data
(hard links). CoreTend does **not** claim a "you have N GB of clones/shared
storage" figure anywhere. `logical > allocated` alone does not license that
claim — it can also come from sparse regions, block rounding, or compression,
none of which are "storage shared between two files". No public, stable API
surveyed for this pass lets CoreTend attribute *how much* space two files
share, so this stays `Unavailable`, with that exact reason, rather than
computed from an equivalence that doesn't hold.

### Pre-existing hard-link double-counting (found during this audit, not introduced by it)

`DuplicateEngine` is hard-link-safe: it collapses candidates sharing a
`(device, inode)` identity (`fileResourceIdentifierKey`) before comparing
content, so a hard-linked file is never counted as its own duplicate
(`Tests/SystemMetricsTests/LogicalVsPhysicalSizeTests
.hardLinkedFilesReportTheSameAllocationNeverDoubleCounted` also directly
verifies the underlying resource-identifier behavior this depends on).

`ScanEngine` (Cleanup), `SpaceLensEngine`, and `AppDiscovery.directorySize`
do **not** request `fileResourceIdentifierKey` and do not deduplicate by
inode: if two hard-linked names both fall inside a scanned tree, both logical
and (where requested) allocated bytes are summed once per *name*, not once
per unique file. This is pre-existing behavior, unrelated to this feature,
and it means `[ScanFinding].totalAllocatedSizeIfFullyKnown` — and therefore
`TimelineCategorySample.physicalBytes` for Cleanup — inherits the same
per-name (not per-inode) counting as Cleanup's existing logical-byte total
always has. It is disclosed here rather than silently fixed only for the new
metric, because fixing it only for physical bytes while leaving logical bytes
per-name would make the two numbers describe subtly different perimeters —
violating the pairing rule above. A full fix (deduplicating by inode across
all three call sites) is out of scope for this read-only pass and is left as
a documented, tracked limitation rather than an unaudited refactor of
production scan paths.

## Snapshots — concept only, not listed (this version)

CoreTend explains what an APFS/Time Machine local snapshot is
(`apfs.snapshots.concept`) but does not enumerate real snapshots, compute an
individual snapshot's size, or distinguish a generic APFS snapshot from a
Time Machine local snapshot in this pass. Reliable listing on macOS 14+
requires either `tmutil`/`diskutil` subprocess execution or a private API;
this codebase has zero production `Process` usage today (confirmed by
auditing `Sources/`) and CoreTend's entitlements file documents a deliberate
"no external process capability" design stance. Rather than introduce the
first subprocess dependency in the codebase for a feature this pass can ship
without it, snapshot listing is left `PARTIAL` / not implemented, disclosed
as such (`apfs.snapshots.not_listed`), not silently omitted. A snapshot size
is never computed as "the difference between two volume measurements" —
that would attribute filesystem noise (ordinary usage between the two
readings) to the snapshot.

**No snapshot deletion, thinning, or any destructive snapshot operation
exists anywhere in this codebase — not behind a flag, not unwired, not for
future use.** A future Snapshot Manager would need its own, separately
reviewed safety model; this vertical does not lay any groundwork for one.

## Non-APFS volumes

`APFSVolumeInfo.isAPFS` is `false` whenever `statfs()` reports a
`f_fstypename` other than `"apfs"`. The APFS screen shows a plain notice
(`apfs.not_apfs`, naming the real filesystem type) and skips APFS-specific
sections; generic volume capacity/availability figures (which are not
APFS-specific APIs) remain shown, since they are meaningful for any
filesystem. No APFS-specific operation is attempted on a non-APFS volume.

## Environment limitation (disclosed, not hidden)

`Tests/SystemMetricsTests/APFSVolumeInspectorTests.swift`'s real-volume suite
assumes the machine running the tests boots from APFS — the only filesystem
type it can exercise without a mounted non-APFS volume in CI/dev. It does not
assert `isAPFS == true` as a hardcoded expectation disconnected from reality;
it reads `APFSVolumeInspector.filesystemTypeRaw` for both `/` and the home
directory and asserts internal consistency (same type reported for both),
plus plausible (not exact) capacity bounds. No test in this pass exercises a
real ExFAT/HFS+/SMB/disk-image volume — `isAPFS` and the non-APFS notice path
are proven by inspecting the type-detection logic and its `nil`/failure paths
(`APFSVolumeInspectorFailureTests`), not by mounting a second filesystem.
**HUMAN VERIFICATION REQUIRED** to confirm on-screen behavior against a real
non-APFS volume (e.g. a FAT32 USB drive or SMB share).

## Summary: measured / derived / unavailable

| Metric | Status | Source |
|---|---|---|
| Volume capacity | Measured | `volumeTotalCapacityKey` |
| Volume available | Measured | `volumeAvailableCapacityKey` |
| Available (important usage) | Measured | `volumeAvailableCapacityForImportantUsageKey` |
| Available (opportunistic usage) | Measured | `volumeAvailableCapacityForOpportunisticUsageKey` |
| Filesystem type / is-APFS | Measured | Darwin `statfs()` / `f_fstypename` |
| Logical size (per scanned file) | Measured | `fileSizeKey` |
| Physical/allocated size (per scanned file) | Measured | `totalFileAllocatedSizeKey` |
| Physical size, Cleanup category total | Measured (when every finding in the category has it), else Unavailable | `[ScanFinding].totalAllocatedSizeIfFullyKnown` |
| Physical size, Duplicates/Leftovers/Privacy category total | Unavailable | Not computed — no second-dimension data captured by those engines |
| Clone/shared-storage attribution | Unavailable | No stable public API found to attribute shared bytes to individual files |
| Snapshot listing | Not implemented (PARTIAL) | Would require subprocess execution CoreTend does not currently do |
| Individual snapshot size | Unavailable | Not computed; never derived by subtraction |
| "Purgeable space" as a named figure | Not shown | Apple's key does not have that exact semantic; not renamed |
