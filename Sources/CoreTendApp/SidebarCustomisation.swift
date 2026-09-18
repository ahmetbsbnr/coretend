// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Observation

/// Which modules a person wants in their sidebar, and in what order.
///
/// The HIG: "When possible, let people customize the contents of a sidebar. A
/// sidebar lets people navigate to important areas in your app, so it works
/// well when people can decide which areas are most important and in what order
/// they appear."
///
/// CoreTend has ten modules and most people use two or three. The eleven-row
/// list is the same for everyone, which means it is tuned for nobody.
///
/// ## Two rules that keep this from becoming a way to break the app
///
/// **Hiding is not removing.** A hidden module stays reachable from the Go menu
/// and the command palette. Someone who hides Cloud Cleanup has said "not in my
/// sidebar", not "never again" — and a customisation that can make a feature
/// unreachable is a customisation that generates support requests.
///
/// **The Dashboard cannot be hidden.** It is where routing falls back when a
/// selection is invalid, so a sidebar without it has no home to return to.
@MainActor
@Observable
final class SidebarCustomisation {
    static let shared = SidebarCustomisation()

    nonisolated static let hiddenKey = "sidebarHiddenModules"
    nonisolated static let orderKey = "sidebarModuleOrder"

    /// The one module that is always present.
    nonisolated static let pinned: ModuleID = .smartCare

    private let defaults: UserDefaults

    private(set) var hidden: Set<ModuleID>
    /// User-chosen order. Modules absent from it keep their declared position,
    /// so an untouched install looks exactly as it always has.
    private(set) var order: [ModuleID]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hidden = Self.readHidden(defaults)
        order = Self.readOrder(defaults)
    }

    // MARK: - Reading

    /// The groups to render, after hiding and reordering.
    ///
    /// Grouping survives customisation: a reordered module keeps the group it
    /// belongs to, because the groups are what make ten rows scannable. What
    /// the user arranges is the order *within* what they can see.
    func groups(_ available: [SidebarGroup] = SidebarGroup.available()) -> [SidebarGroup] {
        available.compactMap { group in
            let visible = Self.arrange(group.modules.filter { !hidden.contains($0) }, by: order)
            guard !visible.isEmpty else { return nil }
            return SidebarGroup(id: group.id, title: group.title, modules: visible)
        }
    }

    /// Pure, so the ordering rule is testable without a defaults suite.
    nonisolated static func arrange(_ modules: [ModuleID], by order: [ModuleID]) -> [ModuleID] {
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return modules.enumerated().sorted { lhs, rhs in
            switch (rank[lhs.element], rank[rhs.element]) {
            case let (l?, r?): return l < r
            // Unplaced modules keep their declared position, below placed ones.
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    /// Whether a module may be hidden at all.
    nonisolated static func canHide(_ module: ModuleID) -> Bool { module != pinned }

    func isHidden(_ module: ModuleID) -> Bool { hidden.contains(module) }

    // MARK: - Writing

    func setHidden(_ module: ModuleID, _ isHidden: Bool) {
        guard Self.canHide(module) else { return }
        if isHidden { hidden.insert(module) } else { hidden.remove(module) }
        defaults.set(hidden.map(\.rawValue), forKey: Self.hiddenKey)
    }

    func setOrder(_ modules: [ModuleID]) {
        order = modules
        defaults.set(modules.map(\.rawValue), forKey: Self.orderKey)
    }

    /// Back to the shipped sidebar. Present because a customisation with no way
    /// out is a trap: someone who hides six modules to try it needs one action
    /// to undo it, not six.
    func reset() {
        hidden = []
        order = []
        defaults.removeObject(forKey: Self.hiddenKey)
        defaults.removeObject(forKey: Self.orderKey)
    }

    // MARK: - Persistence

    /// Unknown raw values are dropped rather than kept.
    ///
    /// A module removed from the app leaves its name in a user's defaults
    /// forever; carrying it would mean a stale string quietly shaping the
    /// sidebar of someone who once hid something that no longer exists.
    nonisolated static func readHidden(_ defaults: UserDefaults) -> Set<ModuleID> {
        Set((defaults.array(forKey: hiddenKey) as? [String] ?? [])
            .compactMap(ModuleID.init(rawValue:))
            .filter(canHide))
    }

    nonisolated static func readOrder(_ defaults: UserDefaults) -> [ModuleID] {
        (defaults.array(forKey: orderKey) as? [String] ?? []).compactMap(ModuleID.init(rawValue:))
    }
}
