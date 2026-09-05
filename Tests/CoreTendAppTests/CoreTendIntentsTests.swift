// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import AppIntents
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import DesignSystem
@testable import CoreTendApp


@Suite("CoreTendIntentText — service-output → string mapping")
struct CoreTendIntentTextTests {
    @Test func freeSpaceFormatsBothNumbers() {
        let text = CoreTendIntentText.freeSpace(freeBytes: 12_000_000_000, totalBytes: 500_000_000_000)
        #expect(text.contains(mcFormatBytes(12_000_000_000)))
        #expect(text.contains(mcFormatBytes(500_000_000_000)))
    }

    @Test func summaryHandlesNoHistoryNoChangeGrewAndShrank() {
        #expect(CoreTendIntentText.summary(freeBytes: 1, deltaBytes: nil, lastScan: nil)
            .contains(L("appintent.summary.no_history")))
        #expect(CoreTendIntentText.summary(freeBytes: 1, deltaBytes: 0, lastScan: nil)
            .contains(L("appintent.summary.no_change")))
        #expect(CoreTendIntentText.summary(freeBytes: 1, deltaBytes: 5_000_000_000, lastScan: nil)
            .contains(mcFormatBytes(5_000_000_000)))
        let shrank = CoreTendIntentText.summary(freeBytes: 1, deltaBytes: -3_000_000_000, lastScan: nil)
        #expect(shrank.contains(mcFormatBytes(3_000_000_000)))
        #expect(shrank == CoreTendIntentText.summary(freeBytes: 1, deltaBytes: -3_000_000_000, lastScan: nil))
    }

    @Test func storageChangeMissingHistoryIsExplicit() {
        #expect(CoreTendIntentText.storageChange(deltaBytes: nil, topIncreaseBytes: nil)
            == L("appintent.change.no_history"))
        #expect(CoreTendIntentText.storageChange(deltaBytes: 0, topIncreaseBytes: nil)
            == L("appintent.change.none"))
    }

    @Test func storageChangeAddsTopCategoryOnlyForAnIncrease() {
        let up = CoreTendIntentText.storageChange(deltaBytes: 4_000_000_000, topIncreaseBytes: 3_000_000_000)
        #expect(up.contains(L("appintent.change.top_category", mcFormatBytes(3_000_000_000))))
        let down = CoreTendIntentText.storageChange(deltaBytes: -4_000_000_000, topIncreaseBytes: 3_000_000_000)
        #expect(!down.contains(L("appintent.change.top_category", mcFormatBytes(3_000_000_000))))
    }

    @Test func imageMetadataStatusMapping() {
        #expect(CoreTendIntentText.imageMetadata(status: .inspected, presentCategories: [])
            == L("appintent.imagemeta.none"))
        #expect(CoreTendIntentText.imageMetadata(status: .inspected, presentCategories: ["Location / GPS"])
            .contains("Location / GPS"))
        #expect(CoreTendIntentText.imageMetadata(status: .fileMissing, presentCategories: [])
            == L("appintent.imagemeta.missing"))
        #expect(CoreTendIntentText.imageMetadata(status: .unsupported(detail: "x"), presentCategories: [])
            == L("appintent.imagemeta.unsupported"))
    }

    @Test func integritySummaryIncludesCountsAndTier() {
        let text = CoreTendIntentText.integrity(provenanceCount: 12, quarantinedCount: 3,
                                                loginItemCount: 5, ownTierRawValue: "appleSigned")
        #expect(text.contains("12"))
        #expect(text.contains(L("appintent.integrity.tier.appleSigned")))
    }
}

@Suite("CoreTendModuleAppEnum — every case maps to a reachable module")
struct CoreTendModuleAppEnumTests {
    @Test func mappingIsTotalAndReachable() {
        for module in CoreTendModuleAppEnum.allCases {
            let id = module.moduleID
            #expect(SidebarGroup.visibleModules.contains(id), "\(module) → \(id) is not in the sidebar")
        }
        #expect(CoreTendModuleAppEnum.caseDisplayRepresentations.count == CoreTendModuleAppEnum.allCases.count)
    }
}

@Suite("OpenCoreTendModuleIntent — routes through the shared AppRouter")
@MainActor
struct OpenModuleIntentTests {
    @Test func performBuffersARouteForTheChosenModule() async throws {
        AppRouter.shared.resetForTesting()
        let intent = OpenCoreTendModuleIntent()
        intent.module = .recoveryPlan
        _ = try await intent.perform()
        #expect(AppRouter.shared.pendingRoute == .module(.recoveryPlan))
        AppRouter.shared.resetForTesting()
    }
}

@Suite("InspectImageMetadataIntent — reuses Privacy Lab, keeps no path")
struct InspectImageMetadataIntentTests {
    private func jpeg(_ properties: [CFString: Any]) throws -> URL {
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let image = ctx.makeImage()!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ii-\(UUID().uuidString).jpg")
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))
        return url
    }

    @Test func reportsPresentCategoriesForARealImage() async throws {
        let url = try jpeg([kCGImagePropertyGPSDictionary: [
            kCGImagePropertyGPSLatitude: 37.77, kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 122.41, kCGImagePropertyGPSLongitudeRef: "W",
        ]])
        defer { try? FileManager.default.removeItem(at: url) }
        let intent = InspectImageMetadataIntent()
        intent.image = IntentFile(fileURL: url, filename: url.lastPathComponent, type: .jpeg)
        let result = try await intent.perform()
        #expect(result.value?.contains(PrivacyLabCatalog.title(for: .location)) == true)
    }

    @Test func reportsCleanlyWhenTheFileIsGone() async throws {
        let url = try jpeg([:])
        try FileManager.default.removeItem(at: url)
        let intent = InspectImageMetadataIntent()
        intent.image = IntentFile(fileURL: url, filename: url.lastPathComponent, type: .jpeg)
        let result = try await intent.perform()
        #expect(result.value == L("appintent.imagemeta.missing"))
    }

    @Test func theIntentSourceContainsNoPersistenceCall() throws {
        let raw = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/CoreTendApp/CoreTendIntents.swift"), encoding: .utf8)
        // Strip `//` comments so the intent's own "never stored" prose does
        // not trip the check, then isolate the image-metadata intent.
        let code = raw.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            if let r = line.range(of: "//") { return String(line[line.startIndex..<r.lowerBound]) }
            return String(line)
        }.joined(separator: "\n")
        let section = code.components(separatedBy: "struct InspectImageMetadataIntent").last ?? ""
        let imageSection = section.components(separatedBy: "enum CoreTendModuleAppEnum").first ?? ""
        for forbidden in ["AppEnvironment.shared.store", "setSetting", "recordActivity",
                          "recordTimelineSnapshot", "UserDefaults", "recordRestoreManifest"] {
            #expect(!imageSection.contains(forbidden),
                    "InspectImageMetadataIntent must not reference \(forbidden)")
        }
    }
}

@Suite("Read-only data intents — smoke")
struct DataIntentSmokeTests {
    @Test func freeDiskSpaceReturnsARealNonZeroValue() async throws {
        let result = try await GetFreeDiskSpaceIntent().perform()
        #expect((result.value ?? 0) > 0)
    }
}
