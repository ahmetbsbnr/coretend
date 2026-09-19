// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

// The catalogue of destinations and their grouping. See docs/INFORMATION_ARCHITECTURE.md.

import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence

enum ModuleID: String, CaseIterable, Identifiable {
    /// The first sidebar entry: it renders `DashboardView` and its label is
    /// `module.dashboard`. The case name and `"Smart Care"` raw value are kept
    /// only because the raw value is a stable identity matched elsewhere
    /// (`sidebar.<rawValue>` a11y ids, activity-summary prefixes); the
    /// standalone Smart Care view was retired in favour of the Dashboard.
    case smartCare = "Smart Care"
    /// The record. Direction B's spine: every scan, approval and refusal,
    /// readable backwards. It was a sheet buried inside My Activity; a product
    /// whose strongest engineering is its safety model cannot keep the
    /// evidence of that model hidden two levels down.
    case record = "Record"
    case cleanup = "Cleanup"
    case protection = "Protection"
    case performance = "Performance"
    case applications = "Applications"
    case duplicates = "Duplicates"
    case spaceLens = "Space Lens"

    var id: String { rawValue }

    /// Resolves a module from a shell-friendly identifier.
    ///
    /// `rawValue` is a display-shaped string with capitals and spaces
    /// ("Space Lens", "Smart Care") because it is a stable identity matched
    /// elsewhere. Passing that through a shell argument is awkward, and
    /// guessing at it silently does not work: the capture script passed
    /// "spaceLens" and "applications", `ModuleID(rawValue:)` returned nil, and
    /// every screenshot was of the Dashboard — while the checks run against
    /// those screenshots all passed, because the Dashboard renders fine.
    ///
    /// So matching is explicit and forgiving: case-insensitive, and ignoring
    /// spaces, so both the raw value and the Swift case name resolve.
    /// `ModuleIdentifierTests` asserts every module is reachable both ways.
    init?(testIdentifier: String) {
        let normalized = testIdentifier
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        guard let match = ModuleID.allCases.first(where: {
            $0.rawValue.replacingOccurrences(of: " ", with: "").lowercased() == normalized
            || String(describing: $0).lowercased() == normalized
        }) else { return nil }
        self = match
    }

    var identity: MCModuleIdentity {
        switch self {
        case .smartCare: .smartCare
        case .cleanup: .cleanup
        case .protection: .protection
        case .performance: .performance
        case .applications: .applications
        case .duplicates: .duplicates
        case .spaceLens: .spaceLens
        case .record: .record
        }
    }

    var systemImage: String { identity.icon }

    /// Whether this module has a scan to start.
    ///
    /// Stated once. The toolbar, the Overview's scan rows and the Overview's
    /// summary-prefix lookup each had their own list, and two of them were
    /// already out of date with the third.
    var hasScan: Bool {
        switch self {
        case .cleanup, .spaceLens, .duplicates, .applications: true
        case .smartCare, .record, .protection, .performance: false
        }
    }

    /// Localized display label. `rawValue` stays the internal stable identity
    /// (matched against `ActivityRecord.summary` prefixes elsewhere).
    var label: String {
        switch self {
        case .smartCare: L("module.overview")
        case .cleanup: L("module.cleanup")
        case .protection: L("module.protection")
        case .performance: L("performance.nav_title")
        case .applications: L("apps.title")
        case .duplicates: L("module.duplicates")
        case .spaceLens: L("module.explore")
        case .record: L("record.title")
        }
    }
}

/// Sidebar groups — logical, quiet, native.
struct SidebarGroup: Identifiable {
    let id: String
    let title: String?
    let modules: [ModuleID]

    /// The information architecture, rebuilt from what a person is trying to
    /// do rather than from where code happened to live.
    ///
    /// Two things at the top with no heading: where you are, and what has
    /// happened. Then the disk — find space, explore it, resolve duplicates.
    /// Then the Mac itself — what is installed, whether it can be trusted, how
    /// it is running.
    ///
    /// What is *not* here any more, and why:
    /// - "My Clutter" and "Cloud Cleanup" were read-only lenses on the disk
    ///   presented as destinations. They are tabs of Explore now, next to the
    ///   map they were always a different view of.
    /// - "Activity" duplicated the Record with less evidence. Merged.
    /// - The browser-cache cleaner lived under Integrity, where it did not
    ///   belong: it cleans caches. It is a tab of Cleanup.
    /// - Launch agents lived under Performance, where they were the one
    ///   non-temporal thing on a temporal screen. They are what starts
    ///   automatically, which is an integrity question.
    static let all: [SidebarGroup] = [
        SidebarGroup(id: "main", title: nil, modules: [.smartCare, .record]),
        SidebarGroup(id: "space", title: L("sidebar.space"),
                     modules: [.cleanup, .spaceLens, .duplicates]),
        SidebarGroup(id: "mac", title: L("sidebar.mac"),
                     modules: [.applications, .protection, .performance]),
    ]

    /// The groups this build can actually deliver, with unsupported modules
    /// removed and any group left empty dropped entirely.
    ///
    /// Filtering here rather than in the view is what makes a missing module an
    /// absence instead of a failure: the sidebar, the command palette and
    /// keyboard navigation all read from this, so none of them can offer
    /// something the build cannot do.
    static func available(_ capabilities: AppCapabilities = .forCurrentBuild()) -> [SidebarGroup] {
        all.compactMap { group in
            let modules = group.modules.filter(capabilities.supports)
            guard !modules.isEmpty else { return nil }
            return SidebarGroup(id: group.id, title: group.title, modules: modules)
        }
    }

    static var visibleModules: [ModuleID] {
        available().flatMap(\.modules)
    }
}
