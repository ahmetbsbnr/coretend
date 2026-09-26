public enum Capability: String, CaseIterable, Sendable {
    case shellLaunch = "shell.launch"
    case shellNav = "shell.nav"
    case shellMenubar = "shell.menubar"
    case shellOnboarding = "shell.onboarding"
    case shellDiagnostics = "shell.diagnostics"
    case uiCommandPalette = "ui.commandpalette"
    case safetyPathValidator = "safety.pathvalidator"
    case safetyExecutionGate = "safety.executiongate"
    case safetyExecute = "safety.execute"
    case safetyAuditLog = "safety.auditlog"
    case spacelensDelete = "spacelens.delete"
    case scanEngine = "scan.engine"
    case scanDuplicates = "scan.duplicates"
    case scanSimilarImages = "scan.similarimages"
    case scanSpaceLens = "scan.spacelens"
    case clutterLargeOld = "clutter.largeold"
    case clutterDuplicates = "clutter.duplicates"
    case clutterSimilarImages = "clutter.similarimages"
    case spacelensView = "spacelens.view"
    case cloudDetect = "cloud.detect"
    case cleanupUserCaches = "cleanup.usercaches"
    case cleanupUserLogs = "cleanup.userlogs"
    case cleanupCrashReports = "cleanup.crashreports"
    case cleanupXcodeDerivedData = "cleanup.xcodederiveddata"
    case cleanupIncompleteDownloads = "cleanup.incompletedownloads"
    case cleanupXcodeDeviceSupport = "cleanup.xcodedevicesupport"
    case cleanupIOSBackups = "cleanup.iosbackups"
    case integrityProvenance = "integrity.provenance"
    case integrityCodeSign = "integrity.codesign"
    case integrityLoginItems = "integrity.loginitems"
    case performanceMetrics = "perf.metrics"
    case appsDiscovery = "apps.discovery"
    case appsLeftovers = "apps.leftovers"
    case appsUpdates = "apps.updates"
    case activityLog = "activity.log"
    case activityGrouping = "activity.grouping"
    case activityJSONExport = "activity.jsonexport"
    case settingsMenubar = "settings.menubar"
    case settingsAppSignature = "settings.appsignature"
    case settingsFullDiskAccess = "settings.fulldiskaccess"
    case settingsExclusions = "settings.exclusions"
    case settingsClearActivity = "settings.clearactivity"
    case settingsExportDiagnostic = "settings.exportdiagnostic"
    case l10nLanguagePicker = "l10n.languagepicker"
    case migrationLegacyData = "migration.legacydata"
    case migrationLaunchWiring = "migration.launchwiring"
    case settingsMigrationNotice = "settings.migrationnotice"
    case uninstallLegacyData = "uninstall.legacydata"
    case testingStoreIsolation = "testing.storeisolation"
    case quickLookExtended = "quicklook.extended"
    case favoriteRecentModule = "favrec.module"
}

public struct ProductManifest: Sendable {
    public let name: String
    public let destinations: [String]
    public let capabilityIDs: [String]

    public init(name: String = "CoreTend") {
        self.name = name
        self.destinations = ["Overview", "Record", "Cleanup", "Explore", "Duplicates", "Applications", "Integrity", "Performance"]
        self.capabilityIDs = Capability.allCases.map(\.rawValue).sorted()
    }
}

public enum ProductMeasurement<Value: Sendable>: Sendable {
    case known(Value)
    case unknown(reason: String)
}

extension ProductMeasurement: Equatable where Value: Equatable {}
