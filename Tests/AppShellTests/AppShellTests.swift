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

    func testMenuBarSettingCopyIsPresentInBothLanguages() {
        for key in ["settings.menubar.title", "settings.menubar.help"] {
            XCTAssertNotEqual(ProductCopy.value(for: key, french: false), key)
            XCTAssertNotEqual(ProductCopy.value(for: key, french: true), key)
        }
        XCTAssertTrue(ProductCopy.value(for: "settings.menubar.title", french: false).contains("menu bar"))
        XCTAssertTrue(ProductCopy.value(for: "settings.menubar.title", french: true).contains("barre des menus"))
        XCTAssertTrue(ProductCopy.value(for: "settings.menubar.help", french: false).contains("Disabled by default"))
        XCTAssertTrue(ProductCopy.value(for: "settings.menubar.help", french: true).contains("Désactivé par défaut"))
    }

    func testMenuBarMetricsAndLatestActivityCopyExistsInBothLanguages() {
        for key in ["menubar.metrics.title", "menubar.metrics.help", "menubar.metrics.updated", "menubar.activity.title", "menubar.activity.empty", "menubar.activity.unavailable", "menubar.open"] {
            XCTAssertNotEqual(ProductCopy.value(for: key, french: false), key)
            XCTAssertNotEqual(ProductCopy.value(for: key, french: true), key)
        }
        XCTAssertTrue(ProductCopy.value(for: "menubar.metrics.help", french: false).contains("30 seconds"))
        XCTAssertTrue(ProductCopy.value(for: "menubar.metrics.help", french: true).contains("30 secondes"))
    }

    func testVisibleSamplingLoopStopsWhenItsTaskIsCancelled() async throws {
        let counter = SamplingCounter()
        let task = Task.detached {
            await VisibleSamplingLoop.run(interval: .milliseconds(5)) {
                await counter.record()
            }
        }

        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        try await Task.sleep(for: .milliseconds(10))
        let stoppedCount = await counter.currentCount()
        try await Task.sleep(for: .milliseconds(20))

        XCTAssertGreaterThan(stoppedCount, 0)
        let finalCount = await counter.currentCount()
        XCTAssertEqual(finalCount, stoppedCount)
    }

    func testSavedFileAvailabilityDistinguishesPresentFromMissingOrInaccessibleInBothLanguages() {
        XCTAssertEqual(ProductCopy.savedFileAvailability(isPresent: true, french: false), "Present (current access not verified)")
        XCTAssertEqual(ProductCopy.savedFileAvailability(isPresent: false, french: false), "Missing or inaccessible")
        XCTAssertEqual(ProductCopy.savedFileAvailability(isPresent: true, french: true), "Présent (accès actuel non garanti)")
        XCTAssertEqual(ProductCopy.savedFileAvailability(isPresent: false, french: true), "Absent ou inaccessible")
    }

    func testOnboardingExplainsChosenFoldersReadOnlyScansAndConfirmedTrashInBothLanguages() {
        for key in ["onboarding.title", "onboarding.scope", "onboarding.privacy", "onboarding.start"] {
            XCTAssertNotEqual(ProductCopy.value(for: key, french: false), key)
            XCTAssertNotEqual(ProductCopy.value(for: key, french: true), key)
        }
        XCTAssertTrue(ProductCopy.value(for: "onboarding.scope", french: false).contains("Choose folders"))
        XCTAssertTrue(ProductCopy.value(for: "onboarding.scope", french: false).contains("read-only"))
        XCTAssertTrue(ProductCopy.value(for: "onboarding.scope", french: false).contains("review and confirmation"))
        XCTAssertTrue(ProductCopy.value(for: "onboarding.scope", french: true).contains("Choisissez vous-même"))
        XCTAssertTrue(ProductCopy.value(for: "onboarding.scope", french: true).contains("lecture seule"))
        XCTAssertTrue(ProductCopy.value(for: "onboarding.scope", french: true).contains("revue et confirmation"))
        XCTAssertTrue(ProductCopy.value(for: "onboarding.privacy", french: false).contains("does not request Full Disk Access"))
        XCTAssertTrue(ProductCopy.value(for: "onboarding.privacy", french: true).contains("ne demande pas l’accès intégral"))
    }

    func testRecordDateRangeCopyExistsInBothLanguages() {
        for key in ["record.range", "record.range.all", "record.range.last7", "record.range.last30"] {
            XCTAssertNotEqual(ProductCopy.value(for: key, french: false), key)
            XCTAssertNotEqual(ProductCopy.value(for: key, french: true), key)
        }
        XCTAssertEqual(ProductCopy.value(for: "record.range.last7", french: false), "Last 7 days")
        XCTAssertEqual(ProductCopy.value(for: "record.range.last7", french: true), "7 derniers jours")
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

    func testScanResultAccessibilitySummaryPreservesSourceRiskAndIndependentMeasurementsInBothLanguages() {
        let english = ProductCopy.scanResultAccessibilitySummary(
            name: "fixture.bin", source: "User caches", state: "Low risk",
            allocated: "Unknown", logical: "4 KB", modified: "Unknown", french: false
        )
        XCTAssertTrue(english.contains("fixture.bin"))
        XCTAssertTrue(english.contains("Source: User caches"))
        XCTAssertTrue(english.contains("State: Low risk"))
        XCTAssertTrue(english.contains("Allocated locally: Unknown"))
        XCTAssertTrue(english.contains("Logical size: 4 KB"))
        XCTAssertTrue(english.contains("Modified: Unknown"))
        XCTAssertTrue(english.contains("review before action"))

        let french = ProductCopy.scanResultAccessibilitySummary(
            name: "fixture.bin", source: "Caches utilisateur", state: "Risque élevé",
            allocated: "Inconnu", logical: "4 Ko", modified: "Inconnu", french: true
        )
        XCTAssertTrue(french.contains("fixture.bin"))
        XCTAssertTrue(french.contains("Source : Caches utilisateur"))
        XCTAssertTrue(french.contains("État : Risque élevé"))
        XCTAssertTrue(french.contains("Allouée localement : Inconnu"))
        XCTAssertTrue(french.contains("Taille logique : 4 Ko"))
        XCTAssertTrue(french.contains("Modifié : Inconnu"))
        XCTAssertTrue(french.contains("examiner avant toute action"))
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

    func testSettingsOwnSignatureGuidanceExistsInBothLanguages() {
        for key in ["settings.signature.title", "settings.signature.valid", "settings.signature.invalid", "settings.signature.unavailable", "settings.signature.limit"] {
            XCTAssertNotEqual(ProductCopy.value(for: key, french: false), key, "Missing English copy for \(key)")
            XCTAssertNotEqual(ProductCopy.value(for: key, french: true), key, "Missing French copy for \(key)")
        }
        XCTAssertTrue(ProductCopy.value(for: "settings.signature.limit", french: false).contains("does not establish"))
        XCTAssertTrue(ProductCopy.value(for: "settings.signature.limit", french: true).contains("ne prouve"))
    }

    func testRootScanFailuresDistinguishDeniedFromUnavailableInBothLanguages() {
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "permission_denied", french: false), "macOS denied access to the selected folder.")
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "metadata_unavailable", french: false), "The selected folder's availability could not be determined.")
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "missing", french: false), "The selected folder no longer exists.")
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "permission_denied", french: true), "macOS a refusé l’accès au dossier sélectionné.")
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "metadata_unavailable", french: true), "Impossible de déterminer la disponibilité du dossier choisi.")
        XCTAssertEqual(ProductCopy.scanRootFailure(reason: "missing", french: true), "Le dossier choisi n’existe plus.")
    }

    func testPartialScanFailuresDistinguishPermissionDenialFromOtherUnavailableItems() {
        let deniedEN = ProductCopy.scanPartialFailure(reasons: ["permission_denied"], french: false)
        let unavailableEN = ProductCopy.scanPartialFailure(reasons: ["metadata_unavailable"], french: false)
        XCTAssertTrue(deniedEN.contains("macOS denied access"))
        XCTAssertTrue(unavailableEN.contains("could not be read"))
        XCTAssertNotEqual(deniedEN, unavailableEN)
        XCTAssertFalse(deniedEN.contains("absent"))

        let deniedFR = ProductCopy.scanPartialFailure(reasons: ["permission_denied"], french: true)
        let unavailableFR = ProductCopy.scanPartialFailure(reasons: ["metadata_unavailable"], french: true)
        XCTAssertTrue(deniedFR.contains("macOS a refusé l’accès"))
        XCTAssertTrue(unavailableFR.contains("n’ont pas pu être lus"))
        XCTAssertNotEqual(deniedFR, unavailableFR)
        XCTAssertFalse(deniedFR.localizedCaseInsensitiveContains("absent"))
        let combined = ProductCopy.scanPartialFailure(reasons: ["permission_denied", "directory_read_failed"], french: false)
        XCTAssertTrue(combined.contains("macOS denied access"))
        XCTAssertTrue(combined.contains("other items could not be read"))
        let missing = ProductCopy.scanPartialFailure(reasons: ["missing"], french: true)
        XCTAssertTrue(missing.contains("ont disparu pendant l’analyse"))
    }

    func testScanProgressCopyReportsOnlyMeasuredCountInBothLanguages() {
        XCTAssertEqual(ProductCopy.scanProgress(completedFiles: 0, french: false), "0 files examined")
        XCTAssertEqual(ProductCopy.scanProgress(completedFiles: 12, french: false), "12 files examined")
        XCTAssertEqual(ProductCopy.scanProgress(completedFiles: 0, french: true), "0 fichiers examinés")
        XCTAssertEqual(ProductCopy.scanProgress(completedFiles: 12, french: true), "12 fichiers examinés")
        XCTAssertEqual(ProductCopy.scanProgress(completedFiles: -2, french: false), "0 files examined")
    }

    func testAnalysisProgressCopyReportsMeasuredWorkAndClampsValues() {
        XCTAssertEqual(ProductCopy.duplicateHashProgress(completed: 2, total: 5, french: false), "Hashing candidates: 2/5")
        XCTAssertEqual(ProductCopy.duplicateHashProgress(completed: 9, total: 5, french: true), "Hachage des candidats : 5/5")
        XCTAssertEqual(ProductCopy.similarImageProgress(completed: 3, total: 7, comparingPairs: false, french: true), "Analyse des images : 3/7")
        XCTAssertEqual(ProductCopy.similarImageProgress(completed: 4, total: 6, comparingPairs: true, french: false), "Comparing pairs: 4/6")
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

    func testCommandPaletteSearchAcceptsEnglishAndFrenchAliasesInEitherInterfaceLanguage() {
        let aliases: [(String, String, CommandTarget)] = [
            ("home", "accueil", .destination(.overview)),
            ("history", "historique", .destination(.record)),
            ("clean", "nettoyer", .destination(.cleanup)),
            ("folders", "dossiers", .destination(.explore)),
            ("duplicate files", "doublons exacts", .destination(.duplicates)),
            ("software", "logiciels", .destination(.applications)),
            ("quarantine", "quarantaine", .destination(.integrity)),
            ("measurements", "mesures", .destination(.performance)),
            ("preferences", "préférences", .settings)
        ]
        for (english, french, target) in aliases {
            XCTAssertTrue(CommandPaletteCatalog.search(english, french: true).contains { $0.target == target }, "French UI should find (target) with (english)")
            XCTAssertTrue(CommandPaletteCatalog.search(french, french: false).contains { $0.target == target }, "English UI should find (target) with (french)")
        }
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
    func testSidebarOrderGroupsYourMacThenUnderstandAndCoversEveryDestination() {
        XCTAssertEqual(Destination.sidebarOrder, [.overview, .explore, .cleanup, .duplicates, .applications, .integrity, .performance, .record])
        XCTAssertEqual(Set(Destination.sidebarOrder), Set(Destination.allCases))
    }

    func testSidebarStepMovesByOneAndStopsAtTheEnds() {
        XCTAssertEqual(Destination.overview.step(1), .explore)
        XCTAssertEqual(Destination.explore.step(-1), .overview)
        XCTAssertEqual(Destination.overview.step(-1), .overview)
        XCTAssertEqual(Destination.record.step(1), .record)
        XCTAssertEqual(Destination.duplicates.step(1), .applications, "crossing the section boundary")
    }

    func testShortcutNumbersFollowTheSidebar() {
        XCTAssertEqual(Destination.sidebarOrder.map(\.shortcutNumber), Array(1...8))
    }

    func testCommandPaletteListsDestinationsInSidebarOrder() {
        let destinations = CommandPaletteCatalog.commands(french: false).compactMap { command -> Destination? in
            if case .destination(let destination) = command.target { return destination } else { return nil }
        }
        XCTAssertEqual(destinations, Destination.sidebarOrder)
    }


    func testEveryDestinationHasASerreLedeInBothLanguages() {
        for destination in Destination.allCases {
            for french in [false, true] {
                let lede = ProductCopy.value(for: destination.ledeKey, french: french)
                XCTAssertFalse(lede.isEmpty)
                XCTAssertNotEqual(lede, destination.ledeKey, "\(destination) has no \(french ? "French" : "English") lede")
            }
        }
    }

    func testByteSizesFollowTheAppLanguageNotTheSystemLocale() {
        let french = ProductFormat.bytes(58_540_000_000, french: true)
        let english = ProductFormat.bytes(58_540_000_000, french: false)
        XCTAssertTrue(french.contains("Go") && french.contains(","), french)
        XCTAssertTrue(english.contains("GB") && english.contains("."), english)
    }

    func testSoilShowsOnlyMeasuredConsistentQuantities() throws {
        let soil = try XCTUnwrap(SoilFractions(free: 50, total: 200))
        XCTAssertEqual(soil.used, 0.75, accuracy: 0.0001)
        XCTAssertEqual(soil.free, 0.25, accuracy: 0.0001)
        XCTAssertNil(SoilFractions(free: nil, total: 200), "unknown free space draws no soil")
        XCTAssertNil(SoilFractions(free: 50, total: nil))
        XCTAssertNil(SoilFractions(free: 300, total: 200), "free larger than capacity is not drawn")
        XCTAssertNil(SoilFractions(free: 50, total: 0))
        XCTAssertNil(SoilFractions(free: -1, total: 200))
    }

    func testCleanupStatesAndMoveFailureReasonsExistInBothLanguages() {
        let keys = ["cleanup.rules", "cleanup.expected", "cleanup.expected.help", "cleanup.none.help", "cleanup.denied.retry",
                    "scan.retry", "scan.reading", "scan.finished", "cleanup.selectNone", "cleanup.review",
                    "cleanup.trash", "cleanup.moving", "cleanup.moved", "cleanup.stayed",
                    "action.failure.trash", "action.failure.history", "action.failure.changed", "action.failure.missing",
                    "action.failure.outside", "action.failure.expired", "action.failure.cancelled"]
        for key in keys {
            let english = ProductCopy.value(for: key, french: false)
            let french = ProductCopy.value(for: key, french: true)
            XCTAssertNotEqual(english, key, key)
            XCTAssertNotEqual(french, key, key)
            XCTAssertNotEqual(english, french, key)
        }
        // A file that stays is always said to stay; no reason claims a deletion.
        for key in keys where key.hasPrefix("action.failure.") && key != "action.failure.missing" {
            XCTAssertFalse(ProductCopy.value(for: key, french: false).lowercased().contains("deleted"), key)
        }
    }

    func testScanCountsFollowTheAppLanguage() {
        XCTAssertEqual(ProductFormat.count(18_000, french: false), "18,000")
        XCTAssertTrue(["18 000", "18\u{202F}000", "18\u{00A0}000"].contains(ProductFormat.count(18_000, french: true)))
        XCTAssertEqual(ProductFormat.filesExamined(1, french: true), "fichier examiné")
        XCTAssertEqual(ProductFormat.filesExamined(2, french: true), "fichiers examinés")
        XCTAssertEqual(ProductFormat.filesExamined(1, french: false), "file examined")
    }

    func testItemCountsAgreeInBothLanguages() {
        XCTAssertEqual(ProductFormat.items(0, french: true), "0 élément")
        XCTAssertEqual(ProductFormat.items(1, french: true), "1 élément")
        XCTAssertEqual(ProductFormat.items(3, french: true), "3 éléments")
        XCTAssertEqual(ProductFormat.items(1, french: false), "1 item")
        XCTAssertEqual(ProductFormat.items(0, french: false), "0 items")
        XCTAssertEqual(ProductFormat.frenchPlural(1), "")
        XCTAssertEqual(ProductFormat.frenchPlural(2), "s")
    }

    func testCrashReportRuleNamesBothExtensionsItReads() {
        XCTAssertTrue(ProductCopy.value(for: "cleanup.crashes.help", french: false).contains(".ips"))
        XCTAssertTrue(ProductCopy.value(for: "cleanup.crashes.help", french: true).contains(".ips"))
    }

    func testFirstLaunchStepsExistInBothLanguages() {
        for step in 1...3 {
            for french in [false, true] {
                for part in ["title", "body"] {
                    let key = "onboarding.step\(step).\(part)"
                    XCTAssertNotEqual(ProductCopy.value(for: key, french: french), key)
                }
            }
        }
    }
}

private actor SamplingCounter {
    private var count = 0
    func record() { count += 1 }
    func currentCount() -> Int { count }

}
