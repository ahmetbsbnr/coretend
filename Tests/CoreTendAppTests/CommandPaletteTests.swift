// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
@testable import CoreTendApp

@Suite("Command palette filtering")
struct CommandPaletteTests {
    @Test("empty query matches everything")
    func emptyQueryMatchesAll() {
        #expect(paletteMatches(label: "Space Lens", query: ""))
        #expect(paletteMatches(label: "Space Lens", query: "   "))
    }

    @Test("case- and diacritic-insensitive substring match")
    func caseAndDiacriticInsensitive() {
        #expect(paletteMatches(label: "Space Lens", query: "space"))
        #expect(paletteMatches(label: "Réglages", query: "reglages"))
        #expect(!paletteMatches(label: "Space Lens", query: "zzz"))
    }

    @Test("every sidebar destination has a non-empty label and icon")
    func everyModuleHasLabelAndIcon() {
        let modules = SidebarGroup.visibleModules
        for module in modules {
            #expect(!module.label.isEmpty)
            #expect(!module.systemImage.isEmpty)
        }
        // Eight destinations in three groups. My Clutter and Cloud Cleanup
        // became tabs of Explore, Activity merged into the Record, and the
        // browser-cache cleaner moved from Integrity to Cleanup — see the
        // SidebarGroup.all comment for each reason.
        #expect(modules == [
            .smartCare, .record,
            .cleanup, .spaceLens, .duplicates,
            .applications, .protection, .performance,
        ])
        #expect(Set(modules.map(\.rawValue)).count == modules.count)
    }
}
