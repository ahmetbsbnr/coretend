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
user reviews/toggles → explicit confirmation → SafetyCenter.approve each → execute
(re-validate, move to Trash)
→ result screen.

Additional shipped modules: Persistence (SQLite actor), SystemMetrics,
AppDiscovery, IntegrityCore, duplicate/image-similarity engines, diagnostics and
menu-bar status. There is no privileged helper or third-party malware engine.
