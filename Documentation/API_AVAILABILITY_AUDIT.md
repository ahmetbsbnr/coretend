# API Availability Audit

Deployment target: macOS 14.0 (`Package.swift`: `.macOS(.v14)`).

## Method

No `@available` annotations exist anywhere in `Sources/` (`grep -rn
"@available" Sources` → 0 matches), meaning nothing in the codebase
currently claims to need less than the full deployment target and
nothing is gated for a higher one. So the audit is: does every
non-trivial API actually used exist at macOS 14.0? Checked by grepping
every `import` and every framework-level symbol name that could plausibly
be macOS-15-or-later, and cross-checking each hit against its known
introduction version.

No Xcode/multiple macOS SDKs are available in this environment (see
`Documentation/COMPATIBILITY.md`), so this is a documentation-and-grep
audit, not a compiled-against-the-14.0-SDK verification. That limitation
is explicit, not hidden.

## Imports used (`Sources/`)

```
AppKit, CoreGraphics, CoreServices, CryptoKit, Darwin, Foundation,
ImageIO, QuickLook, QuickLookThumbnailing, QuickLookUI, SQLite3, SwiftUI,
UniformTypeIdentifiers, UserNotifications, Vision
```

All of these frameworks predate macOS 14; none is new-in-14-or-later as a
whole. No `TipKit`, `SwiftData`, `WidgetKit`, or other post-14 framework
is imported.

## Notable SwiftUI/Observation symbols checked individually

| Symbol | Introduced | Used here | Status at target (14.0) |
|---|---|---|---|
| `@Observable` macro (Observation framework) | macOS 14.0 | 16 files (e.g. `Sources/MacCareApp/MacCareApp.swift:41`, `SettingsView.swift:8`, `SmartCareView.swift:11`) | OK — exactly at floor, no headroom |
| `MenuBarExtra` | macOS 13.0 | `Sources/MacCareApp/MacCareApp.swift:27` | OK |
| `NavigationSplitView` | macOS 13.0 | `Sources/MacCareApp/MacCareApp.swift:241` | OK |

No hits for `@Bindable`, `@Entry`, `ContentUnavailableView`,
`symbolEffect`, `ImageRenderer`, `scrollTargetBehavior`,
`contentMargins`, `.inspector(`, `glassEffect`, `MeshGradient`, or other
macOS-15/26-era SwiftUI API — these were grepped for and found absent.

## Result

Everything found in a static scan is at or below the macOS 14.0 floor.
`@Observable` is the tightest constraint in the codebase — it is the
reason the floor cannot be lowered below macOS 14 without a rewrite, and
also the newest API actually in use, so it's the first thing to
re-check if the deployment target ever changes. No `@available` guard or
fallback was needed because nothing above the target was found.

This audit does not substitute for compiling against the macOS 14.0 SDK
or running on a macOS 14 machine, neither of which is available here —
see the honest gap noted in `Documentation/COMPATIBILITY.md`.

## Re-verification (Step 10, functional-completion phase)

Grep re-run at HEAD on this branch confirmed the table above unchanged:
still 0 `@available` in `Sources/`, `@Observable` now in 18 files (was
16), no new post-14 API. `MenuBarExtra` (`MacCareApp.swift:27`),
`NavigationSplitView` (`:241`), `VNGenerateImageFeaturePrintRequest` /
`VNImageRequestHandler` (`SimilarImagesEngine.swift:70-71`, feature-print
= macOS 10.15), `QLThumbnailGenerator` (`SimilarImagesView.swift:76`,
macOS 10.15), `FSEventStream` (`ProtectionWatcher.swift:221`),
ubiquitous-item resource keys, `SQLite3`, and the
`x-apple.systempreferences:` deep-links all sit at or below the macOS 14
floor. No `ServiceManagement`/`SMAppService` in the tree. Result stands:
no guard or fallback needed.

To close the "static-only" gap without a second Mac, a
`.github/workflows/compat-matrix.yml` builds+tests on macos-14 and
macos-15 GitHub-hosted runners. It is **IMPLEMENTED_UNVERIFIED** — never
pushed or run in this environment.
