<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Finder Extension recovery and validation

## Recovered state

Repository: `products/coretend/app`; branch `feat/finder-extension`.
Starting HEAD: `71d1c06fe927ab62823e625f9c61e2f120c9cadb`.
Previous shipping commits already present: `fddf0de` (Xcode/Widget implementation)
and `71d1c06` (shipping documentation). No Finder commit existed at takeover.
Finder target, shared module, handoff/router/views, localization, tests and shipping
scripts were staged. Finder documentation was unstaged. The old handoff's claim of
commits and a clean tree contradicted Git; its test claims were not accepted as
current evidence. Initial targeted Finder/router run passed 38 tests.

Existing partial work was retained and completed. Fixes: actual-account home
registration; bounded live item classification; no empty/multiple/unsupported menu;
explicit containing-host URL target; strict payload grammar; image-kind validation;
selected-symlink rejection; consumption-time validation; shared one-shot consumer;
replacement and closed-window lifecycle; localized errors; off-main Integrity;
Finder scans without persistent path history; both extension executable plist keys;
compiled Finder entitlement probe and stronger dependency/package checks.

Local agent setup/backups remain on disk, excluded locally through `.git/info/exclude`.
They were not deleted or mixed into product commits. No partial product work was
thrown away; superseded inaccurate scaffolding comments/docs were corrected.

## Validation

Validated implementation commit: `4cb9a0df4d5d3258874f197566098b1c3545ce43`. Later changes are documentation only.

| Gate | Actual result |
|---|---|
| `Scripts/build.sh` | PASS, Debug SwiftPM build, 0 compiler warnings |
| `Scripts/test.sh` | PASS, **727 passed, 0 failing** (46 above 681 checkpoint) |
| `Scripts/repository-doctor.sh` | PASS, all checks, localization and Xcode drift included |
| `Scripts/build-xcode.sh` | PASS, Release universal build; both extensions embedded |

Finder compiled-copy entitlements were read back and exactly matched sandbox-only.
Both built extension plists declare the correct executable. Widget identifiers and
FR resources remain present; App Intents metadata contains **7 intents / 6 shortcuts**.
No absolute developer path appears in the generated project/schemes or host plist.

Diagnostics: no Swift compiler warning in final app builds. Test compilation emits
existing `swift-testing` package deprecation warnings for Test/Suite macros under
the installed Swift 6 toolchain. These are compiler diagnostics, not sandbox noise.
Xcode's metadata processor skips extraction for Finder because Finder intentionally
has no AppIntents dependency; host metadata passes. `codesign` emits a deprecation
notice for its existing `--entitlements :-` display syntax. No compiler errors.

Authorization receipt: the user explicitly authorized local implementation,
synthetic tests, builds, documentation, and coherent local commits on the recovered
feature branch. No push, merge, release, Developer ID signing, or notarization ran.
No capability expansion or privileged action was required.
Targeted new host integration: 8 passed, synthetic files only.
Build logs are local `/tmp/coretend-final-{build,tests,xcode,doctor}.log`.

## Architecture and limitations

See `MACOS_INTEGRATIONS.md` §6 for exact payload, validation, route consumption,
registration, entitlement, privacy, and signing boundaries.

The extension contains no destructive engine or call; host scan initiation does
not approve cleanup, Trash, restore, or Recovery Plan. The extension performs only
single-item attributes and handoff. Filesystem permissions remain enforced by macOS;
metadata-denied items yield no menu. Read-only inspection is not an atomic filesystem
snapshot; inspectors handle disappearance/unreadability, and files may change while
read. No destructive operation follows a Finder route.

The deliverable is a local unsigned build. An isolated copy of the compiled Finder
bundle is ad-hoc signed to inspect exact sandbox-only entitlements; this is not
Developer ID signing, notarization, or Finder runtime verification.

## HUMAN VERIFICATION REQUIRED

- Finder extension visible and enableable in System Settings.
- Real Finder right-click menu, all three actions, empty/unsupported/multi selection.
- Cold launch and warm foreground/background/menu-bar-only/closed-window delivery.
- Desktop, Documents, Downloads, and external-volume coverage/permissions.
- EN/FR Finder labels, keyboard and VoiceOver on menu and Settings.
- Developer ID signed/notarized artifact with Widget and Finder extensions.
- Second Mac and another supported macOS version.

Launch Items Manager remains analysis only; see `LAUNCH_ITEMS_MANAGER_READINESS.md`.

### Local evidence hashes (SHA-256)

- `build` log: `5bec281b92d22f549d229d6d3befad17e88bbd98bb22e43d2189e98ff0387594`
- `tests` log: `434ec05675d5f8b2a0a33eb817fa9e2b3463c2a63884cc51554b5e28f7ff91bb`
- `xcode` log: `3ab207300fb512618a29f95d41ef778a62186a90128449ec62f1126412635581`
- Unsigned `CoreTendFinder` executable: `d5fa59ebd22f4b2aa95dd1d201ed3cbca77146f789c9e635b102a5de63d76acb`
- Unsigned `CoreTendWidget` executable: `71140635fe56bc2264ce2fa922ffde248fa6867bff7e8970e618d5b6883aeb41`
