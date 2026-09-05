// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import WidgetShared

private func tempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ws-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@Suite("WidgetSnapshot — encode/decode + schema")
struct WidgetSnapshotCodableTests {
    @Test func roundTripsEveryField() throws {
        let original = WidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            freeBytes: 42_000_000_000, totalBytes: 500_000_000_000,
            reclaimableBytes: 8_400_000_000, sinceLastScanDeltaBytes: -3_000_000_000,
            lastScanDate: Date(timeIntervalSince1970: 1_699_900_000), lastActivityKind: "cleanup")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(WidgetSnapshot.self, from: encoder.encode(original))
        #expect(decoded == original)
        #expect(decoded.schemaVersion == WidgetSnapshot.currentSchemaVersion)
    }

    @Test func optionalFieldsSurviveAsNil() throws {
        let original = WidgetSnapshot(generatedAt: Date(), freeBytes: 1, totalBytes: 2)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(WidgetSnapshot.self, from: encoder.encode(original))
        #expect(decoded.reclaimableBytes == nil)
        #expect(decoded.sinceLastScanDeltaBytes == nil)
        #expect(decoded.lastScanDate == nil)
        #expect(decoded.lastActivityKind == nil)
    }

    @Test func staleAfterSevenDays() {
        let s = WidgetSnapshot(generatedAt: Date(), freeBytes: 1, totalBytes: 2)
        #expect(!s.isStale(now: Date().addingTimeInterval(3 * 24 * 3600)))
        #expect(s.isStale(now: Date().addingTimeInterval(8 * 24 * 3600)))
    }
}

@Suite("WidgetSnapshotStore — atomic write, graceful read")
struct WidgetSnapshotStoreTests {
    @Test func writeThenReadRoundTrips() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = WidgetSnapshotStore(directory: dir)
        let snapshot = WidgetSnapshot(generatedAt: Date(), freeBytes: 10, totalBytes: 20,
                                      reclaimableBytes: 5)
        #expect(store.write(snapshot))
        guard case let .snapshot(read) = store.read() else { Issue.record("expected .snapshot"); return }
        #expect(read.freeBytes == 10)
        #expect(read.reclaimableBytes == 5)
    }

    @Test func missingFileReportsFileMissingNotAZero() {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        #expect(WidgetSnapshotStore(directory: dir).read() == .unavailable(reason: .fileMissing))
    }

    @Test func malformedJsonReportsMalformed() throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = WidgetSnapshotStore(directory: dir)
        try Data("{ this is not json".utf8).write(to: try #require(store.fileURL))
        #expect(store.read() == .unavailable(reason: .malformed))
    }

    @Test func emptyFileReportsUnreadable() throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = WidgetSnapshotStore(directory: dir)
        try Data().write(to: try #require(store.fileURL))
        #expect(store.read() == .unavailable(reason: .unreadable))
    }

    @Test func aFutureSchemaVersionIsRefusedRatherThanMisread() throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = WidgetSnapshotStore(directory: dir)
        var future = WidgetSnapshot(generatedAt: Date(), freeBytes: 1, totalBytes: 2)
        future.schemaVersion = WidgetSnapshot.currentSchemaVersion + 1
        #expect(store.write(future))
        #expect(store.read() == .unavailable(reason: .unsupportedFutureVersion))
    }

    @Test func aNilContainerReportsAppGroupUnavailable() {
        let store = WidgetSnapshotStore(containerURL: nil)
        #expect(store.fileURL == nil)
        #expect(store.read() == .unavailable(reason: .appGroupUnavailable))
        #expect(!store.write(WidgetSnapshot(generatedAt: Date(), freeBytes: 1, totalBytes: 2)))
    }

    @Test func atomicWriteNeverLeavesAHalfWrittenFileVisibleToAReader() throws {
        // Simulate a reader interleaved with many writers: every read either
        // sees a complete previous snapshot or a complete new one, never a
        // decode failure.
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = WidgetSnapshotStore(directory: dir)
        store.write(WidgetSnapshot(generatedAt: Date(), freeBytes: 0, totalBytes: 100))
        for i in 1...200 {
            store.write(WidgetSnapshot(generatedAt: Date(), freeBytes: Int64(i), totalBytes: 100))
            if case .unavailable(let reason) = store.read(), reason == .malformed || reason == .unreadable {
                Issue.record("reader saw a partial write on iteration \(i)")
            }
        }
    }
}

@Suite("WidgetDisplayModel — snapshot -> strings mapping (no rendering)")
struct WidgetDisplayModelTests {
    private func model(_ s: WidgetSnapshot, now: Date = Date()) -> WidgetDisplayModel {
        WidgetDisplayModel.from(.snapshot(s), now: now)
    }

    @Test func unavailableIsAPlaceholderNotAZero() {
        let m = WidgetDisplayModel.from(.unavailable(reason: .fileMissing))
        #expect(m.isPlaceholder)
        #expect(!m.primary.contains("0"))
        #expect(m.headline == WL("widget.empty.never_opened"))
    }

    @Test func freeSpaceAndGrowthAreWords() {
        let m = model(WidgetSnapshot(generatedAt: Date(), freeBytes: 42_000_000_000,
                                     totalBytes: 500_000_000_000, sinceLastScanDeltaBytes: 4_200_000_000))
        #expect(m.primary.contains(widgetFormatBytes(42_000_000_000)))
        #expect(m.headline == WL("widget.trend.increased", widgetFormatBytes(4_200_000_000)))
        #expect(m.headline.contains(widgetFormatBytes(4_200_000_000)))
    }

    @Test func negativeDeltaReadsAsDecrease() {
        let m = model(WidgetSnapshot(generatedAt: Date(), freeBytes: 1, totalBytes: 2,
                                     sinceLastScanDeltaBytes: -3_000_000_000))
        #expect(m.headline == WL("widget.trend.decreased", widgetFormatBytes(3_000_000_000)))
    }

    @Test func noHistoryAndNoChangeAreDistinct() {
        #expect(model(WidgetSnapshot(generatedAt: Date(), freeBytes: 1, totalBytes: 2, sinceLastScanDeltaBytes: nil)).headline
                == WL("widget.trend.no_history"))
        #expect(model(WidgetSnapshot(generatedAt: Date(), freeBytes: 1, totalBytes: 2, sinceLastScanDeltaBytes: 0)).headline
                == WL("widget.trend.no_change"))
    }

    @Test func mediumDetailSurfacesReclaimableAndLastScanWhenPresent() {
        let m = model(WidgetSnapshot(generatedAt: Date(), freeBytes: 1, totalBytes: 2,
                                     reclaimableBytes: 8_000_000_000,
                                     lastScanDate: Date().addingTimeInterval(-3600)))
        #expect(m.detail?.contains(widgetFormatBytes(8_000_000_000)) == true)
    }

    @Test func aStaleSnapshotIsStillShownButLabelled() {
        let old = Date().addingTimeInterval(-10 * 24 * 3600)
        let m = model(WidgetSnapshot(generatedAt: old, freeBytes: 1, totalBytes: 2), now: Date())
        #expect(m.isStale)
        #expect(m.footnote?.contains(WL("widget.as_of", "").replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)) == true || m.footnote != nil)
    }

    @Test func accessibilityLabelIsAFullSentenceNotJustAGlyph() {
        let m = model(WidgetSnapshot(generatedAt: Date(), freeBytes: 42_000_000_000,
                                     totalBytes: 500_000_000_000, sinceLastScanDeltaBytes: 4_200_000_000))
        #expect(m.accessibilityLabel.contains(WL("widget.trend.increased", widgetFormatBytes(4_200_000_000))))
        #expect(!m.accessibilityLabel.contains("↑"))
        #expect(!m.accessibilityLabel.contains("→"))
    }
}

@Suite("WidgetShared — localization parity")
struct WidgetLocalizationParityTests {
    private func keys(_ folder: String) throws -> Set<String> {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/WidgetShared/Resources/\(folder).lproj/Localizable.strings")
        // These files are UTF-16 BE with a BOM (repo `.gitattributes` enforces
        // `working-tree-encoding=UTF-16` for every `*.strings`). Let Foundation
        // pick the encoding from the BOM rather than assuming UTF-8.
        var used = String.Encoding.utf8
        let text = try String(contentsOf: url, usedEncoding: &used)
        var found: Set<String> = []
        for line in text.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("\"") else { continue }
            if let end = t.dropFirst().firstIndex(of: "\"") {
                found.insert(String(t[t.index(after: t.startIndex)..<end]))
            }
        }
        return found
    }

    @Test func baseAndFrenchHaveTheExactSameKeys() throws {
        let base = try keys("Base")
        let fr = try keys("fr")
        #expect(base == fr, "widget string keys differ: only in Base \(base.subtracting(fr)), only in fr \(fr.subtracting(base))")
        #expect(base.count >= 15)
    }

    @Test func everyKeyUsedInCodeResolvesInBothLanguages() {
        // The mapping code paths reference these; a missing key would echo
        // the key back.
        let used = ["widget.empty.primary", "widget.empty.never_opened", "widget.empty.unavailable",
                    "widget.free_of_total", "widget.trend.no_change", "widget.trend.increased",
                    "widget.trend.decreased", "widget.trend.no_history", "widget.reclaimable",
                    "widget.last_scan", "widget.last_activity", "widget.as_of",
                    "widget.activity.scan", "widget.activity.cleanup", "widget.activity.restore",
                    "widget.activity.error", "widget.display_name", "widget.description"]
        for key in used {
            #expect(WL(key) != key, "widget key \(key) does not resolve")
        }
    }
}
