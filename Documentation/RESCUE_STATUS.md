# CoreTend Rescue Status

Date: 2026-07-31
Branch: `rescue/coretend-final-product`
Active repo path: `/Users/ahmetbasbunar/Developer/Website/products/coretend/app`
HEAD before rescue edits: `38b8ddac091f0965bde1ce380d984b59619da6a8`

## Git Validation

- Index write test passed: `.codex-git-index-test` was created, staged, verified in the index, unstaged, removed, and `git status --short` returned to the exact initial state.
- Reference write test passed: temporary branch `codex-git-ref-test` was created from HEAD, verified, deleted without checkout, and the active branch remained `rescue/coretend-final-product`.
- Git is functional in this session.

## Local Backup

Current worktree diff was exported before additional fixes:

- Path: `/Users/ahmetbasbunar/Developer/Website/_backups/codex-rescue-20260731-214557/rescue-worktree-20260731-214557.diff`
- SHA-256: `902b8006d263e3355aabcb652499e003361bacf922c1fa802d642359a0d2574f`
- HEAD: `38b8ddac091f0965bde1ce380d984b59619da6a8`

Earlier verified backup directory:
`/Users/ahmetbasbunar/Developer/Website/_backups/20260731T174147Z-coretend-rescue`

## Public Launch Reproduction

Public download URL identified from `Website/vercel.json`:
`https://github.com/ahmetbsbnr/coretend/releases/download/v0.9.1-rc.3/CoreTend-0.9.1-rc.3-arm64-unsigned.dmg`

Previous reproduction state remains factual:

- DMG SHA-256: `2960293a278f81be602aebb84ad6582d41f118635bbbca4517853bb68831ee71`
- `hdiutil verify`: checksum valid.
- `hdiutil attach`: failed with `Périphérique non configuré`; local DMGs failed the same way, so this session cannot prove the normal DMG mount path.
- ZIP SHA-256: `28114f0a352abe340bb83cd61c84dedcb3cb0b8e031a12ae7a1a4e306e4db173`
- Bundle ID: `com.ahmetbsbnr.coretend`
- Version: `0.9.1-rc.3`
- Minimum macOS: `14.0`
- Architecture: `arm64`
- Signature: ad hoc, no TeamIdentifier.
- `spctl --assess --type execute`: `internal error in Code Signing subsystem`.
- `open -n -W CoreTend.app`: failed with `kLSNoExecutableErr`.
- Direct executable launch in this headless session returned exit `134` without a CoreTend crash report.

Conclusion: the public artifact is not Developer ID signed and not notarized; Gatekeeper normal-launch acceptance is not valid. DMG mounting still needs validation in a normal GUI environment.

## Pause / Resume Fix

Diagnosis:

- The old exit-137 class was consistent with blocking pause waits under Swift Concurrency pressure.
- A polling `Task.sleep` pause avoided OS-thread blocking but still left stress coverage fragile and made cancellation/release behavior indirect.
- The repaired controller stores suspended continuations and resumes them explicitly, so paused scans do not occupy cooperative-executor threads.

Implemented:

- `ScanPauseController` actor with pause/resume state and waiter release on resume/cancellation.
- `ScanEngine.run(rules:pauseController:)` plumbs pause control into the filesystem walk.
- Smart Care, Cleanup, and My Clutter expose Pause / Resume / Cancel controls in the running state.
- EN/FR localization keys exist for Pause, Resume, Cancel, and VoiceOver hints.
- Keyboard shortcuts: `p` pauses, `r` resumes, Escape cancels.
- Reduce Motion remains respected by existing animated views; the pause controls do not add motion.

## Verification

Passed:

- `swift test --disable-sandbox --scratch-path /tmp/coretend-swiftpm-scratch --filter ScanPauseControllerTests`
- `swift build --disable-sandbox --scratch-path /tmp/coretend-swiftpm-scratch -c debug`
- `swift build --disable-sandbox --scratch-path /tmp/coretend-swiftpm-scratch-release -c release`
- EN/FR localization key check with `iconv -f UTF-16 -t UTF-8 ... | rg 'common\.(pause|resume|cancel)|pause_hint|resume_hint'`

Partial / blocked:

- Full test suite was started after targeted deterministic tests passed, but was stopped after no further output for roughly 90 seconds; no failure was reported before interruption.
- Xcode MCP build remains unavailable because no scheme is selected in Xcode.
- CI status requires pushing and observing GitHub Actions.
- Signing and notarization require a valid Developer ID identity; none was available in the prior identity check.
