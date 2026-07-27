<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Screenshot Manifest

One cropped application-only screenshot is approved. Earlier captures remain
excluded unless their individual status below changes after a complete review.

| ID | Feature | Planned file | Appearance | Site | README | Required alt text | Status |
|---|---|---|---|---|---|---|---|
| main-dark | Smart Care and navigation | `coretend-main-window-dark.png` | dark | hero/demos | hero | CoreTend 0.9.0 Smart Care window with module navigation and scan controls | HUMAN_REVIEW_REQUIRED |
| main-light | Smart Care and navigation | `coretend-main-window-light.png` | light | hero | hero light source | CoreTend Smart Care in light appearance | HUMAN_REVIEW_REQUIRED |
| cleanup | Cleanup review | `coretend-cleanup-review.png` | dark | gallery | gallery | CoreTend Cleanup review screen using synthetic demo files | HUMAN_REVIEW_REQUIRED |
| performance | Live metrics | `coretend-performance.png` | dark | gallery | gallery | CoreTend live performance metrics | HUMAN_REVIEW_REQUIRED |
| applications | App inventory | `coretend-applications.png` | dark | demos | — | CoreTend Applications inventory with neutral data | HUMAN_REVIEW_REQUIRED |
| clutter | My Clutter | `coretend-my-clutter.png` | dark | demos | — | CoreTend My Clutter tools with synthetic files | HUMAN_REVIEW_REQUIRED |
| space-lens | Disk map | `coretend-space-lens.png` | dark | demos | gallery | CoreTend Space Lens map of the Demo Workspace | HUMAN_REVIEW_REQUIRED |
| protection | Optional scan | `coretend-protection.png` | dark | demos | — | CoreTend Protection showing its real engine state | HUMAN_REVIEW_REQUIRED |
| settings | Permissions and safety | `coretend-settings-light.png` | light | getting started | gallery | CoreTend settings and permission status | HUMAN_REVIEW_REQUIRED |
| gatekeeper | Real first-open block | `coretend-first-launch-gatekeeper.png` | system | install guide | — | macOS first-open warning for CoreTend on the stated OS version | HUMAN_REVIEW_REQUIRED |
| menu-bar | Menu bar status panel | `Website/assets/app/menu-bar.png` and `.webp` | dark | home/demos | planned | CoreTend 0.9.0 menu bar panel showing CPU, memory, free space, thermal state and protection status | APPROVED |

Approved export details:

- Dimensions: 660×806.
- PNG: 232,364 bytes, SHA-256
  `1da767c9b50f43b61539b70e73e8ba3df19ebf2c05a3ff73e22e77b6d256b756`.
- WebP: 125,174 bytes, SHA-256
  `058796dc7cf65448f432180747ea4e042f833eab2ee603caa4ef9d71bbf32d86`.
- CoreTend: 0.9.0 arm64 capture session; source commit `a6aa3bf`.
- Capture/review date: 2026-07-27. macOS exact version was not embedded and is
  therefore not guessed.
- Source:
  `$MEDIA_WORKSPACE/processing/incoming/coretend-additional-screen-review.png`.
- Privacy review: passed. Full pixels, metadata, PNG chunks, and extended
  attributes were inspected; exports contain no author, username, path, GPS,
  URL, account, or screenshot comment.
- The approved exports are recompressed copies. The source remains untouched
  outside Git.

Every accepted row must add: exact dimensions, file size, CoreTend version,
source commit, macOS version, capture date, synthetic dataset version,
`privacy_review: passed`, reviewer, review date, metadata removal and visual
inspection result. No media may be added before all fields pass.
