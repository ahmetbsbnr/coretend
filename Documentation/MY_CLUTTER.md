# My Clutter

My Clutter helps you find space-heavy or forgotten content. It has three
sub-modules. See also [CLEANUP_GUIDE.md](CLEANUP_GUIDE.md) for Duplicates and
Similar Images, which share the same engines.

## Large & Old Files
Scans user-content folders only — Downloads, Documents, Desktop, Movies, Music,
Pictures — for files larger than a size threshold (default 100 MB) not modified
in an age threshold (default 30+ days). Both thresholds are adjustable.

**Read-only by design.** There is no deletion path: findings can be sorted (by
size or age), previewed with Quick Look, and revealed in Finder. User-content
locations are deliberately outside the deletion allowlist, so nothing here can
be auto-deleted — you decide and act in Finder. Results are capped at 2000
items; unreadable/permission-denied paths are skipped without crashing.

## Duplicates
Byte-identical file detection: size bucket → 64 KB partial hash → full SHA-256.
Hard links are collapsed, symlinks and remote-only iCloud files are skipped. The
shallowest-path copy is chosen as the keeper and can never be fully removed;
`wastedBytes` counts copies minus the keeper. Removal is Trash-based via
`SafetyCenter`. A mid-scan-edit guard (`hasChangedOnDisk`, using a fresh URL
read) deselects any copy whose modification time changed since the scan before
trashing.

## Similar Images
Perceptual near-duplicate detection using Vision feature-prints. Supports jpg,
png, heic, gif, tiff, webp, bmp; respects EXIF orientation; reads pixel counts
from metadata only (no full decode, so memory stays bounded). Corrupt images,
Photos-library items, and remote-only iCloud files are skipped. Clustering is
greedy at a configurable threshold; the best-resolution image is suggested as
the one to keep. **Reveal-only — no deletion path**, so nothing is ever
auto-deleted.
