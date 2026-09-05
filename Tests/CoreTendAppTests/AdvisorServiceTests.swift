// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
import SafetyCore
import AppDiscovery
import FileRules
@testable import CoreTendApp

private func finding(ruleID: String, logicalSize: Int64 = 1_000, risk: RiskLevel = .low,
                      url: URL = URL(fileURLWithPath: "/tmp/x")) -> ScanFinding {
    ScanFinding(url: url, logicalSize: logicalSize, allocatedSize: nil, modificationDate: nil,
                ruleID: ruleID, category: "Cleanup", explanation: "unused — Advisor supplies its own text",
                confidence: 0.9, risk: risk, preselected: true)
}

@Suite("AdvisorService — Cleanup")
struct AdvisorServiceCleanupTests {
    @Test func lowRiskRuleMapsToLowRisk() {
        let advisor = AdvisorService.advise(ruleID: "user.caches", findings: [finding(ruleID: "user.caches", risk: .low)])
        #expect(advisor.risk == .low)
        #expect(advisor.confidence == .high)
        #expect(advisor.reversibility == .trash)
        #expect(advisor.category == .cleanup)
    }

    @Test func mediumRiskRuleMapsToMediumRisk() {
        let advisor = AdvisorService.advise(
            ruleID: "dev.xcode.devicesupport",
            findings: [finding(ruleID: "dev.xcode.devicesupport", risk: .medium)])
        #expect(advisor.risk == .medium)
    }

    @Test func highRiskRuleMapsToHighRisk() {
        let advisor = AdvisorService.advise(
            ruleID: "user.iosbackups", findings: [finding(ruleID: "user.iosbackups", risk: .high)])
        #expect(advisor.risk == .high)
    }

    @Test func titleComesFromTheSameLocalizedLabelTimelineUses() {
        let advisor = AdvisorService.advise(ruleID: "user.caches", findings: [finding(ruleID: "user.caches")])
        #expect(advisor.title == TimelineCategoryLabel.display(engine: "cleanup", category: "user.caches"))
        #expect(advisor.title == "User caches")
    }

    @Test func everyShippedCleanupRuleHasNonEmptyAdvisorText() {
        // Reads the real shipped rule list — a rule added to
        // UserCleanupRules.all without matching Advisor localized text fails
        // this test automatically, rather than relying on a second,
        // hand-maintained list that could silently drift from the first.
        for rule in UserCleanupRules.all.map(\.id) {
            let advisor = AdvisorService.advise(ruleID: rule, findings: [finding(ruleID: rule)])
            #expect(!advisor.summary.isEmpty, "\(rule) summary")
            #expect(!advisor.reason.isEmpty, "\(rule) reason")
            #expect(!advisor.consequence.isEmpty, "\(rule) consequence")
            #expect(!advisor.summary.hasPrefix("advisor."), "\(rule) summary leaked a raw key")
            #expect(!advisor.reason.hasPrefix("advisor."), "\(rule) reason leaked a raw key")
            #expect(!advisor.consequence.hasPrefix("advisor."), "\(rule) consequence leaked a raw key")
            #expect(advisor.confidence != .uncertain, "\(rule) is a real shipped rule — must not fall into the unknown-rule path")
        }
    }

    @Test func unrecognizedRuleIDFallsBackHonestlyInsteadOfGuessingLowRisk() {
        let advisor = AdvisorService.advise(ruleID: "totally.unknown.rule", findings: [finding(ruleID: "totally.unknown.rule")])
        #expect(advisor.risk == .medium, "an unrecognized rule must not default to low risk")
        #expect(advisor.confidence == .uncertain)
        #expect(advisor.reason == "CoreTend doesn't have specific information about this category.")
    }

    @Test func reclaimableBytesSumsAllFindingsInTheGroup() {
        let findings = [finding(ruleID: "user.logs", logicalSize: 100), finding(ruleID: "user.logs", logicalSize: 250)]
        let advisor = AdvisorService.advise(ruleID: "user.logs", findings: findings)
        #expect(advisor.reclaimableBytes == 350)
    }

    @Test func zeroFindingsIsAZeroByteFindingNotAMissingOne() {
        let advisor = AdvisorService.advise(ruleID: "user.logs", findings: [])
        #expect(advisor.reclaimableBytes == 0)
    }

    @Test func veryLargeReclaimableSizeSurvivesWithoutOverflow() {
        let huge: Int64 = 5_000_000_000_000
        let advisor = AdvisorService.advise(ruleID: "user.iosbackups", findings: [finding(ruleID: "user.iosbackups", logicalSize: huge)])
        #expect(advisor.reclaimableBytes == huge)
    }

    @Test func idIsStableNotRandom() {
        let a = AdvisorService.advise(ruleID: "user.caches", findings: [finding(ruleID: "user.caches")])
        let b = AdvisorService.advise(ruleID: "user.caches", findings: [finding(ruleID: "user.caches", logicalSize: 999)])
        #expect(a.id == b.id, "the id must depend only on the rule, not on the findings")
    }
}

@Suite("AdvisorService — Duplicates")
struct AdvisorServiceDuplicatesTests {
    @Test func validGroupIsExactConfidenceMediumRisk() {
        let group = DuplicateGroup(id: "hash-1", fileSize: 1_000,
                                    urls: [URL(fileURLWithPath: "/a"), URL(fileURLWithPath: "/b")])
        let advisor = AdvisorService.advise(duplicateGroup: group)
        #expect(advisor.confidence == .exact, "content-hash matching is a verified identity, not a guess")
        #expect(advisor.risk == .medium, "choosing which copy to keep is still a real decision")
        #expect(advisor.reversibility == .trash)
        #expect(advisor.category == .duplicates)
    }

    @Test func reclaimableBytesMatchesWastedBytesNotTotalGroupSize() {
        // 3 copies of a 1,000-byte file: 2,000 bytes wasted (all but one copy).
        let group = DuplicateGroup(id: "hash-2", fileSize: 1_000,
                                    urls: [URL(fileURLWithPath: "/a"), URL(fileURLWithPath: "/b"), URL(fileURLWithPath: "/c")])
        let advisor = AdvisorService.advise(duplicateGroup: group)
        #expect(advisor.reclaimableBytes == 2_000)
    }

    @Test func alwaysCarriesACautiousRecommendation() {
        let group = DuplicateGroup(id: "hash-3", fileSize: 10, urls: [URL(fileURLWithPath: "/a"), URL(fileURLWithPath: "/b")])
        let advisor = AdvisorService.advise(duplicateGroup: group)
        #expect(advisor.recommendation != nil)
        #expect(advisor.recommendation?.isEmpty == false)
    }
}

@Suite("AdvisorService — Leftovers")
struct AdvisorServiceLeftoversTests {
    private func item(sizeBytes: Int64 = 500) -> AssociatedItem {
        AssociatedItem(kind: .applicationSupport, url: URL(fileURLWithPath: "/tmp/com.example.retired"), sizeBytes: sizeBytes)
    }

    @Test func exactBundleIDMatchIsHighConfidence() {
        let advisor = AdvisorService.advise(leftover: item(), isAmbiguous: false)
        #expect(advisor.confidence == .high)
        #expect(advisor.risk == .medium)
        #expect(advisor.recommendation == nil, "a non-ambiguous leftover needs no extra caution beyond risk/confidence")
        #expect(advisor.reason.contains("no currently installed app"))
    }

    @Test func ambiguousMatchIsProbableConfidenceWithARecommendation() {
        let advisor = AdvisorService.advise(leftover: item(), isAmbiguous: true)
        #expect(advisor.confidence == .probable)
        #expect(advisor.recommendation != nil)
        #expect(advisor.reason.contains("more than one leftover") || advisor.reason.contains("app family"))
    }

    @Test func neverPromotesAHeuristicToExactConfidence() {
        // Leftovers are always inferred from a folder-name shape, never a
        // live Info.plist read the way Applications' own associated files
        // are — so this mapping must never claim `.exact`.
        #expect(AdvisorService.advise(leftover: item(), isAmbiguous: false).confidence != .exact)
        #expect(AdvisorService.advise(leftover: item(), isAmbiguous: true).confidence != .exact)
    }

    @Test func reclaimableBytesMatchesItemSize() {
        let advisor = AdvisorService.advise(leftover: item(sizeBytes: 12_345), isAmbiguous: false)
        #expect(advisor.reclaimableBytes == 12_345)
    }

    @Test func aggregateSumsBytesAcrossItemsAndSharesTheSameClassificationRules() {
        let items = [item(sizeBytes: 100), item(sizeBytes: 250)]
        let exact = AdvisorService.advise(leftovers: items, isAmbiguous: false)
        #expect(exact.reclaimableBytes == 350)
        #expect(exact.confidence == .high)
        let ambiguous = AdvisorService.advise(leftovers: items, isAmbiguous: true)
        #expect(ambiguous.reclaimableBytes == 350)
        #expect(ambiguous.confidence == .probable)
        #expect(exact.id != ambiguous.id, "the two classifications must never collide on one id")
    }

    @Test func aggregateIDIsStableAcrossDifferentItemSets() {
        let a = AdvisorService.advise(leftovers: [item(sizeBytes: 1)], isAmbiguous: false)
        let b = AdvisorService.advise(leftovers: [item(sizeBytes: 999), item(sizeBytes: 1)], isAmbiguous: false)
        #expect(a.id == b.id, "the aggregate id depends only on the classification, not on which items are in it")
    }
}

@Suite("AdvisorService — Privacy")
struct AdvisorServicePrivacyTests {
    private func profile(browser: String = "Chrome", cacheBytes: Int64 = 4_000) -> BrowserProfile {
        BrowserProfile(id: "\(browser)-default", browser: browser, bundleID: "com.example.\(browser)",
                       profileName: "Default", cacheURLs: [], cacheBytes: cacheBytes,
                       historyBytes: 999, cookieBytes: 999)
    }

    @Test func cacheOnlyIsLowRiskHighConfidence() {
        let advisor = AdvisorService.advise(browserProfile: profile())
        #expect(advisor.risk == .low)
        #expect(advisor.confidence == .high)
        #expect(advisor.reversibility == .trash)
        #expect(advisor.category == .privacy)
    }

    @Test func reclaimableBytesIsCacheOnlyNeverHistoryOrCookies() {
        let advisor = AdvisorService.advise(browserProfile: profile(cacheBytes: 4_000))
        #expect(advisor.reclaimableBytes == 4_000, "historyBytes/cookieBytes (999 each) must never leak into the reclaimable figure")
    }

    @Test func statesExactlyWhatIsNotRemovedAndNothingElse() {
        let advisor = AdvisorService.advise(browserProfile: profile())
        #expect(advisor.notRemoved == ["Browsing history", "Cookies"])
        #expect(!advisor.notRemoved.contains { $0.localizedCaseInsensitiveContains("password") },
                "this product doesn't track a passwords category — never claim protection for it")
    }

    @Test func titleIsTheBrowserNameVerbatimNotATranslatedProperNoun() {
        let advisor = AdvisorService.advise(browserProfile: profile(browser: "Firefox"))
        #expect(advisor.title == "Firefox")
    }

    @Test func aggregateSumsCacheBytesAcrossEveryProfileWithAGenericTitle() {
        let profiles = [profile(browser: "Chrome", cacheBytes: 1_000), profile(browser: "Safari", cacheBytes: 2_000)]
        let advisor = AdvisorService.advise(browserProfiles: profiles)
        #expect(advisor.reclaimableBytes == 3_000)
        #expect(advisor.title != "Chrome" && advisor.title != "Safari", "the aggregate names no single browser")
        #expect(!advisor.title.isEmpty)
        #expect(advisor.risk == .low)
        #expect(advisor.confidence == .high)
        #expect(advisor.notRemoved == ["Browsing history", "Cookies"])
    }

    @Test func aggregateWithNoProfilesIsAZeroByteFinding() {
        let advisor = AdvisorService.advise(browserProfiles: [])
        #expect(advisor.reclaimableBytes == 0)
    }
}

@Suite("AdvisorService — safety")
struct AdvisorServiceSafetyTests {
    @Test func adviseNeverTouchesTheFilesystem() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("x".utf8).write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }
        _ = AdvisorService.advise(ruleID: "user.caches", findings: [finding(ruleID: "user.caches", url: path)])
        #expect(FileManager.default.fileExists(atPath: path.path), "AdvisorService must never delete or move a file")
    }

    /// Restore Center now exists, but a *scan-result* Advisor finding is
    /// produced before anything has been Trashed — there is no manifest yet,
    /// so it must never claim `.restorableByCoreTend`. That reversibility is
    /// derived from a live restore manifest by `RestoreReversibility.of(_:)`,
    /// proven separately in `RestoreAdvisorReversibilityTests`.
    @Test func scanResultFindingsNeverPreemptivelyClaimRestorability() {
        let cleanup = AdvisorService.advise(ruleID: "user.caches", findings: [finding(ruleID: "user.caches")])
        let duplicate = AdvisorService.advise(duplicateGroup: DuplicateGroup(
            id: "h", fileSize: 1, urls: [URL(fileURLWithPath: "/a"), URL(fileURLWithPath: "/b")]))
        let leftover = AdvisorService.advise(
            leftover: AssociatedItem(kind: .caches, url: URL(fileURLWithPath: "/x"), sizeBytes: 1), isAmbiguous: false)
        let privacy = AdvisorService.advise(browserProfile: BrowserProfile(
            id: "p", browser: "Safari", bundleID: "com.apple.Safari", profileName: "Default",
            cacheURLs: [], cacheBytes: 1, historyBytes: 1, cookieBytes: 1))
        for advisor in [cleanup, duplicate, leftover, privacy] {
            #expect(advisor.reversibility == .trash, "every currently-wired engine goes through SafetyCenter's Trash path")
            #expect(advisor.reversibility != .restorableByCoreTend)
            #expect(advisor.reversibility != .irreversible)
            #expect(advisor.reversibility != .partial)
        }
    }
}

@Suite("AdvisorService — localization")
struct AdvisorServiceLocalizationTests {
    @Test func displayLabelsAreNeverRawKeys() {
        for risk: RiskLevel in [.low, .medium, .high] {
            #expect(!AdvisorDisplay.label(risk).hasPrefix("advisor."))
        }
        for confidence in AdvisorConfidence.allCases {
            #expect(!AdvisorDisplay.label(confidence).hasPrefix("advisor."))
        }
        for reversibility in AdvisorReversibility.allCases {
            #expect(!AdvisorDisplay.label(reversibility).hasPrefix("advisor."))
        }
    }
}
