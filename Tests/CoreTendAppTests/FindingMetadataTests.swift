// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import SafetyCore
@testable import CoreTendApp

@Suite("Finding evidence shown under a scan result")
struct FindingMetadataTests {

    // MARK: - Risk labels

    @Test("every risk level has a localized label, and none leaks the raw enum")
    func riskLabelsAreLocalized() {
        for risk in [RiskLevel.low, .medium, .high] {
            let label = FindingMetadata.riskLabel(risk)
            #expect(!label.isEmpty)
            // The Safety Log used to interpolate the enum directly, printing
            // "low"/"medium"/"high" in a French UI. A label equal to the raw
            // value means the string table lost the key.
            #expect(label != risk.rawValue)
        }
    }

    @Test("risk levels read differently from one another")
    func riskLabelsAreDistinct() {
        let labels = Set([RiskLevel.low, .medium, .high].map(FindingMetadata.riskLabel))
        #expect(labels.count == 3)
    }

    @Test("a known raw value resolves to the same label as the enum")
    func rawRiskMatchesEnum() {
        #expect(FindingMetadata.riskLabel(rawValue: "medium") == FindingMetadata.riskLabel(.medium))
    }

    @Test("an unknown raw value is shown rather than swallowed")
    func unknownRawRiskIsPreserved() {
        // Audit records store the raw string. After a schema change an
        // unrecognised level is possible, and a log that quietly drops a value
        // it holds is worse than one showing an unfamiliar word.
        #expect(FindingMetadata.riskLabel(rawValue: "catastrophic") == "catastrophic")
    }

    // MARK: - Age

    @Test("a missing modification date produces no age, not a placeholder")
    func noDateNoAge() {
        #expect(FindingMetadata.ageDescription(for: nil) == nil)
    }

    @Test("a past date produces a non-empty relative age")
    func pastDateHasAge() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let age = FindingMetadata.ageDescription(for: now.addingTimeInterval(-60 * 60 * 24 * 90), now: now)
        #expect(age?.isEmpty == false)
    }

    @Test("a future modification date is clamped to the present, never rendered as the future")
    func futureDateIsClamped() {
        // Real causes: a wrong clock, a restored backup, an archive that
        // preserved timestamps. "in 3 days" next to a file would read as a bug.
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let future = FindingMetadata.ageDescription(for: now.addingTimeInterval(60 * 60 * 24 * 3), now: now)
        let present = FindingMetadata.ageDescription(for: now, now: now)
        #expect(future == present)
    }

    @Test("an older file reads differently from a recent one")
    func ageDistinguishesOldFromNew() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = FindingMetadata.ageDescription(for: now.addingTimeInterval(-60 * 60 * 24 * 400), now: now)
        let recent = FindingMetadata.ageDescription(for: now.addingTimeInterval(-60 * 60), now: now)
        #expect(old != recent)
    }

    @Test("the age follows the in-app language, not the system locale")
    func ageUsesAppLanguage() {
        // Foundation formatters default to the system locale. The first version
        // of this code did, and rendered "modifié 1 month ago" in a French UI —
        // English leaking into a translated interface, which is exactly the
        // defect this type exists to remove. Only looking at the running app
        // caught it, so the regression is pinned here.
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = now.addingTimeInterval(-60 * 60 * 24 * 40)
        let english = FindingMetadata.ageDescription(for: old, now: now, language: .en)
        let french = FindingMetadata.ageDescription(for: old, now: now, language: .fr)
        #expect(english != nil)
        #expect(french != nil)
        #expect(english != french)
    }

    @Test("the whole summary is translated, separator included")
    func summaryIsFullyLocalized() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = now.addingTimeInterval(-60 * 60 * 24 * 40)
        let english = FindingMetadata.summary(risk: .low, modificationDate: old, now: now, language: .en)
        let french = FindingMetadata.summary(risk: .low, modificationDate: old, now: now, language: .fr)
        #expect(english != french)
        // "ago" appearing in the French line means the formatter fell back to
        // the system locale again.
        #expect(french?.contains("ago") == false)
    }

    // MARK: - Summary line

    @Test("the summary always carries the risk, even with no date")
    func summaryWithoutDate() {
        let summary = FindingMetadata.summary(risk: .medium, modificationDate: nil)
        #expect(summary?.contains(FindingMetadata.riskLabel(.medium)) == true)
    }

    @Test("the summary carries both risk and age when a date exists")
    func summaryWithDate() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let summary = FindingMetadata.summary(
            risk: .low, modificationDate: now.addingTimeInterval(-60 * 60 * 24 * 30), now: now)
        #expect(summary?.contains(FindingMetadata.riskLabel(.low)) == true)
        #expect(summary?.contains("·") == true)
    }

    @Test("the summary never ends with a dangling separator")
    func summaryHasNoTrailingSeparator() {
        for date in [nil, Date(timeIntervalSince1970: 1_700_000_000)] as [Date?] {
            let summary = FindingMetadata.summary(risk: .high, modificationDate: date) ?? ""
            #expect(!summary.hasSuffix("·"))
            #expect(!summary.hasSuffix(" "))
        }
    }

    @Test("risk alone never renders as a bare separator line")
    func summaryIsNeverJustPunctuation() {
        let summary = FindingMetadata.summary(risk: .low, modificationDate: nil) ?? ""
        #expect(summary.trimmingCharacters(in: .whitespacesAndNewlines).count > 1)
    }
}
