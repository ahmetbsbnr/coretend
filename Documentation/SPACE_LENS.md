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
Space Lens is an **analysis view** — it does not delete anything. Use it to
understand where space goes, then act through Finder or the relevant cleanup
feature. Each completed scan is recorded as a dry-run activity entry
(name + total size + top-level item count).

## Accessibility
The treemap exposes an item-count and size summary to VoiceOver; the
keyboard-navigable child list is the accessible equivalent of the visual
fragments.
