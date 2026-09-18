// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// Keyboard navigation for the hand-built sidebar.
///
/// `List(selection:)` provided arrow-key movement for free. Replacing it with
/// CoreTend's own sidebar means that behaviour is now this project's
/// responsibility, and a keyboard-only or switch-control user loses the whole
/// app if it regresses — silently, because nothing visual changes.
@Suite("Sidebar keyboard navigation")
struct SidebarNavigationKeyboardTests {
    private let order = SidebarGroup.visibleModules

    @Test func everyRoutedModuleIsReachable() {
        #expect(order.count == ModuleID.allCases.count,
                "a module exists that the sidebar never lists, so it is unreachable by keyboard")
        #expect(Set(order).count == order.count, "a module is listed twice")
    }

    @Test func downMovesToTheNextModule() {
        let first = order[0]
        #expect(SidebarNavigation.destination(from: first, moving: false, in: order) == order[1])
    }

    @Test func upMovesToThePreviousModule() {
        #expect(SidebarNavigation.destination(from: order[1], moving: true, in: order) == order[0])
    }

    /// Movement crosses group boundaries: the groups are a visual grouping, not
    /// a navigation barrier. Down from the last row of "Storage" must land on
    /// the first row of "More", not stop.
    @Test func movementCrossesGroupBoundaries() {
        let storage = SidebarGroup.all.first { $0.id == "storage" }!
        let more = SidebarGroup.all.first { $0.id == "more" }!
        let lastOfStorage = storage.modules.last!
        #expect(SidebarNavigation.destination(from: lastOfStorage, moving: false, in: order)
                == more.modules.first!)
    }

    /// Clamps rather than wraps. In a list short enough to see all at once,
    /// jumping from the bottom back to the top on a Down press reads as the app
    /// losing your place.
    @Test func movementClampsAtBothEnds() {
        #expect(SidebarNavigation.destination(from: order.first!, moving: true, in: order) == nil)
        #expect(SidebarNavigation.destination(from: order.last!, moving: false, in: order) == nil)
    }

    @Test func aModuleOutsideTheOrderIsRefusedRatherThanCrashing() {
        let truncated = Array(order.dropFirst())
        #expect(SidebarNavigation.destination(from: order.first!, moving: false, in: truncated) == nil)
    }
}
