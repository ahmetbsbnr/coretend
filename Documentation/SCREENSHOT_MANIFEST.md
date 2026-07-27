<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Screenshot Manifest

No final screenshot is currently approved. A first capture run used the normal
macOS account with an isolated CoreTend store. Although the app-only frames
were visually clean, the later privacy requirement mandates a dedicated demo
account or VM. Those files were rejected before commit and removed.

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

Every accepted row must add: exact dimensions, file size, CoreTend version,
source commit, macOS version, capture date, synthetic dataset version,
`privacy_review: passed`, reviewer, review date, metadata removal and visual
inspection result. No media may be added before all fields pass.
