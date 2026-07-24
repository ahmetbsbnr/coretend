# Cloud Cleanup

Cloud Cleanup analyzes the **local** folders of cloud providers and shows how
much space files actually occupy on this Mac versus their logical (cloud) size.

## Provider detection
Detects known local roots under your home directory (pure, fixture-testable —
`detectProviders(home:)`):
- iCloud Drive — `Library/Mobile Documents/com~apple~CloudDocs`
- Dropbox — `~/Dropbox`
- Google Drive / OneDrive — `Library/CloudStorage/…` (including the
  provider-named `GoogleDrive-…`, `OneDrive-…`, `Dropbox-…` entries)

Detection only checks for the existence of these local roots. It never opens,
downloads, or mounts anything.

## Sync-state classification
Each entry is classified from real signals (`SyncState.classify`):
- **local** — fully downloaded (local bytes ≥ logical bytes).
- **placeholder** — not downloaded (`ubiquitousItemDownloadingStatus` reports
  not-current, or local bytes are under 10% of logical).
- **partial** — a mix of downloaded and not-downloaded children.

There is no public API to read Finder's per-item "Keep Downloaded" pin state, so
this module does not claim a pinned state it cannot verify.

## What it does — and does not — do
It measures. `recoverableLocalBytes` is the bytes actually on disk today and is
**informational**, not an action total. Cloud Cleanup **never downloads and
never deletes** — a synced deletion would propagate to every device, so that
action is deliberately absent. Reclaim space using the provider's own Finder
integration ("Remove Download" / "Free Up Space") after you've seen what's local.
