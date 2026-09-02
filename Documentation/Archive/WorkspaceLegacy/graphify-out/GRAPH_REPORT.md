# Graph Report - .  (2026-07-31)

## Corpus Check
- Corpus is ~41,058 words - fits in a single context window. You may not need a graph.

## Summary
- 1128 nodes · 2174 edges · 58 communities (56 shown, 2 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 77 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]

## God Nodes (most connected - your core abstractions)
1. `L()` - 32 edges
2. `Store` - 24 edges
3. `AppDiscovery` - 20 edges
4. `OnboardingView` - 20 edges
5. `CleanupViewModel` - 18 edges
6. `ModuleID` - 18 edges
7. `OnboardingViewModel` - 18 edges
8. `String` - 17 edges
9. `SmartCareViewModel` - 17 edges
10. `PathValidator` - 17 edges

## Surprising Connections (you probably didn't know these)
- `Store` --implements--> `SafetyAuditSink`  [EXTRACTED]
  Sources/CoreTendApp/AppEnvironment.swift → Sources/SafetyCore/SafetyCore.swift
- `Store` --references--> `Database`  [EXTRACTED]
  Sources/CoreTendApp/AppEnvironment.swift → Sources/Persistence/Store.swift

## Import Cycles
- None detected.

## Communities (58 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.10
Nodes (26): AppDiscovery, AssociatedItem, HomebrewCaskIndex, InstalledApp, Kind, applicationSupport, caches, containers (+18 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (38): App, Commands, CommandPaletteView, CoreTendApp, CoreTendHelpCommands, Entry, action, module (+30 more)

### Community 2 - "Community 2"
Cohesion: 0.09
Nodes (33): Comparable, ApprovedFileOperation, ExecutionResult, Kind, moveToTrash, PathValidator, RiskLevel, high (+25 more)

### Community 3 - "Community 3"
Cohesion: 0.07
Nodes (32): AsyncThumbnail, ImageMember, Phase, empty, idle, results, scanning, SimilarImagesView (+24 more)

### Community 4 - "Community 4"
Cohesion: 0.09
Nodes (29): AppUpdateSource, AppUpdatesView, AppUpdatesViewModel, Phase, empty, loading, ready, UpdateInfo (+21 more)

### Community 5 - "Community 5"
Cohesion: 0.08
Nodes (26): Calendar, ActivityDateRange, all, last30, last7, ActivityDayGroup, ActivityGrouping, ActivityImpactSummary (+18 more)

### Community 6 - "Community 6"
Cohesion: 0.09
Nodes (24): CareModule, ModuleState, done, pending, scanning, unavailable, Phase, executing (+16 more)

### Community 7 - "Community 7"
Cohesion: 0.16
Nodes (22): RiskLevel, ScanConfiguration, ScanEngine, ScanEvent, cancelled, error, finding, finished (+14 more)

### Community 8 - "Community 8"
Cohesion: 0.12
Nodes (19): Phase, idle, ready, scanning, SpaceLensView, SpaceLensViewModel, SpaceNodeCategory, archive (+11 more)

### Community 9 - "Community 9"
Cohesion: 0.10
Nodes (21): Binding, CleanupView, CleanupViewModel, Phase, done, failed, idle, review (+13 more)

### Community 10 - "Community 10"
Cohesion: 0.13
Nodes (19): CloudCleanupView, CloudCleanupViewModel, Entry, Phase, detecting, noProviders, ready, results (+11 more)

### Community 11 - "Community 11"
Cohesion: 0.09
Nodes (22): DuplicatesView, DuplicatesViewModel, DupMember, Phase, empty, executing, finished, idle (+14 more)

### Community 12 - "Community 12"
Cohesion: 0.14
Nodes (19): CodeSignInfo, CodeSignInspector, CodeSignTier, adHocOrUnsigned, appleSigned, teamSigned, DownloadProvenance, LoginItem (+11 more)

### Community 13 - "Community 13"
Cohesion: 0.17
Nodes (11): ClutterExclusions, ClutterExclusionsController, ClutterSearch, ClutterVolumeGrouping, SystemVolumeResolver, VolumeInfo, VolumeResolving, Hashable (+3 more)

### Community 14 - "Community 14"
Cohesion: 0.17
Nodes (18): MCEmptyState, MCErrorState, MCMetricCard, MCModuleIdentity, MCSectionHeader, MCStatus, active, attention (+10 more)

### Community 15 - "Community 15"
Cohesion: 0.14
Nodes (18): DuplicateEngine, DuplicateEvent, cancelled, finished, group, progress, DuplicateGroup, AsyncStream (+10 more)

### Community 16 - "Community 16"
Cohesion: 0.15
Nodes (16): AnimatablePair, CoreBloomMark, MCArc, MCBloomGeometry, OrbitalProgressView, Track, Path, Shape (+8 more)

### Community 17 - "Community 17"
Cohesion: 0.19
Nodes (15): MCFragmentView, Phase, executing, rest, review, scanning, success, CGFloat (+7 more)

### Community 18 - "Community 18"
Cohesion: 0.19
Nodes (8): OnboardingView, MCStatus, Bool, Color, String, Void, SystemCheck, View

### Community 19 - "Community 19"
Cohesion: 0.20
Nodes (14): MCMeshView, Style, alert, incomplete, ready, scanning, Bool, CGPoint (+6 more)

### Community 20 - "Community 20"
Cohesion: 0.11
Nodes (17): LargeOldFilesView, MyClutterView, MyClutterViewModel, Phase, empty, idle, results, scanning (+9 more)

### Community 21 - "Community 21"
Cohesion: 0.15
Nodes (17): Inputs, Item, SecurityConfig, SecurityProfile, cautious, custom, recommended, Status (+9 more)

### Community 22 - "Community 22"
Cohesion: 0.16
Nodes (5): OnboardingViewModel, PermissionProbe, SecurityProfile, UNAuthorizationStatus, URL

### Community 23 - "Community 23"
Cohesion: 0.18
Nodes (12): Error, OpaquePointer, Database, DatabaseError, migrationFailed, openFailed, prepareFailed, stepFailed (+4 more)

### Community 24 - "Community 24"
Cohesion: 0.13
Nodes (13): LaunchAgentInfo, LaunchAgentInspector, PerformanceView, PerformanceViewModel, Bool, Color, Double, Int64 (+5 more)

### Community 25 - "Community 25"
Cohesion: 0.15
Nodes (10): MCSettingsView, MigrationNoticeRow, PermissionFormatting, SettingsViewModel, Bool, Color, LegacyDataMigration, String (+2 more)

### Community 26 - "Community 26"
Cohesion: 0.18
Nodes (13): ActivityRecord, Kind, cleanup, error, restore, scan, SafetyLogRecord, SafetyAuditEvent (+5 more)

### Community 27 - "Community 27"
Cohesion: 0.17
Nodes (14): Rejection, markerAbsent, markerNotExactlyOne, pathAbsent, pathEmpty, pathIsHomeOrAbove, pathNotAbsolute, pathNotUnderTemporaryRoot (+6 more)

### Community 28 - "Community 28"
Cohesion: 0.24
Nodes (13): async, ReleaseInfo, SemanticVersion, UpdateChannel, prerelease, stable, UpdateChecker, Bool (+5 more)

### Community 29 - "Community 29"
Cohesion: 0.14
Nodes (12): BrowserProfile, Phase, empty, finished, results, scanning, PrivacyCleanerView, PrivacyCleanerViewModel (+4 more)

### Community 30 - "Community 30"
Cohesion: 0.17
Nodes (9): AppGroup, AppGroupingLogic, ApplicationsViewModel, Key, AssociatedItem, HomebrewCaskIndex, InstalledApp, Set (+1 more)

### Community 31 - "Community 31"
Cohesion: 0.21
Nodes (4): Database, URL, Store, String

### Community 32 - "Community 32"
Cohesion: 0.22
Nodes (8): LegacyDataMigration, LegacyPreferenceSource, SystemPreferenceSource, Any, FileManager, String, URL, UserDefaults

### Community 33 - "Community 33"
Cohesion: 0.13
Nodes (13): LeftoversView, LeftoversViewModel, Phase, empty, finished, idle, results, scanning (+5 more)

### Community 34 - "Community 34"
Cohesion: 0.17
Nodes (8): L(), CVarArg, mcFormatBytes(), Int, Task, URL, Int64, String

### Community 35 - "Community 35"
Cohesion: 0.28
Nodes (7): Date, Double, Int64, String, MetricsCollector, MetricsSnapshot, UInt64

### Community 36 - "Community 36"
Cohesion: 0.16
Nodes (12): Phase, empty, failed, loaded, loading, SafetyLogRow, SafetyLogView, SafetyLogViewModel (+4 more)

### Community 37 - "Community 37"
Cohesion: 0.24
Nodes (11): BrowserCatalog, BrowserProfile, Definition, Layout, chromium, firefox, safari, FileManager (+3 more)

### Community 38 - "Community 38"
Cohesion: 0.18
Nodes (10): Phase, checking, idle, result, UpdatesView, UpdatesViewModel, Bool, String (+2 more)

### Community 39 - "Community 39"
Cohesion: 0.16
Nodes (12): MCHeroCoreView, MCHeroState, error, idle, review, running, scanning, success (+4 more)

### Community 40 - "Community 40"
Cohesion: 0.24
Nodes (11): Codable, Equatable, Failure, Report, Status, completed, completedWithErrors, completedWithSkips (+3 more)

### Community 41 - "Community 41"
Cohesion: 0.26
Nodes (7): CodeSignTier, DiagnosticReport, DiagnosticReportView, Inputs, Bool, Int, String

### Community 42 - "Community 42"
Cohesion: 0.17
Nodes (11): ApplicationsView, AppUpdateSource, appStore, homebrew, none, sparkle, InstalledAppsView, Phase (+3 more)

### Community 43 - "Community 43"
Cohesion: 0.20
Nodes (8): IntegrityView, IntegrityViewModel, ProtectionView, DownloadProvenance, LoginItem, CodeSignInfo, String, URL

### Community 44 - "Community 44"
Cohesion: 0.20
Nodes (10): CaseIterable, AppGrouping, lastUsed, none, publisher, size, updateState, SortOption (+2 more)

### Community 45 - "Community 45"
Cohesion: 0.24
Nodes (5): AppEnvironment, ActivityRecord, Bool, LegacyDataMigration, String

### Community 46 - "Community 46"
Cohesion: 0.31
Nodes (6): Bundle, AppLanguage, en, fr, system, LocalizationManager

### Community 47 - "Community 47"
Cohesion: 0.25
Nodes (6): CloudFile, Bool, Set, URLResourceKey, URLResourceValues, URLUbiquitousItemDownloadingStatus

### Community 48 - "Community 48"
Cohesion: 0.33
Nodes (6): ClutterExclusionsController, ExcludeButton, ExclusionsMenu, MCSearchField, String, URL

### Community 49 - "Community 49"
Cohesion: 0.29
Nodes (6): LaunchLocation, applications, diskImage, downloads, other, temporary

### Community 50 - "Community 50"
Cohesion: 0.33
Nodes (5): Canonical, MCColor, Color, Double, String

### Community 51 - "Community 51"
Cohesion: 0.33
Nodes (6): UpdateCheckError, badResponse, cancelled, malformedManifest, notConfigured, offline

### Community 52 - "Community 52"
Cohesion: 0.47
Nodes (4): MCOverlapStack, Item, ItemContent, Bool

### Community 53 - "Community 53"
Cohesion: 0.40
Nodes (3): UserCleanupRules, ScanRule, URL

### Community 55 - "Community 55"
Cohesion: 0.50
Nodes (4): UpdateStatus, failed, updateAvailable, upToDate

### Community 57 - "Community 57"
Cohesion: 0.50
Nodes (3): MCFont, MCIconSize, CGFloat

## Knowledge Gaps
- **359 isolated node(s):** `appStore`, `sparkle`, `homebrewCask`, `manual`, `unknown` (+354 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `L()` connect `Community 34` to `Community 1`, `Community 36`, `Community 5`, `Community 6`, `Community 38`, `Community 8`, `Community 9`, `Community 10`, `Community 11`, `Community 43`, `Community 46`, `Community 18`, `Community 22`, `Community 25`, `Community 30`, `Community 31`?**
  _High betweenness centrality (0.105) - this node is a cross-community bridge._
- **Why does `DatabaseError` connect `Community 23` to `Community 21`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Why does `MCFragmentView` connect `Community 17` to `Community 9`, `Community 18`?**
  _High betweenness centrality (0.054) - this node is a cross-community bridge._
- **What connects `appStore`, `sparkle`, `homebrewCask` to the rest of the system?**
  _359 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.10195035460992907 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.06262626262626263 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.09292929292929293 - nodes in this community are weakly interconnected._