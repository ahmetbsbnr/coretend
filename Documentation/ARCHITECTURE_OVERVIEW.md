# Architecture Overview

See [Documentation/ARCHITECTURE.md](ARCHITECTURE.md) for the module graph
and dependency list. This doc walks one flow end to end so a new
contributor can see how the pieces actually connect.

## Module graph (dependency direction)

```
SafetyCore  (no deps)
   ^  ^
   |  |
ScanCore   FileRules ---> (also depends on ScanCore)
   ^
   |
CoreTendApp (executable) ---> also depends on: DesignSystem, Persistence,
                              SystemMetrics, AppDiscovery, IntegrityCore
```

`SafetyCore` sits at the bottom deliberately — nothing above it can bypass
path validation, because everything above it depends on it, never the
other way around.

## Walkthrough: a Cleanup scan-to-delete run

1. **CoreTendApp/CleanupView.swift** builds a `ScanConfiguration` from
   `FileRules`' built-in rules and the user's saved
   [exclusions](../Documentation/EXCLUSIONS.md) (loaded from `Persistence.Store`).
2. **ScanCore.ScanEngine** walks the filesystem in a detached task, emits
   `ScanEvent`s over an `AsyncStream` — see [SCANCORE.md](SCANCORE.md).
3. The view model accumulates `ScanFinding`s as they stream in (capped for
   on-screen rendering only, not for totals — see `CHANGELOG.md`).
4. User reviews/selects findings in the UI. Nothing has been validated for
   deletion yet — findings are just evidence.
5. “Move to Trash” opens an explicit confirmation. After confirmation, each
   selected finding goes through **SafetyCore.SafetyCenter**, which re-validates the path
   (protected roots, symlink escape, allowlist) immediately before acting
   — see [SAFETYCORE.md](SAFETYCORE.md) — and produces an
   `ApprovedFileOperation`, the only type the actual trash-move call
   accepts.
6. The result (files actually moved and bytes reclaimed) is recorded via
   **Persistence.Store.recordActivity** — see [PERSISTENCE.md](PERSISTENCE.md).
7. UI shows the done screen; user can restore from Trash — see
   [RESTORE.md](RESTORE.md).

## Where Protection differs

Integrity (`ProtectionView.swift` + `IntegrityCore`) is read-only. It reports
macOS download provenance, code-signature tiers and launch items from local
metadata; it does not claim malware detection and ships no third-party scanner.
Privacy Cleaner uses the normal reviewed, confirmed SafetyCore Trash path.

## UI layer conventions

SwiftUI `NavigationSplitView` shell, `@Observable` view models on
`MainActor`, heavy work always pushed off `MainActor` via the engines
above. Every module's view follows the same phase-state pattern: idle /
scanning / review / executing / done / failed — see
[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).
