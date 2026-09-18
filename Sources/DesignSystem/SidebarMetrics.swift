// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppKit
import Observation

/// The row size the user chose for sidebars, system-wide.
///
/// System Settings ▸ Appearance ▸ "Sidebar icon size" offers Small, Medium and
/// Large, and every app that uses a standard `List` with `.listStyle(.sidebar)`
/// follows it for free. The HIG is explicit:
///
/// > "A sidebar's row height, text, and glyph size depend on its overall size,
/// > which can be small, medium, or large. You can set the size
/// > programmatically, but people can also change it by selecting a different
/// > sidebar icon size in General settings."
///
/// CoreTend replaced that `List` with its own sidebar and lost the behaviour
/// without noticing. Rows were fixed at 13 pt text and a 14 pt glyph, so
/// someone who enlarged their sidebar icons system-wide — which people do for
/// legibility, not decoration — got no change at all. That is an accessibility
/// regression, and it is the predictable cost of taking over a system control
/// without enumerating what the system was doing.
///
/// AppKit exposes the setting as the `NSTableViewDefaultSizeMode` global
/// default: 1 small, 2 medium, 3 large. There is no SwiftUI environment key
/// for it on macOS, so it is read here and published the same way
/// `MCAccessibilityState` publishes Increase Contrast.
@MainActor
@Observable
public final class MCSidebarMetrics {
    public static let shared = MCSidebarMetrics()

    public enum Size: Int, Sendable, CaseIterable {
        case small = 1
        case medium = 2
        case large = 3

        /// Row label point size.
        public var textSize: CGFloat {
            switch self {
            case .small: 11
            case .medium: 13
            case .large: 15
            }
        }

        /// Glyph point size. Tracks the text rather than scaling
        /// independently, so a row stays a row at every setting.
        public var iconSize: CGFloat {
            switch self {
            case .small: 12
            case .medium: 14
            case .large: 17
            }
        }

        /// Vertical padding per row.
        public var rowPadding: CGFloat {
            switch self {
            case .small: 4
            case .medium: 6
            case .large: 9
            }
        }

        /// Group header point size.
        public var sectionSize: CGFloat {
            switch self {
            case .small: 10
            case .medium: 11
            case .large: 12
            }
        }
    }

    public private(set) var size: Size

    nonisolated static let defaultsKey = "NSTableViewDefaultSizeMode"

    private init() {
        size = Self.read()
        // The setting changes while the app is running — someone adjusts it to
        // fix legibility and expects the window in front of them to respond,
        // not the next launch.
        DistributedNotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.size = MCSidebarMetrics.read() }
        }
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.size = MCSidebarMetrics.read() }
        }
    }

    /// Reads the global default, defaulting to medium.
    ///
    /// `integer(forKey:)` returns 0 for an absent key, which is not a valid
    /// size — a fresh account that has never touched the setting must get the
    /// system default, not a zero-height row.
    nonisolated static func read(_ defaults: UserDefaults = .standard) -> Size {
        Size(rawValue: defaults.integer(forKey: defaultsKey)) ?? .medium
    }
}
