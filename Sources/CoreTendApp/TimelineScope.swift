// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// The scan methodologies currently wired into Storage Timeline. Each case's
/// `rawValue` is the exact `scope` string stored in `timeline_snapshots` — the
/// single source of truth for what "comparable" means (see `Store.swift`'s
/// Timeline section). Adding an engine to Timeline means adding a case here,
/// wiring that engine's completed-scan handler to record a snapshot with this
/// scope, and nothing else — no new comparison logic, since every comparison
/// already operates within one scope.
enum TimelineScope: String, CaseIterable, Identifiable, Sendable {
    case cleanup
    case duplicates
    case leftovers
    case privacy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cleanup: L("timeline.scope.cleanup")
        case .duplicates: L("timeline.scope.duplicates")
        case .leftovers: L("timeline.scope.leftovers")
        case .privacy: L("timeline.scope.privacy")
        }
    }

    /// Reuses each scope's existing module identity rather than inventing a
    /// second icon/color language just for Timeline.
    var identity: MCModuleIdentity {
        switch self {
        case .cleanup: .cleanup
        case .duplicates: .duplicates
        case .leftovers: .applications
        case .privacy: .protection
        }
    }

    var systemImage: String { identity.icon }
    var tint: Color { identity.color }

    /// Where this scan lives in the app, for "Run a scan" navigation from an
    /// empty Timeline state.
    var module: ModuleID {
        switch self {
        case .cleanup: .cleanup
        case .duplicates: .duplicates
        case .leftovers: .applications
        case .privacy: .protection
        }
    }
}

/// Localizes a category identifier written by a scan engine (a Cleanup rule
/// ID, or a fixed bucket name for engines that don't have sub-rules) into
/// display text. Falls back to the raw identifier — never a blank label —
/// for a category no longer recognized (e.g. a retired rule still present in
/// old history).
enum TimelineCategoryLabel {
    static func display(engine: String, category: String) -> String {
        let key = "timeline.category.\(engine).\(category)"
        let localized = L(key)
        return localized == key ? category : localized
    }
}
