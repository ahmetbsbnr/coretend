# CoreTend Xcode Integration

SwiftPM (`Package.swift`) is the single source of truth for every domain
module, service, and test. `swift build` / `Scripts/build.sh` /
`Scripts/test.sh` never need Xcode.

Two distinct Xcode-facing surfaces exist and must not be confused:

| Surface | Path | Purpose | Tracked? |
|---|---|---|---|
| **Package schemes** | `.swiftpm/xcode/xcshareddata/xcschemes/` | Open `Package.swift` in Xcode for local dev — schemes/test plans only | yes |
| **Shipping host project** | `CoreTend.xcodeproj` (generated from `project.yml`) | Build the distributable `.app`: nested WidgetKit extension, App Intents metadata bundle, entitlements | yes (generated artifact + drift check) |

## Shipping host project — `CoreTend.xcodeproj`

Apple bundle structures that SwiftPM cannot express — an embedded
`.appex`, `Contents/Resources/Metadata.appintents`, per-target
entitlements, a Developer-ID-compatible signing config — require a real
Xcode project. `CoreTend.xcodeproj` provides exactly that thin container
and nothing else.

- **Generated, not hand-edited.** `project.yml` is the source;
  `xcodegen generate` produces `CoreTend.xcodeproj`.
  `Scripts/repository-doctor.sh` regenerates it and fails on any drift, the
  same tracked-generated-artifact pattern used for `settings-matrix.json`
  → `SETTINGS_MATRIX.md`. Install with `brew install xcodegen`.
- **One product, no fork.** The `application` target `CoreTend` compiles
  `Sources/CoreTend/` (the existing `main.swift` entry point →
  `CoreTendApp.main()`) and links the repo package's `CoreTendApp`
  product. There is no second `@main`, no copied source.
- **Targets:**
  - `CoreTend` — `application`, bundle id `com.ahmetbsbnr.coretend`,
    deployment target macOS 14.0, hardened runtime on, embeds both
    extensions below.
  - `CoreTendWidget` — `app-extension`
    (`com.apple.widgetkit-extension`), bundle id
    `com.ahmetbsbnr.coretend.widget`, links **only** the `WidgetShared`
    package product (no scan/cleanup/restore module is reachable).
  - `CoreTendFinder` — `app-extension` (`com.apple.FinderSync`), bundle id
    `com.ahmetbsbnr.coretend.finder`, links **only** the `FinderShared`
    package product. Read-only: forwards the Finder selection to the host
    as a `coretend://` URL and does nothing else. App-sandbox-only
    entitlements, no App Group.
- **Shared scheme:** `CoreTend-App` (`xcshareddata/xcschemes/`), tracked so
  CI can build it. User schemes, `xcuserdata`, `*.xcuserstate`,
  `DerivedData`, and workspace check files are git-ignored.
- No absolute `/Users/...` path appears in any committed Xcode file
  (`repository-doctor.sh` greps for it).

### Building it

```sh
Scripts/build-xcode.sh
```

Non-interactive, CI-safe. Runs `xcodegen generate`, then `xcodebuild
-project CoreTend.xcodeproj -scheme CoreTend-App -configuration Release`
into a temp derived-data dir with `CODE_SIGNING_ALLOWED=NO` (an ordinary
build needs no Developer ID), then verifies the built bundle
structurally: **both** extensions embedded at
`Contents/PlugIns/CoreTendWidget.appex` (`com.apple.widgetkit-extension`)
and `Contents/PlugIns/CoreTendFinder.appex` (`com.apple.FinderSync`) with
the right bundle ids and FR localizations,
`Contents/Resources/Metadata.appintents/extract.actionsdata` present with
≥ 7 App Intents and ≥ 6 App Shortcuts, both extension `CFBundleExecutable` declarations, exact sandbox-only entitlements
from an ad-hoc-signed copy of the compiled Finder bundle, the host `Info.plist` registering
the `coretend://` URL scheme, and no absolute developer path in the generated project/schemes or host plist. The
verified `.app` is copied to `build/CoreTend.app` for the signing lane.

### Signing / release

`Scripts/sign-and-notarize.sh` consumes `build/CoreTend.app` from
`build-xcode.sh` (not `package-local.sh`, which is a fast extension-less
SwiftPM build) and signs **each extension bundle first** (Finder, then
widget), then the host last — see
`Documentation/SIGNING_NOTARIZATION.md`.

## Package schemes — `.swiftpm/xcode`

Unchanged. These only define useful schemes/test plans for opening
`Package.swift` in Xcode during local development.

- `CoreTend`: Debug app build, launch, profile, and the primary isolated
  test plan.
- `CoreTendTests`: deterministic unit and integration tests.
- `CoreTendUITests`: UI contract source retained for a future native
  Xcode UI-test target. SwiftPM emits this as a unit-test bundle, so
  `XCUIApplication` is unsupported and these tests skip with that explicit
  reason.
- `CoreTendAccessibility`: accessibility contract tests and manual
  Accessibility Inspector runs.
- `CoreTendPerformance`: deterministic performance smoke tests.
- `CoreTendRelease`: Release launch/profile/analyze path.

### Isolation

Every package test plan sets `CORETEND_TEST_MODE=1` and
`CORETEND_TEST_STORE_DIR=/tmp/coretend-xcode-*/store`.
`Persistence.TestStoreOverride` only accepts an override when both
variables are present and the path is under a temporary root — these
schemes must not read or migrate the user's real CoreTend data.
