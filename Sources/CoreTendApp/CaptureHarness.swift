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
