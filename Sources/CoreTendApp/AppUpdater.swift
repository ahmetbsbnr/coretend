import Foundation
import Observation
import Sparkle
import AppShell

/// Updates through Sparkle: signed (EdDSA), from the feed on CoreTend's site, checked only when the
/// person allows it. A build without a feed (local builds) and every fixture launch never start it.
@MainActor @Observable
final class AppUpdater {
    private let controller: SPUStandardUpdaterController?

    init(preferences: CoreTendPreferences = CoreTendPreferences()) {
        let hasFeed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        controller = hasFeed && preferences.usesPersistentStorage
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
        automaticChecks = controller?.updater.automaticallyChecksForUpdates ?? false
    }

    var isAvailable: Bool { controller != nil }

    /// Mirrors Sparkle's own setting, so Settings can show and change it.
    var automaticChecks: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticChecks }
    }

    func checkForUpdates() { controller?.checkForUpdates(nil) }
}
