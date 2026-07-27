# ARCHITECTURE

SwiftPM package, one executable + library modules:

- **SafetyCore** (no deps): PathValidator (Sendable struct), SafetyCenter (actor),
  ApprovedFileOperation, RiskLevel, SafetyError (typed throws).
- **ScanCore** (dep: SafetyCore): ScanRule (declarative), ScanConfiguration,
  ScanEngine → `AsyncStream<ScanEvent>`; sync directory walk in detached utility task;
  cancellation via stream termination.
- **FileRules** (deps: ScanCore, SafetyCore): built-in rules + matching deletion allowlists.
  Rules and allowlists are tested to stay in sync.
- **DesignSystem** (no deps): MCTheme tokens, MCCard, formatting helpers.
- **CoreTendApp** (executable): SwiftUI App, NavigationSplitView shell, per-module views,
  @Observable view models on MainActor. Heavy work stays off MainActor via engines.

Flow (Cleanup): ScanEngine stream → view model accumulates findings (capped) →
user reviews/toggles → SafetyCenter.approve each → execute (re-validate, trash/dry-run)
→ result screen.

Planned modules: Persistence (SQLite actor), SystemMetrics, AppDiscovery,
DuplicateEngine, ImageSimilarity, MalwareEngine, Diagnostics, menu bar agent,
privileged helper (XPC, typed methods only).
