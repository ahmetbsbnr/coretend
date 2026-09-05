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

import AppIntents
import Foundation
import SystemMetrics
import IntegrityCore
import Persistence

// MARK: - Localized metadata helper

extension LocalizedStringResource {
    /// Resolves against CoreTend's own `Localizable.strings` (EN + FR), so an
    /// intent's title/description/phrases localize from the same table as the
    /// rest of the app. (Whether the *Shortcuts app* surfaces the FR variant
    /// depends on the App Intents metadata bundle being present in the
    /// packaged `.app` — see `Documentation/MACOS_INTEGRATIONS.md`.)
    static func ct(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, table: "Localizable", bundle: .atURL(Bundle.module.bundleURL))
    }
}

/// Wraps an already-localized runtime string (from `CoreTendIntentText`) as
/// an `IntentDialog` without a second round of localization.
func ctDialog(_ localized: String) -> IntentDialog {
    IntentDialog(LocalizedStringResource(stringLiteral: localized))
}

// MARK: - Get free disk space

struct GetFreeDiskSpaceIntent: AppIntent {
    static let title: LocalizedStringResource = .ct("appintent.freespace.title")
    static let description = IntentDescription(.ct("appintent.freespace.description"))

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let snapshot = await MetricsCollector().snapshot()
        return .result(
            value: Int(snapshot.diskFreeBytes),
            dialog: ctDialog(CoreTendIntentText.freeSpace(
                freeBytes: snapshot.diskFreeBytes, totalBytes: snapshot.diskTotalBytes)))
    }
}

// MARK: - CoreTend summary

struct GetCoreTendSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = .ct("appintent.summary.title")
    static let description = IntentDescription(.ct("appintent.summary.description"))

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
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

struct GetStorageChangeIntent: AppIntent {
    static let title: LocalizedStringResource = .ct("appintent.change.title")
    static let description = IntentDescription(.ct("appintent.change.description"))

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let comparison = await TimelineService().overallSinceLastScan()
        let text = CoreTendIntentText.storageChange(
            deltaBytes: comparison?.totalDeltaBytes,
            topIncreaseBytes: comparison?.increases.first?.deltaBytes)
        return .result(value: text, dialog: ctDialog(text))
    }
}

// MARK: - Reclaimable developer storage

struct GetReclaimableDeveloperStorageIntent: AppIntent {
    static let title: LocalizedStringResource = .ct("appintent.devstorage.title")
    static let description = IntentDescription(.ct("appintent.devstorage.description"))

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
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

struct GetIntegritySummaryIntent: AppIntent {
    static let title: LocalizedStringResource = .ct("appintent.integrity.title")
    static let description = IntentDescription(.ct("appintent.integrity.description"))

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
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

struct InspectImageMetadataIntent: AppIntent {
    static let title: LocalizedStringResource = .ct("appintent.imagemeta.title")
    static let description = IntentDescription(.ct("appintent.imagemeta.description"))

    // macOS 14: `IntentFile` accepts any file; `perform()` verifies it is an
    // inspectable image and reports cleanly otherwise. The resolved URL is
    // used for this call only — never stored, never logged (same contract as
    // Privacy Lab; there is no `Store`/persistence call in this type).
    @Parameter(title: .ct("appintent.imagemeta.param"))
    var image: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
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

enum CoreTendModuleAppEnum: String, AppEnum {
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

    static let typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: .ct("appintent.module.type"))

    static let caseDisplayRepresentations: [CoreTendModuleAppEnum: DisplayRepresentation] = [
        .dashboard: .init(title: .ct("appintent.module.dashboard")),
        .storage: .init(title: .ct("appintent.module.storage")),
        .timeline: .init(title: .ct("appintent.module.timeline")),
        .recoveryPlan: .init(title: .ct("appintent.module.recovery_plan")),
        .developer: .init(title: .ct("appintent.module.developer")),
        .privacyLab: .init(title: .ct("appintent.module.privacy_lab")),
        .restoreCenter: .init(title: .ct("appintent.module.restore_center")),
        .apfs: .init(title: .ct("appintent.module.apfs")),
        .applications: .init(title: .ct("appintent.module.applications")),
        .settings: .init(title: .ct("appintent.module.settings")),
    ]
}

struct OpenCoreTendModuleIntent: AppIntent {
    static let title: LocalizedStringResource = .ct("appintent.open.title")
    static let description = IntentDescription(.ct("appintent.open.description"))
    static let openAppWhenRun = true

    @Parameter(title: .ct("appintent.open.param"))
    var module: CoreTendModuleAppEnum

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.route(to: .module(module.moduleID))
        return .result()
    }
}
