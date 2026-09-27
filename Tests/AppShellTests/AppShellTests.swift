import XCTest
@testable import AppShell

final class AppShellTests: XCTestCase {
    func testNavigationHasExactlyEightProductDestinations() {
        XCTAssertEqual(Destination.allCases.count, 8)
        XCTAssertEqual(Set(Destination.allCases.map(\.rawValue)).count, 8)
    }

    func testDestinationRestorationAndRouteMappingCoverAllEightDestinations() {
        XCTAssertEqual(Destination.restored(from: nil), .overview)
        XCTAssertEqual(Destination.restored(from: "obsolete-destination"), .overview)
        for destination in Destination.allCases {
            XCTAssertEqual(Destination.restored(from: destination.rawValue), destination)
        }
        XCTAssertEqual(Set(Destination.allCases.map(\.route)), Set(DestinationRoute.allCases))
    }

    func testCriticalCopyHasEnglishFrenchParity() {
        XCTAssertEqual(Set(ProductCopy.english.keys), Set(ProductCopy.french.keys))
        XCTAssertTrue(ProductCopy.english.keys.contains("overview.title"))
        XCTAssertTrue(ProductCopy.french.keys.contains("safety.notice"))
    }

    func testSystemMeasurementCopyNamesSourceAndLimitsClaimsInBothLanguages() {
        let english = ProductCopy.value(for: "metrics.scope", french: false)
        let french = ProductCopy.value(for: "metrics.scope", french: true)
        let sources = ["volume", "load", "processors", "memory", "uptime", "thermal"]

        XCTAssertTrue(english.contains("macOS"))
        XCTAssertTrue(english.contains("not a system-health diagnosis"))
        XCTAssertTrue(english.contains("do not estimate recoverable space"))
        XCTAssertTrue(french.contains("macOS"))
        XCTAssertTrue(french.contains("pas un diagnostic de santé du système"))
        XCTAssertTrue(french.contains("n’estiment pas l’espace récupérable"))
        for source in sources {
            let key = "metrics.source.\(source)"
            XCTAssertNotEqual(ProductCopy.value(for: key, french: false), key, "Missing English source for \(source)")
            XCTAssertNotEqual(ProductCopy.value(for: key, french: true), key, "Missing French source for \(source)")
        }
        XCTAssertTrue(ProductCopy.value(for: "metrics.source.volume", french: false).contains("/"))
        XCTAssertTrue(ProductCopy.value(for: "metrics.source.volume", french: true).contains("/"))
    }

    func testProductCopyRejectsAffirmativeHealthAndRecoveredSpaceClaims() {
        let forbiddenEnglish = ["the system is healthy", "healthy system", "your mac is safe", "space recovered", "space was recovered", "space freed"]
        let forbiddenFrench = ["le système est sain", "système en bonne santé", "votre mac est sûr", "espace récupéré", "espace a été récupéré", "espace libéré"]

        for copy in ProductCopy.english.values {
            for claim in forbiddenEnglish {
                XCTAssertFalse(copy.localizedCaseInsensitiveContains(claim), "Forbidden English claim: \(claim)")
            }
        }
        for copy in ProductCopy.french.values {
            for claim in forbiddenFrench {
                XCTAssertFalse(copy.localizedCaseInsensitiveContains(claim), "Forbidden French claim: \(claim)")
            }
        }
    }

    func testSpaceLensDeleteCopyCoversSelectionReviewCancelAndStatusInBothLanguages() {
        let keys = [
            "explore.delete.select", "explore.delete.review", "spacelens.delete.title",
            "spacelens.delete.confirm", "spacelens.delete.success.one", "spacelens.delete.success.many",
            "spacelens.delete.partial.one", "spacelens.delete.partial.many", "spacelens.delete.failed.one",
            "spacelens.delete.failed.many", "spacelens.delete.blocked", "spacelens.delete.cancelled"
        ]
        for key in keys {
            XCTAssertNotEqual(ProductCopy.value(for: key, french: false), key, "Missing English copy for \(key)")
            XCTAssertNotEqual(ProductCopy.value(for: key, french: true), key, "Missing French copy for \(key)")
        }

        XCTAssertTrue(ProductCopy.value(for: "spacelens.delete.title", french: false).contains("Trash"))
        XCTAssertTrue(ProductCopy.value(for: "spacelens.delete.title", french: true).contains("Corbeille"))
        XCTAssertTrue(ProductCopy.value(for: "spacelens.delete.success.many", french: false).contains("Trash"))
        XCTAssertTrue(ProductCopy.value(for: "spacelens.delete.success.many", french: true).contains("Corbeille"))
        XCTAssertFalse(ProductCopy.value(for: "spacelens.delete.success.many", french: false).localizedCaseInsensitiveContains("space recovered"))
        XCTAssertFalse(ProductCopy.value(for: "spacelens.delete.success.many", french: true).localizedCaseInsensitiveContains("espace récupéré"))
    }

    func testFolderAccessGuidanceIsLocalizedAndLimitedToChosenFolders() {
        let english = ProductCopy.value(for: "settings.folderaccess.help", french: false)
        let french = ProductCopy.value(for: "settings.folderaccess.help", french: true)

        XCTAssertTrue(english.contains("only folders you choose in the macOS picker"))
        XCTAssertTrue(french.contains("dossiers que vous choisissez dans le sélecteur macOS"))
    }

    func testRootScanFailuresDistinguishDeniedFromUnavailableInBothLanguages() {
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "permission_denied", french: false), "macOS denied access to the selected folder.")
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "metadata_unavailable", french: false), "The selected folder's availability could not be determined.")
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "missing", french: false), "The selected folder no longer exists.")
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "permission_denied", french: true), "macOS a refusé l’accès au dossier sélectionné.")
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "metadata_unavailable", french: true), "Impossible de déterminer la disponibilité du dossier choisi.")
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "missing", french: true), "Le dossier choisi n’existe plus.")
    }

    func testFullDiskAccessGuidanceIsLocalizedAndDoesNotSolicitOrOpenSettings() {
        let english = ProductCopy.value(for: "settings.fulldiskaccess.help", french: false)
        let french = ProductCopy.value(for: "settings.fulldiskaccess.help", french: true)

        XCTAssertTrue(english.contains("does not request Full Disk Access"))
        XCTAssertTrue(english.contains("cannot open Privacy settings"))
        XCTAssertTrue(french.contains("ne demande pas l’accès intégral au disque"))
        XCTAssertTrue(french.contains("ne peut pas ouvrir à votre place les réglages de confidentialité"))
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

    func testTrashFailureDetailPresentsEnglishReasonAndOriginalPath() {
        let path = "/fixture/My Archive.app"
        let detail = "\(path) | reason=trash_failed"
        XCTAssertEqual(ProductCopy.activityDetail(detail, failureCode: "trash_failed", french: false), "\(path) — Could not move to Trash.")
    }

    func testTrashFailureDetailPresentsFrenchReasonAndOriginalPath() {
        let path = "/fixture/My Archive.app"
        let detail = "\(path) | reason=trash_failed"
        XCTAssertEqual(ProductCopy.activityDetail(detail, failureCode: "trash_failed", french: true), "\(path) — Déplacement vers la Corbeille impossible.")
    }

    func testTrashFailureDetailPreservesFilenameEndingInMarker() {
        let path = "/fixture/report | reason=trash_failed"
        let detail = "\(path) | reason=trash_failed"
        XCTAssertEqual(ProductCopy.activityDetail(detail, failureCode: "trash_failed", french: false), "\(path) — Could not move to Trash.")
    }

    func testNonFailedFilenameEndingInKnownSuffixPassesThroughUnchanged() {
        let detail = "/fixture/report | reason=trash_failed"
        XCTAssertEqual(ProductCopy.activityDetail(detail, failureCode: nil, french: true), detail)
        XCTAssertEqual(ProductCopy.activityDetail(detail, failureCode: nil, french: false), detail)
    }

    func testFailedEventWithPlainPathPassesThroughUnchanged() {
        let detail = "/fixture/My Archive.app | reason=trash_failed"
        XCTAssertEqual(ProductCopy.activityDetail(detail, failureCode: nil, french: true), detail)
        XCTAssertEqual(ProductCopy.activityDetail(detail, failureCode: nil, french: false), detail)
    }

    func testUnknownActivityDetailPassesThroughUnchanged() {
        let details = [
            "/fixture/My Archive.app | reason=other_failure",
            "/fixture/My Archive.app | reason=trash_failed | extra=data"
        ]
        for detail in details {
            XCTAssertEqual(ProductCopy.activityDetail(detail, failureCode: "other_failure", french: true), detail)
            XCTAssertEqual(ProductCopy.activityDetail(detail, failureCode: "other_failure", french: false), detail)
        }
    }
}
