import XCTest
@testable import AppShell

final class AppShellTests: XCTestCase {
    func testNavigationHasExactlyEightProductDestinations() {
        XCTAssertEqual(Destination.allCases.count, 8)
        XCTAssertEqual(Set(Destination.allCases.map(\.rawValue)).count, 8)
    }

    func testCriticalCopyHasEnglishFrenchParity() {
        XCTAssertEqual(Set(ProductCopy.english.keys), Set(ProductCopy.french.keys))
        XCTAssertTrue(ProductCopy.english.keys.contains("overview.title"))
        XCTAssertTrue(ProductCopy.french.keys.contains("safety.notice"))
    }

    func testCommandPaletteOffersEveryDestinationAndSettings() {
        let commands = CommandPaletteCatalog.commands(french: true)
        XCTAssertEqual(commands.count, Destination.allCases.count + 1)
        XCTAssertEqual(Set(commands.compactMap { command -> Destination? in
            if case .destination(let destination) = command.target { return destination }
            return nil
        }), Set(Destination.allCases))
        XCTAssertTrue(commands.contains { $0.target == .settings })
    }

    func testCommandPaletteSearchUsesLocalizedLabelsAndAliases() {
        let frenchResults = CommandPaletteCatalog.search("performances", french: true)
        XCTAssertEqual(frenchResults.map(\.target), [.destination(.performance)])
        let aliasResults = CommandPaletteCatalog.search("favoris", french: true)
        XCTAssertEqual(aliasResults.map(\.target), [.destination(.overview)])
        XCTAssertTrue(CommandPaletteCatalog.search("sans résultat", french: false).isEmpty)
    }

    func testCommandPaletteArrowNavigationSelectsAndClampsResults() {
        let commands = CommandPaletteCatalog.search("", french: false)
        XCTAssertEqual(CommandPaletteNavigation.move(in: commands, selectedID: nil, direction: .down), commands.first?.id)
        XCTAssertEqual(CommandPaletteNavigation.move(in: commands, selectedID: nil, direction: .up), commands.last?.id)
        XCTAssertEqual(CommandPaletteNavigation.move(in: commands, selectedID: commands.last?.id, direction: .down), commands.last?.id)
        XCTAssertEqual(CommandPaletteNavigation.move(in: commands, selectedID: commands.first?.id, direction: .up), commands.first?.id)
        XCTAssertNil(CommandPaletteNavigation.move(in: [], selectedID: nil, direction: .down))
    }
}
