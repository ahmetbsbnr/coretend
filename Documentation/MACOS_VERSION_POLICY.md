# macOS Version Policy

Floor: macOS 14.0 (Sonoma), set by `Package.swift`'s `.macOS(.v14)`.

Why 14.0 and not lower: the app's per-screen view models use the
`@Observable` macro (Swift's Observation framework), which requires
macOS 14.0. This is the single binding constraint — see
`API_AVAILABILITY_AUDIT.md`. Every other API in use is available on
macOS 13 or earlier, so 14.0 is not padding, it's the actual floor.

Why not raise it further: nothing in the codebase currently requires
macOS 15+ (audited, see `API_AVAILABILITY_AUDIT.md`), so raising the
floor would only exclude users for no functional gain.

Changing this floor later: lowering it below 14.0 would require removing
or reimplementing every `@Observable` use (16 files as of this audit).
Raising it is free until a macOS-15-or-later API is actually adopted —
re-run the grep audit in `API_AVAILABILITY_AUDIT.md` when that happens.
