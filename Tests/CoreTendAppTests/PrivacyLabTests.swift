// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import CoreTendApp
@testable import SystemMetrics

private func inspection(_ status: ImageMetadataInspection.Status,
                        findings: [MetadataFinding] = [],
                        location: PreciseLocation? = nil) -> ImageMetadataInspection {
    ImageMetadataInspection(status: status, formatIdentifier: "public.jpeg",
                            presentMetadataBlocks: [], findings: findings, preciseLocation: location)
}

private func allNotDetected() -> [MetadataFinding] {
    ImageMetadataCategory.orderedForDisplay.map { MetadataFinding(category: $0, field: .init(presence: .notDetected)) }
}

@Suite("PrivacyLabSummary — honest, never a score")
struct PrivacyLabSummaryTests {
    @Test func inspectedWithNoSupportedFieldIsNotACleanVerdict() {
        let summary = PrivacyLabSummary(inspection(.inspected, findings: allNotDetected()))
        #expect(summary == .noSupportedMetadataDetected(incompleteCount: 0))
    }

    @Test func inspectedWithPresentFieldsCountsThem() {
        var findings = allNotDetected()
        findings[0] = MetadataFinding(category: .location, field: .init(presence: .present))
        findings[2] = MetadataFinding(category: .cameraMake, field: .init(presence: .present, displayValue: "X"))
        let summary = PrivacyLabSummary(inspection(.inspected, findings: findings))
        #expect(summary == .metadataPresent(count: 2, incompleteCount: 0))
    }

    @Test func unavailableCategoriesAreCountedSeparatelyFromPresentOnes() {
        var findings = allNotDetected()
        findings[0] = MetadataFinding(category: .location, field: .init(presence: .present))
        findings[1] = MetadataFinding(category: .captureDate, field: .unavailable("x"))
        let summary = PrivacyLabSummary(inspection(.inspected, findings: findings))
        #expect(summary == .metadataPresent(count: 1, incompleteCount: 1))
    }

    @Test func failureStatusesMapToCannotInspectWithTheRightHeadline() {
        #expect(PrivacyLabSummary(inspection(.fileMissing))
                == .cannotInspect(headlineKey: "privacylab.status.file_missing"))
        #expect(PrivacyLabSummary(inspection(.unreadable(reason: "x")))
                == .cannotInspect(headlineKey: "privacylab.status.unreadable"))
        #expect(PrivacyLabSummary(inspection(.unsupported(detail: "x")))
                == .cannotInspect(headlineKey: "privacylab.status.unsupported"))
    }
}

@Suite("PrivacyLabViewModel — async correctness")
@MainActor
struct PrivacyLabViewModelTests {
    private let slow = URL(fileURLWithPath: "/private/tmp/privacy-lab-A.jpg")
    private let fast = URL(fileURLWithPath: "/private/tmp/privacy-lab-B.jpg")

    private func racingInspector(slowDelayMS: Int) -> ImageMetadataInspecting {
        let slowURL = slow
        return { url in
            if url == slowURL {
                try? await Task.sleep(for: .milliseconds(slowDelayMS))
                return inspection(.unreadable(reason: "stale"), findings: [])
                    .withFormat("STALE")
            }
            return inspection(.inspected, findings: []).withFormat("FRESH")
        }
    }

    @Test func aSlowerEarlierInspectionNeverOverwritesANewerSelection() async {
        let model = PrivacyLabViewModel(inspector: racingInspector(slowDelayMS: 200))
        model.inspect(url: slow)
        model.inspect(url: fast)
        try? await Task.sleep(for: .milliseconds(450))
        #expect(model.phase == .result)
        #expect(model.inspection?.formatIdentifier == "FRESH")
        #expect(model.displayName == "privacy-lab-B.jpg")
    }

    @Test func clearDiscardsAnInFlightInspection() async {
        let model = PrivacyLabViewModel(inspector: racingInspector(slowDelayMS: 200))
        model.inspect(url: slow)
        #expect(model.phase == .inspecting)
        model.clear()
        try? await Task.sleep(for: .milliseconds(350))
        #expect(model.phase == .empty)
        #expect(model.inspection == nil)
        #expect(model.displayName == nil)
    }

    @Test func clearResetsTheOptInCoordinateDisclosure() async {
        let model = PrivacyLabViewModel(inspector: { _ in
            inspection(.inspected, findings: [], location: PreciseLocation(latitude: 1, longitude: 2))
        })
        model.inspect(url: fast)
        try? await Task.sleep(for: .milliseconds(100))
        model.revealsPreciseLocation = true
        model.clear()
        #expect(model.revealsPreciseLocation == false)
    }

    @Test func aFreshSelectionClearsThePreviousResultImmediately() async {
        let model = PrivacyLabViewModel(inspector: racingInspector(slowDelayMS: 120))
        model.inspect(url: fast)
        try? await Task.sleep(for: .milliseconds(80))
        #expect(model.inspection != nil)
        model.inspect(url: slow)
        #expect(model.inspection == nil, "the stale result must not linger while the new one loads")
        #expect(model.phase == .inspecting)
    }
}

private extension ImageMetadataInspection {
    func withFormat(_ id: String) -> ImageMetadataInspection {
        ImageMetadataInspection(status: status, formatIdentifier: id,
                                presentMetadataBlocks: presentMetadataBlocks,
                                findings: findings, preciseLocation: preciseLocation)
    }
}
