import AppIntents
import AppShell
import Foundation
import ScanCore

// Shortcuts and Siri. Every action here reads; none moves a file. Clearing space stays a
// review in the app (SafetyCore), so the only action that touches the Mac opens CoreTend.

/// The four spaces and History, for « Open CoreTend ».
enum CoreTendSpace: String, AppEnum {
    case home, space, clean, apps, record

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Space"
    static let caseDisplayRepresentations: [CoreTendSpace: DisplayRepresentation] = [
        .home: "Home", .space: "Space", .clean: "Clean", .apps: "Apps", .record: "History",
    ]
}

struct OpenCoreTendIntent: AppIntent {
    static let title: LocalizedStringResource = "Open CoreTend"
    static let description = IntentDescription("Opens CoreTend on the space you choose.")
    static let openAppWhenRun = true

    @Parameter(title: "Space", default: .home)
    var space: CoreTendSpace

    @MainActor
    func perform() async throws -> some IntentResult {
        // Saved first, so a CoreTend that is not running yet opens there too.
        CoreTendPreferences().saveLastDestination(space.rawValue)
        NotificationCenter.default.post(name: .coreTendOpenDestination, object: space.rawValue)
        return .result()
    }
}

struct FreeSpaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Free Space"
    static let description = IntentDescription("Says how much space is free on the Mac's disk. Reads only.")

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let home = HomeFolder.url
        let values = try home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        let free = values.volumeAvailableCapacityForImportantUsage ?? 0
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let french = IntentText.french
        let sentence = french
            ? "\(IntentText.bytes(free)) libres sur \(IntentText.bytes(total))."
            : "\(IntentText.bytes(free)) free of \(IntentText.bytes(total))."
        return .result(value: Int(free), dialog: IntentDialog(stringLiteral: sentence))
    }
}

struct ReclaimableSpaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Space to Clear"
    static let description = IntentDescription("Reads every cleanup rule and says how much CoreTend could move to the Trash. Moves nothing.")

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let report = try await CleanupSurvey(home: HomeFolder.url).run()
        let sentence = IntentText.french
            ? "CoreTend peut mettre \(IntentText.bytes(report.bytes)) à la Corbeille. Ouvrez Nettoyer pour revoir la liste."
            : "CoreTend can move \(IntentText.bytes(report.bytes)) to the Trash. Open Clean to review the list."
        return .result(value: Int(report.bytes), dialog: IntentDialog(stringLiteral: sentence))
    }
}

struct CoreTendShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: FreeSpaceIntent(), phrases: ["How much space is free with \(.applicationName)"],
                    shortTitle: "Free Space", systemImageName: "internaldrive")
        AppShortcut(intent: ReclaimableSpaceIntent(), phrases: ["What can \(.applicationName) clear"],
                    shortTitle: "Space to Clear", systemImageName: "sparkles")
        AppShortcut(intent: OpenCoreTendIntent(), phrases: ["Open \(.applicationName)", "Open \(\.$space) in \(.applicationName)"],
                    shortTitle: "Open CoreTend", systemImageName: "macwindow")
    }
}

extension Notification.Name {
    static let coreTendOpenDestination = Notification.Name("CoreTendOpenDestination")
}

private enum IntentText {
    static var french: Bool { AppLanguage.usesFrench(CoreTendPreferences().resolvedLanguage(storedValue: nil)) }

    static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: value)
    }
}
