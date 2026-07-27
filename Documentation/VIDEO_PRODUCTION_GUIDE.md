<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Video Production Guide

Use the real public 0.9.0 artifact for installation media and the isolated
test-store launch described in `MEDIA_CAPTURE_GUIDE.md` for product media.
Record silent source at Retina resolution. Remove dead time, but never cut out
a security warning, permission step or failed action.

For installation, use a clean standard account or VM with no prior CoreTend
approval. Prepare the browser on the official domain with an empty history and
no visible profile. Keep only Finder, System Settings and CoreTend visible.
Record the real dialog text and the OS version. Produce full and short edits,
WebM and H.264, a WebP poster, English VTT captions and a text transcript.

Before retention, inspect the menu bar, desktop, Dock, Finder sidebar, browser
chrome and every frame for private data. Reject and re-record on any finding.
Run `Scripts/encode-media.sh` and `Scripts/check-media.sh`; do not commit editor
projects or original screen recordings.
