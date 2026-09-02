// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
@testable import CoreTendApp

/// Regression guard for the dead-module finding in
/// Documentation/Audits/SESSION_2026-08-09_AUDIT.md: `ModuleID` previously
/// declared cases (`.performance`, `.myClutter`, `.cloudCleanup`,
/// `.favoritesRecents`) with live detail-view switch arms that `SidebarGroup
/// .all` never listed, so they compiled, shipped, and were unreachable from
/// the actual app UI. Every declared module must now be reachable from the
/// sidebar — a module that only wants to be reachable another way (as
/// `FavoritesRecentsView` now is, from Space Lens's toolbar) should not have
/// a `ModuleID` case at all, rather than an orphaned unreachable one.
@Suite("Sidebar reachability")
struct SidebarReachabilityTests {
    @Test("every declared module is reachable from some sidebar group")
    func everyModuleIsVisible() {
        let declared = Set(ModuleID.allCases)
        let visible = Set(SidebarGroup.visibleModules)
        #expect(declared == visible)
    }

    @Test("no sidebar group lists a module twice")
    func noDuplicateModulesAcrossGroups() {
        let all = SidebarGroup.all.flatMap(\.modules)
        #expect(all.count == Set(all).count)
    }
}
