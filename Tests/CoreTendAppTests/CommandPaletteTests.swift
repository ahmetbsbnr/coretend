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
        for module in ModuleID.allCases {
            #expect(!module.label.isEmpty)
            #expect(!module.systemImage.isEmpty)
        }
        #expect(ModuleID.allCases.count == 10)
    }
}
