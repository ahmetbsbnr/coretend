# Space Lens

Space Lens is a visual disk-usage explorer. Point it at a folder and it builds
a size tree (`SpaceLensEngine`), then renders a treemap you can drill into.

## Scanning
Scans a chosen root, summing real on-disk sizes. Symlinks are skipped (no
double-counting or loops), depth is capped defensively, and bytes past the cap
are still summed into their ancestor so totals stay honest. Scanning runs off
the main actor and can be cancelled at any time; results stream in with a live
item count.

## Navigation
Fragments are colored by semantic file category (folder, media, document,
archive, code, other) — never arbitrary index cycling. Click a directory
fragment to descend; a breadcrumb lets you pop back to any ancestor. Empty
directories and zero-size nodes are handled without errors.

## Actions
Space Lens is analysis-first. A real row can be revealed in Finder, previewed,
excluded, or selected for a Trash action. A destructive action requires an
explicit confirmation and is routed through `SafetyCenter` with an allowlist
scoped to the scanned root. After a completed move, Space Lens re-scans the
tree rather than guessing at updated totals. Each scan is recorded as a scan
activity entry (name + measured total + top-level item count).

## Accessibility
The treemap exposes an item-count and size summary to VoiceOver; the
keyboard-navigable child list is the accessible equivalent of the visual
fragments.
