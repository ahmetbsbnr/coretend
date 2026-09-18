// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppKit
import SwiftUI
import DesignSystem
import Persistence

/// What a screenshot of the app has to be able to prove about itself.
///
/// `Scripts/capture-module.sh` once photographed the Dashboard eleven times
/// while claiming eleven modules, and every check run against the images
/// passed. A capture is evidence only if the thing captured can be identified
/// without trusting the caller — so in test mode the app writes down what it
/// is actually showing, and the script refuses the capture if that does not
/// match what was asked for.
///
/// Everything here is inert outside `CORETEND_TEST_MODE`. None of it reads
/// user preferences and none of it persists beyond the isolated store folder.
enum CaptureHarness {

    /// A named window size, so a capture says "compact" rather than "1000×700"
    /// and the numbers live in one place.
    enum WindowSize: String, CaseIterable {
        case compact, standard, large

        var size: CGSize {
            switch self {
            // The minimum the shell allows. Whether the minimum itself is right
            // is a design question for the shell, not for this harness.
            case .compact: CGSize(width: MCSize.windowMinWidth, height: 700)
            case .standard: CGSize(width: MCSize.windowDefaultWidth, height: MCSize.windowDefaultHeight)
            case .large: CGSize(width: 1600, height: 1000)
            }
        }
    }

    enum Appearance: String, CaseIterable {
        case light, dark
        var name: NSAppearance.Name { self == .dark ? .darkAqua : .aqua }
    }

    private static var environment: [String: String] { ProcessInfo.processInfo.environment }

    private static var isActive: Bool {
        TestStoreOverride.isTestMarkerSet(environment: environment)
            && TestStoreOverride.resolve(environment: environment).directory != nil
    }

    /// The appearance a capture asked for, or nil to follow the system.
    static var requestedAppearance: Appearance? {
        guard isActive, let raw = environment["CORETEND_TEST_APPEARANCE"] else { return nil }
        return Appearance(rawValue: raw.lowercased())
    }

    /// A stand-in home directory for scans, so a capture of a review screen
    /// shows controlled files rather than whatever is in this machine's
    /// caches. Every scan that takes a `home` reads this first.
    static var homeOverride: URL? {
        guard isActive, let raw = environment["CORETEND_TEST_HOME"], !raw.isEmpty else { return nil }
        return URL(fileURLWithPath: raw, isDirectory: true)
    }

    /// The home a scan should use: the fixture in test mode, the real one
    /// otherwise.
    static var scanHome: URL { homeOverride ?? FileManager.default.homeDirectoryForCurrentUser }

    /// Whether a capture asked the module to start its scan on appear, so a
    /// review or scanning state can be photographed without a pointer.
    static var autostartScan: Bool {
        isActive && environment["CORETEND_TEST_AUTOSTART"] == "1"
    }

    /// Appends the state a module has reached to the evidence file. The
    /// capture script waits for the state it was asked for and refuses the
    /// capture otherwise — an idle screen photographed as "review" is the
    /// kind of silent wrong that this whole file exists to prevent.
    @MainActor
    static func note(state: String) {
        guard isActive, let directory = TestStoreOverride.resolve(environment: environment).directory else { return }
        let url = directory.appendingPathComponent("showing.txt")
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (existing + "state=\(state)\n").write(to: url, atomically: true, encoding: .utf8)
    }

    static var requestedWindowSize: WindowSize? {
        guard isActive, let raw = environment["CORETEND_TEST_WINDOW"] else { return nil }
        return WindowSize(rawValue: raw.lowercased())
    }

    /// Resizes the key window to the requested size, then writes the evidence
    /// file. Called once the main window's content has appeared.
    ///
    /// The window frame is resized here rather than through `.defaultSize`
    /// because `defaultSize` only applies on a first launch with no autosaved
    /// frame, and the isolated store does not isolate window frames — they live
    /// in the app's own defaults domain. A capture that silently inherited the
    /// previous run's frame would be a capture of the wrong size.
    @MainActor
    static func settle(showing module: ModuleID?) {
        guard isActive, let directory = TestStoreOverride.resolve(environment: environment).directory else { return }
        if let size = requestedWindowSize, let window = NSApp.keyWindow ?? NSApp.windows.first {
            var frame = window.frame
            frame.size = size.size
            window.setFrame(frame, display: true)
        }
        let evidence = [
            "module=\(module?.rawValue ?? "")",
            "appearance=\(NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? "dark" : "light")",
            "window=\(requestedWindowSize?.rawValue ?? "inherited")",
            "increaseContrast=\(NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)",
            "reduceTransparency=\(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)",
        ].joined(separator: "\n") + "\n"
        try? evidence.write(to: directory.appendingPathComponent("showing.txt"),
                            atomically: true, encoding: .utf8)
    }
}
