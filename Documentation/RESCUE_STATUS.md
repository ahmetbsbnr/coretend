# CoreTend Rescue Status

Date: 2026-07-31
Branch: `rescue/coretend-final-product`
Active repo path: `/Users/ahmetbasbunar/Developer/Website/products/coretend/app`
HEAD before rescue edits: `38b8ddac091f0965bde1ce380d984b59619da6a8`
Latest committed rescue subsystem: `6f80ef1b265f9c1c1e20df88504d311f22eea3e9` (`6f80ef1`)
Latest packaging diagnosis commit: `5509efdb9981c6d68a8a3f38511e9cdf3b0b7961` (`5509efd`)

## Git Validation

- Index write test passed: `.codex-git-index-test` was created, staged, verified in the index, unstaged, removed, and `git status --short` returned to the exact initial state.
- Reference write test passed: temporary branch `codex-git-ref-test` was created from HEAD, verified, deleted without checkout, and the active branch remained `rescue/coretend-final-product`.
- Git is functional in this session.
- Branch `rescue/coretend-final-product` was pushed to GitHub at `6f80ef1b265f9c1c1e20df88504d311f22eea3e9`.
- Branch `rescue/coretend-final-product` was pushed to GitHub at `5509efdb9981c6d68a8a3f38511e9cdf3b0b7961`.

## Local Backup

Current worktree diff was exported before additional fixes:

- Path: `/Users/ahmetbasbunar/Developer/Website/_backups/codex-rescue-20260731-214557/rescue-worktree-20260731-214557.diff`
- SHA-256: `902b8006d263e3355aabcb652499e003361bacf922c1fa802d642359a0d2574f`
- HEAD: `38b8ddac091f0965bde1ce380d984b59619da6a8`

Earlier verified backup directory:
`/Users/ahmetbasbunar/Developer/Website/_backups/20260731T174147Z-coretend-rescue`

## Pause / Resume Subsystem

Commit: `6f80ef1b265f9c1c1e20df88504d311f22eea3e9`

Diagnosis:

- The old exit-137 class was consistent with blocking pause waits under Swift Concurrency pressure.
- A polling `Task.sleep` pause avoided OS-thread blocking but left stress coverage fragile and made release behavior indirect.
- The repaired controller stores suspended continuations and resumes them explicitly, so paused waits do not occupy cooperative-executor threads.

Implemented:

- `ScanPauseController` actor with pause/resume state and waiter release on resume/cancellation.
- `ScanEngine.run(rules:pauseController:)` plumbs pause control into the filesystem walk.
- EN/FR localization keys exist for Pause, Resume, Cancel, and VoiceOver hints.
- Keyboard shortcuts: `p` pauses, `r` resumes, Escape cancels.
- Reduce Motion remains respected by existing animated views; the pause controls do not add motion.

Controls currently integrated:

- Smart Care: Pause / Resume / Cancel while scanning.
- Cleanup: Pause / Resume / Cancel while scanning.
- My Clutter, Large & Old analysis: Pause / Resume / Cancel while scanning.

Controls not yet integrated:

- Space Lens scan.
- Duplicates scan.
- Similar Images scan.
- Privacy Cleaner browser detection/cleanup.
- Cloud Cleanup provider analysis.
- Applications scan/uninstall workflows.
- Integrity scanners.

Known limits:

- Pause checks occur between enumerated filesystem entries, not during a single blocking filesystem call.
- Pause currently affects `ScanEngine`-based walks only; engines with separate implementation paths still need equivalent cancellation/pause semantics.
- UI coverage exists through CI visual regression, but no dedicated XCUIAutomation suite has been added yet.

Verification completed for `6f80ef1`:

- `swift test --disable-sandbox --scratch-path /tmp/coretend-swiftpm-scratch --filter ScanPauseControllerTests` passed.
- `swift build --disable-sandbox --scratch-path /tmp/coretend-swiftpm-scratch -c debug` passed.
- `swift build --disable-sandbox --scratch-path /tmp/coretend-swiftpm-scratch-release -c release` passed.
- EN/FR localization key check with `iconv -f UTF-16 -t UTF-8 ... | rg 'common\.(pause|resume|cancel)|pause_hint|resume_hint'` passed.
- GitHub Actions CI run `30659795847` passed: distribution-check and build-and-test were green, including tests, release build, launch robustness, 72 visual captures across FR/EN and viewports, and localization key parity.

## Public Launch Reproduction

Production route checked:
`https://coretend.ahmetbsbnr.com/download`

Observed redirect chain:
`/download` -> `https://github.com/ahmetbsbnr/coretend/releases/download/v0.9.1-rc.3/CoreTend-0.9.1-rc.3-arm64-unsigned.dmg` -> GitHub release-asset CDN.

Expected DMG SHA-256:
`2960293a278f81be602aebb84ad6582d41f118635bbbca4517853bb68831ee71`

Reproduction workspace:
`/private/tmp/coretend-public-dmg-repro-20260731T225553`

Verified:

- Production HTTP route returns the expected public DMG asset.
- Owner unsandboxed Terminal reproduction on 2026-07-31 downloaded the production route successfully.
- DMG SHA-256 matched expected: `2960293a278f81be602aebb84ad6582d41f118635bbbca4517853bb68831ee71`.
- `hdiutil verify`: checksum valid.
- Unsandboxed `hdiutil attach -readonly CoreTend-public.dmg` succeeded and mounted `/Volumes/CoreTend 0.9.1-rc.3`.
- Mounted DMG contents: `.DS_Store`, `.VolumeIcon.icns`, `.background.tiff`, `Applications -> /Applications`, `CoreTend.app`.
- CLI download carries no quarantine by default; browser-equivalent quarantine was applied manually for diagnosis:
  `0081;6a6cfe1e;Safari;https://coretend.ahmetbsbnr.com/download`.
- `hdiutil attach`: failed locally with `Périphérique non configuré`; verbose log says `Cannot start hdiejectd because app is sandboxed`, so this session cannot mount DMGs and cannot complete Finder copy/open from the mounted volume.
- ZIP SHA-256: `28114f0a352abe340bb83cd61c84dedcb3cb0b8e031a12ae7a1a4e306e4db173`
- Bundle ID: `com.ahmetbsbnr.coretend`
- Published app version fields: `CFBundleShortVersionString=0.9.1-rc.3`, `CFBundleVersion=0.9.1-rc.3`
- Minimum macOS: `14.0`
- Architecture: `arm64`
- Dependencies from `otool -L`: system frameworks and `/usr/lib/swift` only; no obvious missing bundled dylib.
- Resources present: app icon, menu-bar templates, license/notice files, SwiftPM resource bundle, Base and FR localizations.
- Signature: ad hoc, no TeamIdentifier; `codesign --verify --deep --strict` passes for the extracted ZIP app.
- Owner unsandboxed reproduction confirms `codesign --verify --deep --strict --verbose=4` passes for the app copied out of the mounted DMG.
- Owner unsandboxed reproduction confirms `spctl --assess --type execute --verbose=4` rejects the app.
- Owner unsandboxed `open -n -W` produced the macOS Gatekeeper malware-warning dialog in French and returned `open exit=0` because the dialog was handled, not because the app launched.
- Exact user-visible alert from the screenshot: `Élément « CoreTend » non ouvert. Apple n’a pas pu confirmer que « CoreTend » ne contenait pas de logiciel malveillant susceptible d’endommager votre Mac ou de porter atteinte à votre vie privée.` Buttons shown: `Placer dans la corbeille`, `Terminé`.
- No CoreTend crash reports were listed by the unsandboxed `DiagnosticReports/*CoreTend*` check.
- Gatekeeper assessment via `spctl` fails in this sandbox with `internal error in Code Signing subsystem`, so the real Gatekeeper verdict must be collected outside the sandbox.
- `open -n -W` fails with `kLSNoExecutableErr` even for the current locally built app, so this LaunchServices path is also sandbox-tainted.
- Direct executable launch in the sandbox returned `137` with quarantine and `134` after quarantine removal; no usable Console/crash report access is available because `/usr/bin/log show` is sandbox-blocked.

Apple documentation check:

- `CFBundleShortVersionString` must be three period-separated integers and can only contain digits and periods.
- `CFBundleVersion` can contain one to three period-separated integers and can only contain digits and periods.
- Therefore the public v0.9.1-rc.3 app contains invalid Apple bundle-version metadata. This is a real packaging defect, independent from the expected unsigned/not-notarized Gatekeeper block.

Mitigation implemented in source, not published:

- `Resources/Info.plist` now uses Apple-compatible bundle fields: `CFBundleShortVersionString=0.9.1`, `CFBundleVersion=913`.
- Product/update UI now reads `CoreTendMarketingVersion=0.9.1-rc.3`, preserving the public semantic prerelease label without putting it in Apple bundle-version keys.
- Version gates now verify the custom marketing version against `Configuration/PublicIdentity.example.json` and validate Apple's numeric bundle-version grammar.
- `Scripts/package-local.sh` can now place the assembled app bundle outside `build/` with `CORETEND_APP_BUNDLE_PATH`, so sandboxed verification can package to `/tmp` without touching an existing local app bundle.
- Verification for the source mitigation: `Scripts/check-version-consistency.sh`, `Scripts/test-release-sync.sh`, `swift test --disable-sandbox --scratch-path /tmp/coretend-swiftpm-scratch-version --filter infoPlistDeclaresIconAndVersion`, `swift build --disable-sandbox --scratch-path /tmp/coretend-swiftpm-scratch-version -c release`, and `/tmp` package/signature inspection all passed.
- GitHub Actions CI run `30662454150` passed on `5509efdb9981c6d68a8a3f38511e9cdf3b0b7961`: distribution-check and build-and-test were green, including package ZIP/DMG, distribution tests, launch robustness, and 72 visual regression captures.

Current conclusion:

- Normal Gatekeeper launch is expected to be blocked because the app is ad-hoc signed and not notarized.
- A separate real packaging defect exists: both Apple bundle-version fields in the public v0.9.1-rc.3 artifact contain `-rc.3`, which violates Apple's documented format.
- The unsandboxed owner run proved the DMG itself downloads, verifies, mounts, and contains the expected drag-install layout; `spctl` rejection is expected for unsigned/unnotarized distribution.
- The reproduced user-facing failure is the normal macOS Gatekeeper block for an app whose developer cannot be verified. There is no evidence of a CoreTend app crash in this reproduction.
- This sandbox cannot independently run the Finder/Console portion, because `spctl`, `open`, and unified logs are sandbox-tainted here.
- Do not replace the public download until a rebuilt artifact with valid Apple bundle metadata has been validated through the same quarantined path.

## Remaining Rescue Work

P0:

- Reproduce and explain the public DMG launch failure from the real website/download path.
- Distinguish Gatekeeper block, crash, packaging fault, macOS/hardware incompatibility, and combinations.
- Do not replace the public download until the failure is explained.

Xcode integration:

- Add minimal robust Xcode integration while keeping SwiftPM the source of truth.
- Provide schemes/test plans for CoreTend, unit/integration/UI/accessibility/performance/release workflows.
- Keep isolated test environments and do not duplicate sources or change bundle ID.

Product/application:

- Perform a real screen-by-screen audit.
- Consolidate target architecture around Dashboard, Storage, Space Lens, Duplicates, Applications, Integrity, Activity, Settings.
- Finish or remove incomplete visible modules.
- Complete visual redesign beyond token replacement.
- Generate fresh Retina captures with fake data and no personal paths.

Testing/accessibility/performance:

- Add real XCUIAutomation coverage for first launch, onboarding, FR/EN, navigation, scan, pause/resume, cancel, modules, errors, light/dark, close/relaunch.
- Run keyboard-only, VoiceOver, Increase Contrast, Reduce Transparency, Reduce Motion, large text.
- Run Instruments: Time Profiler, Allocations, Leaks, File Activity, Energy, SwiftUI when available.

Site/portfolio/release:

- Rebuild CoreTend site to the requested quality bar with honest installation state.
- Verify Talkink license before any reuse and do not copy brand/text/assets/claims.
- Update portfolio after the real product state and captures are complete.
- Finalize README, changelog, licenses/notices, updater, release draft, internal DMG/ZIP/SHA-256/Minisign/SBOM/attestation/feed.

Developer ID:

- Check for Developer ID Application identity before final release packaging.
- Do not regenerate CSR or touch the private key.
- If absent, finish all non-signing work and leave signing/notarization blocked.
