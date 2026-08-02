<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Video Manifest

One genuine Gatekeeper clip is approved and exported. Earlier captures remain
excluded unless their individual status below changes after a complete review.

| ID | Title / function | CoreTend | macOS | Commit | Target duration | Target format | Poster | Captions / transcript | Site | Reduced motion | Privacy | Status |
|---|---|---|---|---|---:|---|---|---|---|---|---|---|
| product-tour | Module navigation and first orientation | 0.9.0 arm64 | record exact | release commit | 12–20 s | VP9 + H.264, silent | required | VTT + transcript | home/demos | poster; no autoplay | frame-by-frame review | HUMAN_REVIEW_REQUIRED |
| install-full | Official site to installed/relaunched app | 0.9.0 arm64 | record exact | release commit | 60–90 s | VP9 + H.264, silent | required | VTT + transcript | install | no autoplay | frame-by-frame review | HUMAN_REVIEW_REQUIRED |
| install-short | First-open per-app route | 0.9.0 arm64 | record exact | release commit | 20–30 s | VP9 + H.264, silent | required | VTT + transcript | download | no autoplay | frame-by-frame review | HUMAN_REVIEW_REQUIRED |
| getting-started | Interface, first scan, reviewed confirmation, settings/help | current arm64 release | record exact | release commit | 40–60 s | VP9 + H.264, silent | required | VTT + transcript | help | controls only | frame-by-frame review | HUMAN_REVIEW_REQUIRED |
| gatekeeper-blocked | Genuine first-open warning | 0.9.0 arm64 | wording varies by macOS release | `a6aa3bf` | 7.75 s | VP9 WebM 103,851 B; H.264 MP4 145,125 B; 926×880; 24 fps; no audio | `Website/assets/demos/gatekeeper-blocked-poster.webp`, 9,018 B | `Website/assets/demos/gatekeeper-blocked.vtt`; `Documentation/Media/coretend-gatekeeper-blocked-transcript.md` | demos/install | controls only; poster before play | full raw and sampled-frame review; metadata stripped | APPROVED |

Approved export SHA-256:

- WebM: `fa22ec16fe6c748807215eee7de142a6bb864372b22cfb47bad6c3d0874ae551`
- MP4: `e180e42b63fcd7c1cf4566e0de267c79c86b5867c374f937632c1b80fe95ad08`
- Poster: `a04ab6edffea04c3785f426e09c96d67203f2f331bd381189048b851e332f2b7`
- VTT: `a2cab7d250355341c1a8c4889936db023d06c6212afa64f1d68b31cff078d750`

Source: `$MEDIA_WORKSPACE/CoreTendMedia/raw/coretend-step-03-gatekeeper-blocked-raw.mov`,
captured 2026-07-27. Reviewer: automated metadata inspection plus full visual
review recorded in `MEDIA_REVIEW_REPORT.md`. The raw is not stored in Git.

Final rows must include exact duration, dimensions, codec, byte size, SHA-256,
poster, subtitle and transcript paths, capture date, demo dataset version,
privacy reviewer, number of extracted review frames, audio-stream count and
metadata audit result.
