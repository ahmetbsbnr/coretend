// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

//
// App Intents are READ-ONLY integrations. Every `perform()` here calls an
// existing CoreTend domain service and returns a value — none of them can
// clean, delete, empty the Trash, restore, or disable a launch item, because
// none of them import or reference `FileRules` / `SafetyCore.SafetyCenter` /
// `RecoveryPlanService` / `RestoreService`. `CoreTendIntentsSafetyTests`
// enforces that at the source level.
//
// LOCALIZATION NOTE: the Apple App Intents metadata extractor (which the
// Xcode shipping build runs to make Shortcuts discovery work) requires every
// `title` / `description` / phrase to be a plain string literal resolved
// against the *main* bundle — it rejects a custom-bundle `LocalizedString
// Resource`. So the Shortcuts-app-facing METADATA below is English literals.
// Everything the user actually reads back — dialogs and result strings — is
// built by `CoreTendIntentText` via `L()` and is fully EN + FR. See
// `Documentation/MACOS_INTEGRATIONS.md` → "App Intents localization".
//

import AppIntents
import Foundation
import SystemMetrics
import IntegrityCore
import Persistence

/// Wraps an already-localized runtime string (from `CoreTendIntentText`) as
/// an `IntentDialog` without a second round of localization.
func ctDialog(_ localized: String) -> IntentDialog {
    IntentDialog(LocalizedStringResource(stringLiteral: localized))
}

// MARK: - Get free disk space

public struct GetFreeDiskSpaceIntent: AppIntent {
    public init() {}
    public static let title: LocalizedStringResource = "Get Free Disk Space"
    public static let description = IntentDescription(
        "Returns the free and total space on this Mac's startup disk.")

    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let snapshot = await MetricsCollector().snapshot()
        return .result(
            value: Int(snapshot.diskFreeBytes),
            dialog: ctDialog(CoreTendIntentText.freeSpace(
                freeBytes: snapshot.diskFreeBytes, totalBytes: snapshot.diskTotalBytes)))
    }
}

// MARK: - CoreTend summary

public struct GetCoreTendSummaryIntent: AppIntent {
    public init() {}
    public static let title: LocalizedStringResource = "Get CoreTend Summary"
    public static let description = IntentDescription(
        "A short read-only summary: free space, change since the last scan, and when CoreTend last scanned.")

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = await MetricsCollector().snapshot()
        let comparison = await TimelineService().overallSinceLastScan()
        let lastScan = (try? await AppEnvironment.shared.store?.activity(limit: 1, kind: .scan))?.first
        let text = CoreTendIntentText.summary(
            freeBytes: snapshot.diskFreeBytes,
            deltaBytes: comparison?.totalDeltaBytes,
            lastScan: lastScan?.date)
        return .result(value: text, dialog: ctDialog(text))
    }
}

// MARK: - What changed since last comparable scan

public struct GetStorageChangeIntent: AppIntent {
    public init() {}
    public static let title: LocalizedStringResource = "Get Storage Change"
    public static let description = IntentDescription(
        "Compares the most recent scan with the previous comparable one and reports the difference.")

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let comparison = await TimelineService().overallSinceLastScan()
        let text = CoreTendIntentText.storageChange(
            deltaBytes: comparison?.totalDeltaBytes,
            topIncreaseBytes: comparison?.increases.first?.deltaBytes)
        return .result(value: text, dialog: ctDialog(text))
    }
}

// MARK: - Reclaimable developer storage

public struct GetReclaimableDeveloperStorageIntent: AppIntent {
    public init() {}
    public static let title: LocalizedStringResource = "Get Reclaimable Developer Storage"
    public static let description = IntentDescription(
        "Runs a read-only Developer Center scan and returns how much developer-cache space could be reclaimed.")

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let locations = ApplicationInventoryLocations.resolve(environment: ProcessInfo.processInfo.environment)
        let excluded = (try? await AppEnvironment.shared.store?.exclusions()) ?? []
        let snapshot = await DeveloperCenterService.scan(
            home: locations.home, applicationRoots: locations.applicationRoots, excludedPaths: excluded)
        let bytes = snapshot?.potentiallyRecoverableBytes ?? 0
        return .result(
            value: Int(bytes),
            dialog: ctDialog(CoreTendIntentText.developerStorage(reclaimableBytes: bytes)))
    }
}

// MARK: - Integrity summary

public struct GetIntegritySummaryIntent: AppIntent {
    public init() {}
    public static let title: LocalizedStringResource = "Get Integrity Summary"
    public static let description = IntentDescription(
        "A read-only summary of downloads with provenance, quarantined downloads, and login items.")

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let provenance = ProvenanceScanner.scan(folder: downloads)
        let text = CoreTendIntentText.integrity(
            provenanceCount: provenance.count,
            quarantinedCount: provenance.filter(\.isQuarantined).count,
            loginItemCount: LoginItemScanner.scan().count,
            ownTierRawValue: CodeSignInspector.inspect(at: Bundle.main.bundleURL).tier.rawValue)
        return .result(value: text, dialog: ctDialog(text))
    }
}

// MARK: - Inspect image metadata

public struct InspectImageMetadataIntent: AppIntent {
    public init() {}
    public static let title: LocalizedStringResource = "Inspect Image Metadata"
    public static let description = IntentDescription(
        "Inspects the metadata embedded in an image, locally. The image is not modified and its path is not stored.")

    // macOS 14: `IntentFile` accepts any file; `perform()` verifies it is an
    // inspectable image and reports cleanly otherwise. The resolved URL is
    // used for this call only — never stored, never logged (same contract as
    // Privacy Lab; there is no `Store`/persistence call in this type).
    @Parameter(title: "Image")
    public var image: IntentFile

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let url = image.fileURL else {
            let text = L("appintent.imagemeta.unavailable")
            return .result(value: text, dialog: ctDialog(text))
        }
        let inspection = await Task.detached(priority: .userInitiated) {
            ImageMetadataInspector.inspect(fileURL: url)
        }.value
        let present = inspection.findings
            .filter { if case .present = $0.field.presence { return true } else { return false } }
            .map { PrivacyLabCatalog.title(for: $0.category) }
        let text = CoreTendIntentText.imageMetadata(status: inspection.status, presentCategories: present)
        return .result(value: text, dialog: ctDialog(text))
    }
}

// MARK: - Open a CoreTend module

public enum CoreTendModuleAppEnum: String, AppEnum {
    case dashboard, storage, timeline, recoveryPlan, developer, privacyLab, restoreCenter, apfs, applications, settings

    var moduleID: ModuleID {
        switch self {
        case .dashboard: return .smartCare
        case .storage: return .cleanup
        case .timeline: return .timeline
        case .recoveryPlan: return .recoveryPlan
        case .developer: return .developer
        case .privacyLab: return .privacyLab
        case .restoreCenter: return .restoreCenter
        case .apfs: return .apfs
        case .applications: return .applications
        case .settings: return .settings
        }
    }

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "CoreTend Screen"

    public static let caseDisplayRepresentations: [CoreTendModuleAppEnum: DisplayRepresentation] = [
        .dashboard: "Dashboard",
        .storage: "Storage",
        .timeline: "Storage Timeline",
        .recoveryPlan: "Recovery Plan",
        .developer: "Developer Center",
        .privacyLab: "Privacy Lab",
        .restoreCenter: "Restore Center",
        .apfs: "APFS",
        .applications: "Applications",
        .settings: "Settings",
    ]
}

public struct OpenCoreTendModuleIntent: AppIntent {
    public init() {}
    public static let title: LocalizedStringResource = "Open CoreTend Screen"
    public static let description = IntentDescription("Opens CoreTend to a specific screen.")
    public static let openAppWhenRun = true

    @Parameter(title: "Screen")
    public var module: CoreTendModuleAppEnum

    @MainActor
    public func perform() async throws -> some IntentResult {
        AppRouter.shared.route(to: .module(module.moduleID))
        return .result()
    }
}
