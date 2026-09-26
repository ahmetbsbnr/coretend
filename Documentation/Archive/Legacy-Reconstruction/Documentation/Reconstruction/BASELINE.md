# CoreTend repository baseline

Observed at (UTC): 2026-09-25 19:53:36 UTC. Measurement host: macOS 27.0 (26A428), arm64.

## Git snapshots

The source checkout (`app/`) is on `claude/keen-gates-6dtpoi`, tracking `origin/claude/keen-gates-6dtpoi`. The isolated execution worktree is on `reconstruction/baseline`. Both have full HEAD `23824216fdefce81802da76a34a92042215506e6` (short: `2382421`), committed 2026-09-25 with subject “Document the Instrument redesign”. Their remote names are `archive` and `origin`. Local branches are `claude/keen-gates-6dtpoi`, `develop/v2`, `feature/app-store-migration`, `main`, `maintenance/1.x`, and `reconstruction/baseline`.

At observation, neither checkout showed tracked modifications. The source checkout showed these untracked path names; their contents were not inspected:

```text
.claude-flow/harness-active-policy.json
.claude-flow/policy/state.json
.claude-flow/sessions/session-1788977278298.json
Documentation/Captures/duplicates-noresults-results-dark-compact.png
Documentation/Captures/duplicates-noresults-results-dark-standard.png
Documentation/Captures/duplicates-noresults-results-light-compact.png
Documentation/Captures/duplicates-noresults-results-light-standard.png
Documentation/Captures/smartCare-onboarding-dark-standard.png
Documentation/Captures/smartCare-onboarding-light-standard.png
Documentation/Captures/smartCare-settings-dark-standard.png
Documentation/Captures/smartCare-settings-light-standard.png
Documentation/Captures/spaceLens-tab2-noresults-results-dark-standard.png
Documentation/Captures/spaceLens-tab2-noresults-results-light-standard.png
Xcode/CoreTend.xcodeproj/project.pbxproj
Xcode/CoreTend.xcodeproj/project.xcworkspace/contents.xcworkspacedata
Xcode/CoreTend.xcodeproj/xcshareddata/xcschemes/CoreTend.xcscheme
Xcode/Staging/Resources/AppIcon.icns
Xcode/Staging/Resources/Assets.car
Xcode/Staging/Resources/Base.lproj/InfoPlist.strings
Xcode/Staging/Resources/LICENSE
Xcode/Staging/Resources/MenuBarTemplate.png
Xcode/Staging/Resources/MenuBarTemplate@2x.png
Xcode/Staging/Resources/NOTICE
Xcode/Staging/Resources/PrivacyInfo.xcprivacy
Xcode/Staging/Resources/THIRD_PARTY_NOTICES.md
Xcode/Staging/Resources/container-migration.plist
Xcode/Staging/Resources/fr.lproj/InfoPlist.strings
docs/superpowers/plans/2026-09-25-coretend-baseline-reconciliation.md
docs/superpowers/plans/2026-09-25-coretend-reconstruction-roadmap.md
docs/superpowers/specs/2026-09-25-coretend-reconstruction-design.md
graphify-out/.graphify_analysis.json
graphify-out/.graphify_labels.json
graphify-out/.graphify_labels.json.sig
graphify-out/2026-09-21/.graphify_analysis.json
graphify-out/2026-09-21/.graphify_labels.json
graphify-out/2026-09-21/GRAPH_REPORT.md
graphify-out/2026-09-21/graph.json
graphify-out/2026-09-21/manifest.json
graphify-out/GRAPH_REPORT.md
graphify-out/graph.html
graphify-out/graph.json
```

The isolated worktree showed these untracked path names:

```text
docs/superpowers/plans/2026-09-25-coretend-baseline-reconciliation.md
docs/superpowers/plans/2026-09-25-coretend-reconstruction-roadmap.md
docs/superpowers/specs/2026-09-25-coretend-reconstruction-design.md
```

## Package declaration

`Package.swift` declares Swift tools version 6.0 and macOS 14. Executable products/targets: `CoreTend`, `coretend-cli` (`CoreTendCLI`). Library products/targets: `ScanCore`, `SafetyCore`, `FileRules`, `DesignSystem`, `Persistence`, `SystemMetrics`, `AppDiscovery`, `IntegrityCore`. Additional regular target: `CoreTendApp`. Test targets: `DesignSystemTests`, `IntegrityCoreTests`, `AppDiscoveryTests`, `PersistenceTests`, `SystemMetricsTests`, `ScanCoreTests`, `SafetyCoreTests`, `FileRulesTests`, `CoreTendAppTests`, `CoreTendIntegrationTests`, `CoreTendUITests`, `CoreTendAccessibilityTests`, `CoreTendPerformanceTests`.

These are verified package declarations. Build and test outcomes were measured later in Task 2 below. This report describes this worktree only; branch names do not prove published content.

## Configured release record

`Configuration/published-release.json` records product `CoreTend`, version `1.0.2`, stable channel, tag `v1.0.2`, source commit `28f41a2ee80fa7bb624bf5b59e2cbdb84097ba6e`, publication timestamp `2026-09-22T05:32:34Z`, minimum macOS `14.0`, and architecture `arm64`. It names `CoreTend-1.0.2-arm64.dmg` and `CoreTend-1.0.2-arm64.zip` and contains hash, signing, and notarization fields. These are **CONFIGURED, UNVERIFIED** release claims. Public assets and checksums have not been independently checked.

## Evidence status

| Status | Current assessment | Basis or next evidence |
| --- | --- | --- |
| VERIFIED | Git snapshots for the source checkout and isolated worktree; package declarations | Read-only Git commands and direct reading of `Package.swift` at the observed commit. |
| RESOLVED IN P4 | `Documentation/LOCALIZATION.md` now reports 585/585 keys and documents the automated parser/parity gate in repository-doctor and CI | `Scripts/check-localization-parity.py`, four parser fixtures, CI workflow, and direct 585/585 gate run. Historical Task 2 finding retained for audit context. |
| HISTORICAL | The checked-in release JSON is a configured record of a purported prior release | Its identifiers are **CONFIGURED, UNVERIFIED** as public release facts. |
| UNKNOWN | Actual public version, assets, and checksums | Independently inspect the public release and compare downloaded artifact hashes in Task 5. |

## Task 2 — current automated gates (2026-09-25 UTC)

This is a measurement of `reconstruction/baseline` at Task 1 commit `632477a`. Controller retries used the same worktree. Results cover the local code and generated site only; no packaged application, UI runtime, public release artifact, or deployed site was tested. The `DEVELOPMENT.md` statement of 286 tests/57 suites, the 338-test floor in `Documentation/TESTING.md`, and older visual capture counts in `Documentation/VISUAL_QA.md` are **HISTORICAL—NOT RE-MEASURED** in this task.

| Gate and evidence class | Command and UTC time | Exit/status and observed result | Boundary / log |
| --- | --- | --- | --- |
| Release compilation; code | `bash Scripts/build.sh release`; controller retry 2026-09-25 20:41:18–20:41:19 UTC | Exit 0. Output: `Building for production... [Computing dependencies] Build complete! (0.49 s)`. The earlier sandboxed attempt exited 1 at 20:09:54 UTC before compilation because Swift could not write its module cache. | Controller retry in this worktree. Earlier attempt: `/private/tmp/coretend-baseline-build.log`. |
| Full Swift suite, first attempt; code/unit/integration | `HOME=/private/tmp/coretend-baseline-test-home bash Scripts/test.sh`; 20:17:19–20:17:21 UTC | Exit 1 before test discovery: `sandbox-exec: sandbox_apply: Operation not permitted` during manifest compilation. **BLOCKED by sandbox**, zero test count measured in this attempt. | Temporary `HOME` contained the script's preference-plist cleanup; no real user preferences were targeted. `/private/tmp/coretend-baseline-test.log`. |
| Full Swift suite, controller retry; code/unit/integration | `HOME=/private/tmp/coretend-baseline-test-home bash Scripts/test.sh`; 2026-09-25 20:41:28–20:41:47 UTC | Exit 0. Thirteen Swift Testing summaries: 386 tests passed across non-empty suites, plus one empty suite. The log excerpt contained no warning lines. | Controller retry, same worktree and isolated `HOME`; log: `/private/tmp/coretend-baseline-test-timestamped.log`. This proves local suite execution, not UI runtime or packaging. |
| Repository doctor; static repository checks | `Scripts/repository-doctor.sh`; 20:17:39–20:17:40 UTC | Exit 0; `repository-doctor: all checks passed.` Includes private-data, test-isolation, placeholder, feature-inventory, settings-matrix, retired-preview, local cask consistency, Markdown links, and tracked-ignore checks. It checked 212 internal links across 250 tracked Markdown files; 32 external links were untested. | Local tracked files only; `/private/tmp/coretend-baseline-doctor-final.log`. Cask comparison is against local release metadata, not downloaded artifact bytes. |
| Base/French localization key parity; static resource check | CI's `iconv -f UTF-16 -t UTF-8` → `sed` → `sort -u` → `diff -u` pipeline from `.github/workflows/ci.yml`; 20:24:54 UTC | Exit 0; Base: 569 keys, fr: 569 keys; no diff. | Key parity only, not translation quality or in-app rendering. Temporary key lists were removed. |
| Isolated public site build; generated site | `python3 Website/build.py --output /private/tmp/coretend-site-baseline-20260925`; 20:25:11–20:25:12 UTC | Exit 0; built the public site and printed two `public release gate: OK` lines for generated `latest.json` and `SHA256SUMS`. | Output was a new temporary directory, not tracked `Website/` assets. `/private/tmp/coretend-baseline-site-build.log`. This does not verify the published release. |
| Canonical website gate, sandbox attempt; generated site/browser | `bash Scripts/check-website.sh`; 20:25:19–20:25:20 UTC | Exit 1. Design-token export matched and first-paint/CSP check passed, then Node failed `listen EPERM: operation not permitted 127.0.0.1` before browser route checks. | The script builds to a temporary directory. `/private/tmp/coretend-baseline-website-final.log`. No deployed site was contacted. |
| Canonical website gate, controller retry; generated site/browser | `bash Scripts/check-website.sh`; 2026-09-25 20:41:58–20:41:59 UTC | Exit 1. Design-token export and first-paint/CSP checks passed. Browser checks stopped in `Scripts/site/site-fixture.mjs:222`: `Playwright is required. Run "npm install --no-save playwright".` The package was unavailable; no dependency install or network attempt was made. | Controller retry in this worktree. Site route/browser coverage remains **BLOCKED by missing local Playwright dependency**. |

The documented Debug build (`Scripts/build.sh`), local package/distribution commands, native visual capture (`zsh Scripts/capture-matrix.sh`), and default site visual capture (`node Scripts/visual/capture.mjs`) were **NOT RUN** in this gate measurement. The brief required the release build and full suite; package/runtime/capture commands are broader gates, and visual capture depends on an interactive display and reviewed reference assets. The documented `Scripts/dev.sh` command family was **NOT RUN** because that script is absent on this branch. `Documentation/LOCALIZATION.md` conflicts with `.github/workflows/ci.yml` on localization parity; the CI pipeline is present and its key comparison passed here, while the documentation statement needs reconciliation.

The localization command executed the CI pipeline with `base_keys=$(mktemp)` and `fr_keys=$(mktemp)`, applying `iconv -f UTF-16 -t UTF-8` to each resource, extracting keys with `sed -n 's/^"\([^"]*\)".*/\1/p'`, then `sort -u` and `diff -u "$base_keys" "$fr_keys"`; it removed both temporary files afterward.

## Task 3 — claim reconciliation at this checkout

This table reconciles repository claims against checked-in code/configuration and Task 2 measurements. It does not establish what GitHub currently serves; no remote release lookup was performed.

| Claim | Repository sources | Direct evidence in this checkout | Status | Owner / next action |
| --- | --- | --- | --- | --- |
| Current product/release version | `README.md`, `Documentation/PROJECT_STATE.md`, `Documentation/CURRENT_PROJECT_STATE.json`, `Configuration/published-release.json`, `Documentation/RELEASE_STATE.md` | README documents shipping 1.x plus a pre-alpha 2.0 line; Project State says published 1.0.0; legacy JSON says 0.9.1-rc.5; configured synchronized record says 1.0.2; Release State still calls 1.0.0 current. | CONTRADICTED | Maintainer: determine remote authority and reconcile stale state docs after remote evidence is available. |
| Public release URL, assets, checksums, signature, notarization | `Configuration/published-release.json`, `Documentation/RELEASE_STATE.md`, `Documentation/GOLD_MASTER_STATUS.md` | Local records contain incompatible versions and detailed historical evidence. Public bytes or release metadata were not independently inspected in this audit. | UNKNOWN | Maintainer: inspect public tag/assets and compare downloaded bytes, checksum, Minisign, signature and notarization evidence in Task 5. |
| Supported OS and architecture | `Package.swift`, `README.md`, configured release JSON | SwiftPM declares macOS 14.0+; README and configured release record say arm64. This verifies declared floor/intent, not compatibility across every supported OS. | VERIFIED (declaration only) | Engineering: keep compatibility matrix separate; record actual runtime matrix in later gate. |
| Product destinations and completeness | `README.md`, `Documentation/FEATURE_MATRIX.md`, `Documentation/FEATURE_INVENTORY.md`, `Sources/CoreTendApp/` | README, ModuleID, sidebar inventory and approved Programme 3 design now align on eleven destinations. Generated inventory contains feature rows with source references. | VERIFIED (navigation declarations); PARTIAL (runtime/visual acceptance and capability claims) | Engineering: native runtime, accessibility and visual acceptance remain unverified in this session. |
| File-operation safety and Trash behavior | README, cahier, `Sources/SafetyCore/`, `Documentation/SAFETY_MODEL.md`, localized strings | `SafetyCenter` revalidates then calls only `FileManager.trashItem`; failure leaves source intact. P1/P4 copy gates pass and label size as moved to Trash. | VERIFIED (source + fixture gates); PARTIAL (native UI runtime) | D-08 implemented; native Trash restoration and confirmation walkthrough remain unobserved. |
| Network, telemetry and accounts | README, `Documentation/CURRENT_PROJECT_STATE.json`, `Package.swift`, production source audit | One production `URLSession` call: explicit user-triggered update metadata GET. No `Process`, privileged helper, telemetry SDK, or account flow found. Test-only Swift Testing dependency remains. | PARTIAL | Independent network observation and audit remain absent; privacy docs describe the user-started request. |
| Runtime dependency count | README badges/body; `Package.swift` | Package manifest declares `swift-testing` for test targets; production target dependency graph does not reference that package. No independent bundle scan was performed here. | PARTIAL | Engineering: verify built app contents before repeating “zero runtime dependencies” as artifact fact. |
| Locale support and parity | `Package.swift`, README, `Documentation/FEATURE_MATRIX.md`, CI workflow, P5 gates | English/Base and French resources exist; current parity gate passes with 585 keys in each. This proves key parity only, not translation quality, page parity, or human wording review. | VERIFIED (key parity); PARTIAL (quality/coverage) | Human review of high-risk strings and visual page coverage remains. |
| Automated test count | `Scripts/test.sh`, P5 rerun | Task 2 historical run: 386 tests. P5 rerun on 2026-09-26: 443 tests across 12 runs, exit 0, excluding native UI XCTest target. Older docs also record 286, 338 and 342 tests at earlier commits. | VERIFIED (local run only); HISTORICAL (older totals) | Engineering: retain each total with its commit/date and suite scope; UI runtime remains unverified. |
| App Store availability | README and release docs | No App Store artifact, listing, or independent availability evidence examined; older docs describe feasibility as future work. | UNKNOWN | Maintainer: decide channel after separate feasibility and release-evidence review. |
| Website deployment state | README and `Website/`; P5 closeout | Local browser gate passes 32/32 with isolated routes/build; no deployed endpoint was checked. | UNKNOWN (deployment) | Maintainer: remote deployment remains outside this local reconstruction gate. |

## Task 5 — release evidence available locally

Project `AGENTS.md` restricts internet/page research to `mcp__web__web_search`; that tool is unavailable in this session. No `gh`, HTTP client, download, tag push, or release mutation was used. Local tag presence and tracked configuration do not prove remote publication.

| Evidence layer | Local observation | Status |
| --- | --- | --- |
| Configured record | `Configuration/published-release.json` specifies stable `v1.0.2`, commit `28f41a2…`, arm64/macOS 14+, signed/notarized flags and artifact hashes/sizes. | CONFIGURED; UNVERIFIED against public bytes |
| Local source tag | Annotated local tag `v1.0.2` resolves to commit `28f41a2ee80fa7bb624bf5b59e2cbdb84097ba6e`; commit exists in local object database. | VERIFIED local Git metadata only; remote presence UNKNOWN |
| Local release artifacts | No `Release/CoreTend-1.0.2-arm64.dmg`, ZIP, `dist/latest.json`, or `dist/SHA256SUMS` found in the isolated worktree. Tracked `Release/` content includes notes and `latest.template.json`, not the claimed binary artifacts. | ABSENT locally; not evidence of public absence |
| Downloaded/public bytes | No artifact downloaded and no public endpoint checked. | UNKNOWN |
| Hash verification | Configured SHA-256 values were not recomputed against artifact bytes. | UNKNOWN |
| Signature / notarization | `signed:true` and `notarized:true` are configuration fields. Historical release documents describe earlier verification for other versions. No 1.0.2 artifact or stapled ticket was locally inspected. | UNKNOWN for 1.0.2 |
| Publication channels | Repository configuration names GitHub release assets and README documents Homebrew/direct installation; no live release/cask endpoint was checked. No App Store listing inspected. | UNKNOWN as current public availability |
| Competing release records | `Documentation/PROJECT_STATE.md` says public 1.0.0; `Documentation/CURRENT_PROJECT_STATE.json` says 0.9.1-rc.5; `Documentation/RELEASE_STATE.md` says 1.0.0; synchronized config plus local tag say 1.0.2. | CONTRADICTED repository documentation; public authority unresolved |

This evidence is not sufficient to announce a current public version, asset integrity, signature, notarization, or channel status. The release source-of-truth decision remains open in `DECISIONS.md`.

## Task 7 — dossier validation

After adding the cahier, matrix, decision register and index links, `Scripts/repository-doctor.sh` exited 0. It checked 220 internal links across 255 tracked Markdown files (0 broken); 32 external links were not tested. Private-data, placeholder, generated feature inventory, settings matrix, retired-preview, cask-vs-local-release-metadata, and tracked-ignore checks all passed. Cask comparison remains local metadata evidence, not independent remote artifact verification. `REQUIREMENTS_TRACEABILITY.md` contains exactly 32 unique IDs (18 FR, 14 NFR); `DECISIONS.md` contains D-01 through D-09. These checks validate repository consistency, not runtime behavior or public release state.


## 2026-09-26 integration addendum

The public release remains **unknown / unverified from this checkout**. The
tracked `Configuration/published-release.json` is local generated data without
a verification attestation; its version and signing facts are not independent
proof. The site now fails closed for that state and links to GitHub Releases.
No live release refresh, download, or publication was performed.


## Programme 5 — hardening evidence addendum (2026-09-26)

Host measured: arm64, macOS 27.0, Swift 6.4. Repository doctor, privacy/data
scans, test isolation, copy/localization, uninstall fixtures and static release
gates passed. Swift test execution did not start: package/UI test target failed
with `_TestingInternals`; retry without that target hit runner `sandbox_apply:
Operation not permitted`. `Package.swift` was restored byte-for-byte. No
performance measurements or other-OS/hardware evidence were obtained; D-06
remains open. Public release remains UNKNOWN. See
[Programme 5 evidence](../HARDENING_PROGRAMME5.md).
