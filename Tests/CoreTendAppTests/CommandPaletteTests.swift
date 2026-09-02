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
        // .myClutter/.cloudCleanup/.performance were reconnected to the "more"
        // sidebar group in the 2026-08-09 dead-module audit — each does
        // something unique (large/old-files finder, cloud sync-state
        // analysis, broken-LaunchAgent detection) so they were kept and
        // re-wired rather than deleted. See Documentation/Audits/
        // SESSION_2026-08-09_AUDIT.md.
        #expect(modules == [
            .smartCare, .cleanup, .spaceLens, .duplicates, .applications,
            .myClutter, .cloudCleanup, .performance,
            .protection, .myActivity, .settings,
        ])
        #expect(Set(modules.map(\.rawValue)).count == modules.count)
    }
}
