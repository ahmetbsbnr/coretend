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
        #expect(modules == [.smartCare, .cleanup, .spaceLens, .duplicates, .applications, .protection, .myActivity, .settings])
        #expect(Set(modules.map(\.rawValue)).count == modules.count)
    }
}
