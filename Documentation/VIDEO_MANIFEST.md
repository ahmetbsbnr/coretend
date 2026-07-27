<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Video Manifest

No final video is currently approved. A 10.8-second real app navigation clip
was produced, then rejected and removed because it was recorded from the normal
macOS account rather than a dedicated CoreTend Demo account.

| ID | Title / function | CoreTend | macOS | Commit | Target duration | Target format | Poster | Captions / transcript | Site | Reduced motion | Privacy | Status |
|---|---|---|---|---|---:|---|---|---|---|---|---|---|
| product-tour | Module navigation and first orientation | 0.9.0 arm64 | record exact | release commit | 12–20 s | VP9 + H.264, silent | required | VTT + transcript | home/demos | poster; no autoplay | frame-by-frame review | HUMAN_REVIEW_REQUIRED |
| install-full | Official site to installed/relaunched app | 0.9.0 arm64 | record exact | release commit | 60–90 s | VP9 + H.264, silent | required | VTT + transcript | install | no autoplay | frame-by-frame review | HUMAN_REVIEW_REQUIRED |
| install-short | First-open per-app route | 0.9.0 arm64 | record exact | release commit | 20–30 s | VP9 + H.264, silent | required | VTT + transcript | download | no autoplay | frame-by-frame review | HUMAN_REVIEW_REQUIRED |
| getting-started | Interface, first dry run, settings/help | 0.9.0 arm64 | record exact | release commit | 40–60 s | VP9 + H.264, silent | required | VTT + transcript | help | controls only | frame-by-frame review | HUMAN_REVIEW_REQUIRED |

Final rows must include exact duration, dimensions, codec, byte size, SHA-256,
poster, subtitle and transcript paths, capture date, demo dataset version,
privacy reviewer, number of extracted review frames, audio-stream count and
metadata audit result.
