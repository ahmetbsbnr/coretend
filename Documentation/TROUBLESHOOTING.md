<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Troubleshooting

| Symptom | Likely cause / check | Safe resolution | Do not |
|---|---|---|---|
| DMG does not open | incomplete download; compare size/hash | download again from the official release | bypass disk-image verification |
| ZIP does not extract | incomplete or changed file | verify SHA-256, then download again | use the damaged bundle |
| Checksum differs | file is not byte-identical to the published asset | delete it and download again; report repeatable mismatch | open it anyway |
| CoreTend cannot be opened | expected unsigned/not-notarized block | use the per-app Finder or Privacy & Security route in `GATEKEEPER_GUIDE.md` | disable Gatekeeper or SIP |
| No per-app option appears | wrong OS/architecture, incomplete copy, policy restriction | confirm macOS 14+, Apple silicon and `/Applications`; contact support | remove quarantine globally |
| App disappears after cleanup | it was run from a temporary extraction location | copy it to Applications before deleting the ZIP/temp folder | keep the only copy in a temp folder |
| Permission refused | feature has reduced coverage | reopen Settings in CoreTend and use its link to System Settings | grant unrelated permissions |
| Scan finds nothing | empty scope, exclusion, missing permission or no eligible items | review scope/exclusions and the module explanation | fabricate test data in a real folder |
| Old version still open | existing process | quit it, replace the app, launch again | overwrite a running bundle |
| Already running | menu-bar or hidden window remains | use the menu-bar Open action or Command-Q | start repeated copies |
| Intel Mac | published build is arm64 only | build an appropriate source target if supported later | claim current binary compatibility |
| macOS too old | minimum is 14.0 | update macOS where supported | bypass the deployment target |
| Preference not saved | app or store could not write | inspect the diagnostic report and support locations | delete unrelated preferences |
| Site works, asset fails | release/CDN/network problem | open the release page and retry; report persistent failure | use an unverified mirror |

Report reproducible non-security bugs through the repository issue tracker.
Use the private route in `SECURITY.md` for vulnerabilities.
