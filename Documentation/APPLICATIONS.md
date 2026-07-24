# Applications

The Applications tab lists installed apps discovered under `/Applications` and
`~/Applications` (via `AppDiscovery`), with real metadata: size, last-used date,
publisher (from the bundle identifier), and update source.

## Update source detection
Each app's update mechanism is classified by the unit-tested
`AppDiscovery.updateMechanism` engine — never guessed from the name:
- **App Store** — a `_MASReceipt` is present in the bundle.
- **Homebrew Cask** — the bundle matches a real Caskroom receipt (token +
  installed path), read from Homebrew metadata, not fuzzy name matching.
- **Sparkle feed** — the bundle declares an `SUFeedURL`; only `https` feeds are
  surfaced (dangerous/non-https feed URLs are rejected).
- **In-app / manual** — none of the above; no auto-update mechanism is claimed.

The same engine feeds the "group by update state" view, so both stay in sync.

## Grouping
Group the list by None, Publisher, Size, Update State, or Last Used. Every
grouping key is derived from real `InstalledApp` data.

## Uninstall
Uninstall moves the app bundle and approved associated support files to the
**Trash** via `SafetyCenter` (medium-risk rule `apps.uninstall`), so it is
reversible from the Trash. It honors the global dry-run default: in dry-run it
reports what *would* be removed and the space that *would* be freed without
touching anything. Associated items are gathered conservatively and validated
by `PathValidator` against an allowlist before any move.

## What it does not do
No forced updates, no background installs, no telemetry. Update source is
informational; MacCare Local does not download or apply app updates for you.
