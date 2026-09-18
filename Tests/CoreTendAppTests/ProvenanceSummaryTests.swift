// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import IntegrityCore
@testable import CoreTendApp

@Suite("Download provenance reports what macOS actually recorded")
struct ProvenanceSummaryTests {

    private func item(
        source: String? = nil, origin: String? = nil,
        agent: String? = nil, date: Date? = nil
    ) -> DownloadProvenance {
        DownloadProvenance(
            path: "/tmp/file.pdf", name: "file.pdf", isQuarantined: true,
            sourceURL: source, originURL: origin, agentName: agent, downloadedAt: date)
    }

    private let when = Date(timeIntervalSince1970: 1_770_040_980)

    // MARK: - The bug this file exists for

    @Test("a file with only an agent and a date is not called unknown")
    func agentAndDateIsProvenance() {
        // The shape of every quarantined file measured on a real Mac: 280 of
        // 280 in ~/Downloads and ~/Desktop had no dataURL, and all 280 had an
        // agent and a timestamp. The old check asked only whether sourceURL
        // was nil, so the list said "no provenance recorded" for all of them.
        let file = item(agent: "Safari", date: when)
        #expect(ProvenanceSummary.isUnknown(file) == false)
        #expect(ProvenanceSummary.acquisition(for: file, language: .en) != nil)
    }

    @Test("unknown means macOS recorded nothing, not that one key was missing")
    func unknownRequiresEverythingMissing() {
        #expect(ProvenanceSummary.isUnknown(item()))
        for known in [item(source: "https://example.com/a.pdf"),
                      item(origin: "https://example.com/page"),
                      item(agent: "Chrome"),
                      item(date: when)] {
            #expect(ProvenanceSummary.isUnknown(known) == false)
        }
    }

    // MARK: - Location

    @Test("the direct URL is preferred when macOS kept it")
    func sourcePreferredOverOrigin() {
        let file = item(source: "https://example.com/a.pdf", origin: "https://example.com/page")
        #expect(ProvenanceSummary.location(for: file) == "https://example.com/a.pdf")
    }

    @Test("the referring page is used when the direct URL is absent")
    func originUsedAsFallback() {
        // Better than showing nothing: the page a download came from is real
        // provenance, and it is what the old code threw away.
        let file = item(origin: "https://example.com/page")
        #expect(ProvenanceSummary.location(for: file) == "https://example.com/page")
    }

    @Test("no location is reported when neither URL was recorded")
    func noLocationWhenNeitherExists() {
        #expect(ProvenanceSummary.location(for: item(agent: "Safari")) == nil)
    }

    // MARK: - Acquisition line

    @Test("agent and date are reported together when both exist")
    func agentWithDate() {
        let line = ProvenanceSummary.acquisition(for: item(agent: "Safari", date: when), language: .en)
        #expect(line?.contains("Safari") == true)
        #expect(line?.contains("2026") == true)
    }

    @Test("an agent alone is still worth saying")
    func agentAlone() {
        let line = ProvenanceSummary.acquisition(for: item(agent: "Chrome"), language: .en)
        #expect(line?.contains("Chrome") == true)
    }

    @Test("a date alone is still worth saying")
    func dateAlone() {
        let line = ProvenanceSummary.acquisition(for: item(date: when), language: .en)
        #expect(line?.isEmpty == false)
    }

    @Test("nothing recorded produces no line rather than an empty one")
    func neitherProducesNil() {
        #expect(ProvenanceSummary.acquisition(for: item(source: "https://x/y"), language: .en) == nil)
    }

    @Test("the acquisition line follows the in-app language")
    func acquisitionIsLocalized() {
        let file = item(agent: "Safari", date: when)
        let english = ProvenanceSummary.acquisition(for: file, language: .en)
        let french = ProvenanceSummary.acquisition(for: file, language: .fr)
        #expect(english != french)
        // The date inside it must be translated too, not just the wrapper.
        #expect(french?.contains("Feb") == false)
    }
}
