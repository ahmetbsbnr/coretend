# CoreTend Agent Handoff

## Exact recovered and validated checkpoint

- Branch: `feat/finder-extension`.
- Starting HEAD: `71d1c06fe927ab62823e625f9c61e2f120c9cadb`.
- Validated implementation HEAD: `4cb9a0df4d5d3258874f197566098b1c3545ce43`.
- This handoff is delivered by the following documentation-only commit; use
  `git log -2 --oneline` for its final hash. No runtime source changes follow
  the implementation commit above.
- At documentation preparation: implementation committed; documentation changes
  unstaged, then staged/committed as one handoff receipt. Final intended state:
  clean working tree. No push, merge, main modification, or history rewrite.
- Prior shipping commits: `fddf0de`, `71d1c06`. No Finder commit existed at takeover.
  All staged Finder scaffolding and unstaged docs were preserved and finished.
- Unrelated local agent setup/backups remain intact, locally excluded through
  `.git/info/exclude`; they are not product changes.

## Completed — Finder Extension FAIT (local engineering gates)

Real embedded `CoreTendFinder.appex`, `com.apple.FinderSync`, bundle id
`com.ahmetbsbnr.coretend.finder`; FinderShared-only package dependency;
entitlements exactly App Sandbox. Widget remains embedded. Both executable
plist declarations fixed. XcodeGen remains authoritative for project generation.

Single existing folder/image/app selection offers corresponding read-only action.
Empty/multiple/unsupported/missing/symlink selection offers none. Menu uses bounded
single-item attributes; no contents, recursion, hashing, metadata decoding,
SQLite, network, or destructive engine in the extension.

Handoff: one `coretend://finder/<action>?path=<encoded-absolute-path>` URL via
NSWorkspace explicitly targeting the containing host. Host uses existing AppRouter,
strict syntax parsing, live validation at receipt and consumption, replacement of
stale payloads, shared consume-once gate, and receiver close/reopen lifecycle.
Invalid selections show EN/FR guidance. No persisted URL payload.

Host integrations remain existing Space Lens (Finder scan skips path history),
Privacy Lab/ImageMetadataInspector (in-memory), and Integrity/CodeSignInspector
(off-main). No automatic cleanup, Trash, Restore, or Recovery Plan.
Registration uses actual account home via getpwuid, /Applications, /Volumes.
Settings explains enablement/read-only semantics without fabricated status.

## Exact validation

- `Scripts/build.sh`: PASS; no compiler warnings.
- `Scripts/test.sh`: **727 passed, 0 failing**.
- `Scripts/repository-doctor.sh`: PASS including localization/project drift.
- `Scripts/build-xcode.sh`: **BUILD SUCCEEDED**, both embedded extensions,
  correct identifiers/executables, FR resources, **7 intents / 6 shortcuts**.
- Compiled Finder copy ad-hoc signed and exact sandbox-only entitlements verified.
- Test compilation has existing swift-testing Test/Suite deprecation diagnostics.
  Finder-only metadata extraction skip and codesign display-syntax deprecation
  are tooling notices. No app compiler errors or warnings.
- No Developer ID signed/notarized artifact produced.

Full recovery, architecture, artifact/log hashes, and human checklist:
`FINDER_EXTENSION_VALIDATION.md`, `MACOS_INTEGRATIONS.md` §6.

## Remaining concrete work / next action

No implementation gate remains. **HUMAN VERIFICATION REQUIRED**: System Settings
visibility/enablement; real Finder menus and all actions; cold/warm/background/
menu-bar-only/closed-window delivery; Desktop/Documents/Downloads/external volume;
EN/FR; VoiceOver/keyboard; signed/notarized build with both extensions; second Mac
and supported macOS. Do not claim these were tested.

Next action: enable the local extension in System Settings and perform that manual
matrix. A separately authorized release run may follow; do not push/merge/publish
implicitly. Launch Items Manager is analysis only, recorded in
`LAUNCH_ITEMS_MANAGER_READINESS.md`; do not implement it without a new assignment.
