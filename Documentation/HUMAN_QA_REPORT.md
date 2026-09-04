# Human QA Report — CoreTend

Status: **PASS — maintainer attestation received 2026-09-04**. Maintainer
confirmed all interactive assistive-technology and second-Mac checks passed.
Hardware identifiers and exact secondary macOS build were not supplied, so
those facts remain explicitly unrecorded.

## Test environment

| Field | Primary Mac | Second Mac |
|---|---|---|
| Tester / date | maintainer / 2026-09-04 | maintainer / 2026-09-04 |
| Hardware / chip | Apple silicon; model not supplied | different Mac; model not supplied |
| macOS version / build | supported; exact build not supplied | different supported macOS; exact build not supplied |
| CoreTend version / SHA-256 | 1.0.0 / published artifact | 1.0.0 / published artifact |
| Fresh install or upgrade | verified; path not supplied | verified; path not supplied |

## Interactive assistive-technology pass

Record PASS/FAIL plus observation for every row. Do not mark PASS from source
inspection or automated tests.

| Check | Result | Observation / issue |
|---|---|---|
| VoiceOver: sidebar order, headings, rotor | PASS | Maintainer verified interactively. |
| VoiceOver: every icon-only control named | PASS | Maintainer verified interactively. |
| VoiceOver: charts, progress, selection counts and warnings announced | PASS | Maintainer verified interactively. |
| VoiceOver: reviewed selection and Trash confirmation unambiguous | PASS | Maintainer verified interactively. |
| Keyboard only: every module and control reachable | PASS | Maintainer verified interactively. |
| Keyboard only: focus order logical and focus ring visible | PASS | Maintainer verified interactively. |
| Keyboard only: Return/Space activate; Escape closes sheets/popovers | PASS | Maintainer verified interactively. |
| Dynamic Type: largest accessibility size, no hidden action or clipped text | PASS | Maintainer verified interactively. |
| 860×580 and full screen in both appearances | PASS | Maintainer verified interactively. |
| Reduce Motion and Reduce Transparency | PASS | Maintainer verified interactively. |

## Cross-Mac compatibility

On both machines: launch signed DMG, verify Gatekeeper acceptance, complete
every sidebar module's non-destructive path, perform one reviewed test-dataset
Trash action, restore it, export diagnostic preview, quit, relaunch, inspect
Console for crash/fault. Record deviations above.

## Native visual matrix

Executed `Scripts/capture-native-matrix.sh <review-directory>` from GUI session
with Screen Recording and Accessibility permission. Expected output: 44 PNGs
(11 modules × EN/FR × light/dark). Human reviewer checks hierarchy, clipping,
localization, contrast, real empty/error states, and personal-data leakage.
Maintainer accepted matrix. All 44 captures now live under
`Documentation/VisualAudit/After/` with `2026-09-04-` prefix and approved
manifest entries.

## Sign-off

- Tester: maintainer
- Reviewer: maintainer
- Blocking defects: none reported
- Final verdict: **PASS**
