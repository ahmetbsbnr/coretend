<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# User Journey QA

| Role | Goal and path | Block / confusion | Steps | Improvement | Result |
|---|---|---|---:|---|---|
| Beginner | Site → Download → DMG → Applications → per-app Open → onboarding | unsigned first-open route was previously buried; Terminal appeared too early | 6 primary stages | DMG is primary, graphical numbered guide, ZIP and SHA-256 are secondary | locally prepared; clean-account run pending |
| Cautious user | release identity → sizes/hashes → optional SHA-256 → permissions/security | checksum could be mistaken for signing | 5 | explicitly separates byte identity from signing/notarization | pass by document review |
| Technical user | manifest/checksums → source commit → build/tests/audits | information was scattered | 5 | README and download page link authoritative files | pass |
| Contributor | README → development → architecture → tests → contribution | stale pre-release README | 5 | current visual README and repository setup checklist | pass |
| Assistive technology user | skip link → headings → numbered install → static reduced-motion fallback | none reported | verified | semantic steps, adjacent descriptions, no essential JS, reduced-motion poster | PASS by maintainer interactive QA, 2026-09-04 |

Measured public downloads on this network: ZIP 5.82 seconds, DMG 6.00 seconds,
manifest 0.86 seconds, checksums 2.07 seconds. These are QA observations, not
marketing claims. Finding the download, Finder copy, per-app approval and first
use timing still require the clean-profile recording.

## One-session human completion

Use a new standard account or arm64 macOS VM. Start screen recording with an
empty browser profile on `https://coretend.ahmetbsbnr.com`. Perform DMG install,
double-click block, Control-click Open, Privacy & Security alternative,
onboarding skip/back, permission accept/refuse/retry, first Smart Care scan and confirmed Trash action,
quit, relaunch, same-version replacement and graphical uninstall. Repeat ZIP
extraction. Record elapsed times and clicks. Then run VoiceOver, keyboard-only,
200% zoom and Reduce Motion checks. Reject the recording if any personal data
is visible.
