import Foundation
import XCTest
import CSQLite
@testable import Persistence

final class PersistenceTests: XCTestCase {
    func testStoreCreatesVersionedSchemaOnlyAtInjectedURL() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-store-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = root.appendingPathComponent("fixture.sqlite")
        let store = try SQLiteStore(url: db)
        try await store.migrate()
        XCTAssertTrue(FileManager.default.fileExists(atPath: db.path))
        let version = try await store.schemaVersion()
        XCTAssertEqual(version, 2)
    }

    func testAppendAndQueryEventsInTimestampOrder() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-store-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SQLiteStore(url: root.appendingPathComponent("fixture.sqlite"))
        try await store.migrate()
        try await store.append(ActivityEvent(id: UUID(), occurredAt: Date(timeIntervalSince1970: 20), kind: .failed, detail: "trash failed"))
        try await store.append(ActivityEvent(id: UUID(), occurredAt: Date(timeIntervalSince1970: 10), kind: .proposed, detail: "candidate"))
        let events = try await store.events()
        XCTAssertEqual(events.map(\.kind), [.proposed, .failed])
        XCTAssertEqual(events.first?.detail, "candidate")
    }

    func testRepeatedMigrationIsIdempotent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-store-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SQLiteStore(url: root.appendingPathComponent("fixture.sqlite"))
        try await store.migrate()
        try await store.append(ActivityEvent(id: UUID(), occurredAt: .now, kind: .cancelled, detail: "cancelled"))
        try await store.migrate()
        let events = try await store.events()
        XCTAssertEqual(events.count, 1)
    }

    func testReadOnlyStoreRejectsAppendAndDoesNotCreateMissingDatabase() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-store-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = root.appendingPathComponent("fixture.sqlite")
        let writer = try SQLiteStore(url: db)
        try await writer.migrate()
        let reader = try SQLiteStore(url: db, readOnly: true)
        do {
            try await reader.append(ActivityEvent(id: UUID(), occurredAt: .now, kind: .proposed, detail: "denied"))
            XCTFail("read-only store accepted a write")
        } catch let error as StoreError { XCTAssertEqual(error, .readOnly) }
        let missing = root.appendingPathComponent("missing.sqlite")
        XCTAssertThrowsError(try SQLiteStore(url: missing, readOnly: true))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
    }

    func testCSVExportEscapesCellsAndNeutralizesSpreadsheetFormulas() throws {
        let event = ActivityEvent(id: UUID(), occurredAt: Date(timeIntervalSince1970: 0), kind: .failed, detail: "=HYPERLINK(\"x\")")
        let csv = ActivityExport.csv([event])
        XCTAssertTrue(csv.contains("'=HYPERLINK("))
        XCTAssertTrue(csv.contains("\"\""))
    }

    func testJSONExportPreservesTypedEventAndTimestamp() throws {
        let event = ActivityEvent(id: UUID(), occurredAt: Date(timeIntervalSince1970: 0), kind: .movedToTrash, detail: "candidate")
        let data = try ActivityExport.json([event])
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ActivityEvent].self, from: data)
        XCTAssertEqual(decoded, [event])
    }

    func testDiagnosticExportOmitsEventDetailsAndPaths() throws {
        let privateEvent = ActivityEvent(id: UUID(), occurredAt: Date(timeIntervalSince1970: 1), kind: .failed,
                                         detail: "private-fixture-root/hidden.dat")
        let bytes = try DiagnosticExport.json(schemaVersion: 2, events: [privateEvent], createdAt: Date(timeIntervalSince1970: 0))
        let json = String(decoding: bytes, as: UTF8.self)
        XCTAssertFalse(json.contains("private-fixture-root"))
        XCTAssertFalse(json.contains("hidden.dat"))
        XCTAssertTrue(json.contains("\"failed\" : 1") || json.contains("\"failed\": 1"))
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(DiagnosticSummary.self, from: bytes)
        XCTAssertEqual(report.schemaVersion, 2)
        XCTAssertEqual(report.eventCounts["failed"], 1)
    }

    func testStoreLocationUsesGreenfieldNamespaceUnderInjectedSupportRoot() {
        let root = URL(fileURLWithPath: "/tmp/synthetic-support", isDirectory: true)
        XCTAssertEqual(StoreLocation.databaseURL(applicationSupportDirectory: root).path,
                       "/tmp/synthetic-support/CoreTend-Reconstruction/records.sqlite")
    }

    func testVersionOneMigrationPreservesActivityAndAddsPreferencesAtomically() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-v1-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("legacy-v1.sqlite")
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &handle), SQLITE_OK)
        let sql = "CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, occurred_at REAL NOT NULL, kind TEXT NOT NULL, detail TEXT NOT NULL); INSERT INTO activity_events VALUES ('11111111-1111-1111-1111-111111111111', 10, 'proposed', 'fixture-event'); PRAGMA user_version = 1;"
        XCTAssertEqual(sqlite3_exec(handle, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(handle)
        let store = try SQLiteStore(url: url)
        try await store.migrate()
        let migratedVersion = try await store.schemaVersion()
        let preservedEvents = try await store.events()
        let exclusions = try await store.exclusions()
        XCTAssertEqual(migratedVersion, 2)
        XCTAssertEqual(preservedEvents.map(\.detail), ["fixture-event"])
        XCTAssertEqual(exclusions, [])
    }

    func testPersistentExclusionsRoundTripAsSortedUniquePaths() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-pref-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SQLiteStore(url: root.appendingPathComponent("store.sqlite")); try await store.migrate()
        try await store.saveExclusions(["/tmp/z", "/tmp/a", "/tmp/z"])
        let exclusions = try await store.exclusions()
        XCTAssertEqual(exclusions, ["/tmp/a", "/tmp/z"])
    }

    func testLegacyImportUsesExplicitFixtureAndIsIdempotentWithoutChangingSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-legacy-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("coretend-preferences-v1.json")
        let bytes = Data("{\"version\":1,\"excludedPaths\":[\"/tmp/excluded\"],\"language\":\"fr\"}".utf8)
        try bytes.write(to: source)
        let attributesBefore = try FileManager.default.attributesOfItem(atPath: source.path)
        let store = try SQLiteStore(url: root.appendingPathComponent("store.sqlite")); try await store.migrate()
        let importer = LegacyPreferencesImporter()
        let preview = try importer.preview(sourceURL: source)
        XCTAssertEqual(preview.excludedPaths, ["/tmp/excluded"])
        let firstImport = try await importer.importCopy(preview, into: store)
        let retryImport = try await importer.importCopy(preview, into: store)
        let importedExclusions = try await store.exclusions()
        let importedLanguage = try await store.languagePreference()
        XCTAssertEqual(firstImport, .imported)
        XCTAssertEqual(retryImport, .alreadyImported)
        XCTAssertEqual(importedExclusions, ["/tmp/excluded"])
        XCTAssertEqual(importedLanguage, "fr")
        let events = try await store.events()
        XCTAssertEqual(events.map(\.kind), [.migrationImported])
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        let attributesAfter = try FileManager.default.attributesOfItem(atPath: source.path)
        XCTAssertEqual(attributesBefore[.size] as? NSNumber, attributesAfter[.size] as? NSNumber)
        XCTAssertEqual(attributesBefore[.modificationDate] as? Date, attributesAfter[.modificationDate] as? Date)
        XCTAssertEqual(attributesBefore[.posixPermissions] as? NSNumber, attributesAfter[.posixPermissions] as? NSNumber)
    }

    func testLegacyImporterRejectsSymlinksAndUnknownFields() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-legacy-unsafe-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let actual = root.appendingPathComponent("actual.json")
        let link = root.appendingPathComponent("coretend-preferences-v1.json")
        try Data("{\"version\":1}".utf8).write(to: actual)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: actual)
        XCTAssertThrowsError(try LegacyPreferencesImporter().preview(sourceURL: link))
        try FileManager.default.removeItem(at: link)
        let unknown = link
        try Data("{\"version\":1,\"accountToken\":\"secret\"}".utf8).write(to: unknown)
        XCTAssertThrowsError(try LegacyPreferencesImporter().preview(sourceURL: unknown))
        let traversal = Data("{\"version\":1,\"excludedPaths\":[\"/tmp/../private\"]}".utf8)
        try traversal.write(to: unknown)
        XCTAssertThrowsError(try LegacyPreferencesImporter().preview(sourceURL: unknown)) { error in
            XCTAssertEqual(error as? LegacyImportError, .unsafePath)
        }
    }
}
