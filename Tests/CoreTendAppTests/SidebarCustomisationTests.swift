// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// People choose what is in their own sidebar.
///
/// The HIG: "When possible, let people customize the contents of a sidebar…
/// people can decide which areas are most important and in what order they
/// appear." CoreTend has ten modules and most people use two or three; one list
/// for everyone is a list tuned for nobody.
@Suite("Sidebar customisation")
@MainActor
struct SidebarCustomisationTests {
    private func make() -> (SidebarCustomisation, UserDefaults, String) {
        let name = "coretend.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (SidebarCustomisation(defaults: defaults), defaults, name)
    }

    /// An untouched install looks exactly as it always has.
    @Test func nothingChangesUntilSomethingIsCustomised() {
        let (custom, defaults, suite) = make()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(custom.groups().flatMap(\.modules) == SidebarGroup.visibleModules)
    }

    @Test func hidingRemovesAModuleFromTheSidebar() {
        let (custom, defaults, suite) = make()
        defer { defaults.removePersistentDomain(forName: suite) }
        custom.setHidden(.cloudCleanup, true)
        #expect(!custom.groups().flatMap(\.modules).contains(.cloudCleanup))
    }

    /// Hiding is not removing. A hidden module stays reachable from the Go menu
    /// and the command palette, both of which read `SidebarGroup.visibleModules`
    /// — someone who hides Cloud Cleanup said "not in my sidebar", not "never
    /// again", and a customisation that makes a feature unreachable generates
    /// support requests.
    @Test func aHiddenModuleIsStillReachableElsewhere() {
        let (custom, defaults, suite) = make()
        defer { defaults.removePersistentDomain(forName: suite) }
        custom.setHidden(.cloudCleanup, true)
        #expect(SidebarGroup.visibleModules.contains(.cloudCleanup),
                "hiding a module removed it from the menus too")
    }

    /// The Dashboard is where routing falls back when a selection is invalid.
    /// A sidebar without it has no home to return to.
    @Test func theDashboardCannotBeHidden() {
        let (custom, defaults, suite) = make()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(SidebarCustomisation.canHide(.smartCare) == false)
        custom.setHidden(.smartCare, true)
        #expect(custom.groups().flatMap(\.modules).contains(.smartCare))
    }

    /// A group emptied by hiding disappears rather than rendering a header with
    /// nothing under it — the same rule the distribution filter follows.
    @Test func aGroupEmptiedByHidingIsDropped() {
        let (custom, defaults, suite) = make()
        defer { defaults.removePersistentDomain(forName: suite) }
        let more = SidebarGroup.all.first { $0.id == "more" }!
        for module in more.modules { custom.setHidden(module, true) }
        #expect(!custom.groups().contains { $0.id == "more" })
        for group in custom.groups() { #expect(!group.modules.isEmpty) }
    }

    @Test func customisationSurvivesARelaunch() {
        let (custom, defaults, suite) = make()
        defer { defaults.removePersistentDomain(forName: suite) }
        custom.setHidden(.performance, true)
        custom.setOrder([.duplicates, .cleanup])
        let reopened = SidebarCustomisation(defaults: defaults)
        #expect(reopened.isHidden(.performance))
        #expect(reopened.groups().first { $0.id == "storage" }?.modules.first == .duplicates)
    }

    /// Grouping survives customisation: a reordered module keeps its group,
    /// because the groups are what make ten rows scannable.
    @Test func reorderingHappensWithinGroups() {
        #expect(SidebarCustomisation.arrange([.cleanup, .spaceLens, .duplicates],
                                             by: [.duplicates]) == [.duplicates, .cleanup, .spaceLens])
    }

    /// Unplaced modules keep their declared position, below placed ones — so
    /// arranging one module does not scramble the rest.
    @Test func unplacedModulesKeepTheirDeclaredOrder() {
        #expect(SidebarCustomisation.arrange([.cleanup, .spaceLens, .duplicates], by: [])
                == [.cleanup, .spaceLens, .duplicates])
    }

    /// A module removed from the app leaves its name in a user's defaults
    /// forever. Carrying it would mean a stale string shaping the sidebar of
    /// someone who once hid something that no longer exists.
    @Test func unknownStoredNamesAreDropped() {
        let name = "coretend.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(["Retired Module", "Cloud Cleanup"], forKey: SidebarCustomisation.hiddenKey)
        defaults.set(["Retired Module", "Duplicates"], forKey: SidebarCustomisation.orderKey)
        let custom = SidebarCustomisation(defaults: defaults)
        #expect(custom.isHidden(.cloudCleanup))
        #expect(custom.groups().flatMap(\.modules).allSatisfy { ModuleID.allCases.contains($0) })
    }

    /// A stored hidden entry naming the pinned module is dropped on read, not
    /// only refused on write — defaults can be edited by hand, or written by an
    /// older build.
    @Test func aStoredAttemptToHideTheDashboardIsIgnored() {
        let name = "coretend.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set([ModuleID.smartCare.rawValue], forKey: SidebarCustomisation.hiddenKey)
        let custom = SidebarCustomisation(defaults: defaults)
        #expect(!custom.isHidden(.smartCare))
    }

    /// A customisation with no way out is a trap: someone who hides six modules
    /// to try it needs one action to undo it, not six.
    @Test func resetRestoresTheShippedSidebar() {
        let (custom, defaults, suite) = make()
        defer { defaults.removePersistentDomain(forName: suite) }
        custom.setHidden(.performance, true)
        custom.setOrder([.duplicates])
        custom.reset()
        #expect(custom.groups().flatMap(\.modules) == SidebarGroup.visibleModules)
    }
}
