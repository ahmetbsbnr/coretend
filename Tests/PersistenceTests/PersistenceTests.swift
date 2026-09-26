import Foundation
import XCTest
import CSQLite
import Darwin
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
        XCTAssertEqual(version, 5)
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
        XCTAssertEqual(events.map(\.failureCode), [nil, nil])
    }

    func testActivityRejectsNonFiniteTimestamp() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-event-time-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SQLiteStore(url: root.appendingPathComponent("store.sqlite")); try await store.migrate()
        let event = ActivityEvent(id: UUID(), occurredAt: Date(timeIntervalSince1970: .infinity), kind: .proposed, detail: "fixture")
        do {
            try await store.append(event)
            XCTFail("non-finite activity timestamp must be rejected")
        } catch let error as StoreError {
            XCTAssertEqual(error, .statement("invalid activity timestamp"))
        }
        let events = try await store.events()
        XCTAssertTrue(events.isEmpty)
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

    func testFailureCodePersistsWithoutChangingActivityExports() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-event-code-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fixture.sqlite")
        let store = try SQLiteStore(url: url)
        try await store.migrate()
        let detail = "/fixture/failed.app | reason=trash_failed"
        let event = ActivityEvent(id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
                                  occurredAt: Date(timeIntervalSince1970: 0), kind: .failed,
                                  detail: detail, failureCode: "trash_failed")
        try await store.append(event)
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &handle), SQLITE_OK)
        defer { sqlite3_close(handle) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(handle, "SELECT failure_code FROM activity_events WHERE id = '11111111-1111-4111-8111-111111111111'", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(String(cString: sqlite3_column_text(statement, 0)), "trash_failed")
        let savedEvents = try await store.events()
        let saved = try XCTUnwrap(savedEvents.first)
        XCTAssertEqual(saved, event)
        let json = try ActivityExport.json([saved])
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [[String: Any]])
        XCTAssertEqual(Set(try XCTUnwrap(objects.first).keys), ["id", "occurredAt", "kind", "detail"])
        XCTAssertEqual(objects.first?["detail"] as? String, detail)
        let csv = ActivityExport.csv([saved])
        XCTAssertEqual(csv, "id,occurred_at,kind,detail\n\"11111111-1111-4111-8111-111111111111\",\"1970-01-01T00:00:00Z\",\"failed\",\"/fixture/failed.app | reason=trash_failed\"\n")
    }

    func testVersionFourMigrationPreservesRowsWithNullFailureCodes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-v4-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fixture.sqlite")
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &handle), SQLITE_OK)
        let fixture = """
        CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, occurred_at REAL NOT NULL, kind TEXT NOT NULL, detail TEXT NOT NULL);
        INSERT INTO activity_events VALUES ('11111111-1111-4111-8111-111111111111', 10, 'failed', '/fixture/report | reason=trash_failed');
        CREATE TABLE preferences (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
        CREATE TABLE legacy_imports (digest TEXT PRIMARY KEY NOT NULL, imported_at REAL NOT NULL);
        CREATE TABLE performance_samples (id TEXT PRIMARY KEY NOT NULL, measured_at REAL NOT NULL, load_average_1m REAL, available_bytes INTEGER);
        CREATE TABLE saved_files (path TEXT PRIMARY KEY NOT NULL, first_seen_at REAL NOT NULL, last_seen_at REAL NOT NULL, logical_bytes INTEGER, allocated_bytes INTEGER, is_favorite INTEGER NOT NULL DEFAULT 0 CHECK(is_favorite IN (0, 1)));
        PRAGMA user_version = 4;
        """
        XCTAssertEqual(sqlite3_exec(handle, fixture, nil, nil, nil), SQLITE_OK)
        sqlite3_close(handle)
        let preMigrationReader = try SQLiteStore(url: url, readOnly: true)
        let preMigrationEvents = try await preMigrationReader.events()
        XCTAssertEqual(preMigrationEvents.map(\.failureCode), [nil])
        let store = try SQLiteStore(url: url)
        try await store.migrate()
        try await store.migrate()
        let version = try await store.schemaVersion()
        XCTAssertEqual(version, 5)
        let savedEvents = try await store.events()
        let saved = try XCTUnwrap(savedEvents.first)
        XCTAssertEqual(saved.detail, "/fixture/report | reason=trash_failed")
        XCTAssertNil(saved.failureCode)
        let reader = try SQLiteStore(url: url, readOnly: true)
        let readOnlyEvents = try await reader.events()
        XCTAssertEqual(readOnlyEvents, [saved])
    }

    func testDiagnosticExportContainsOnlyAllowlistedAggregateFields() throws {
        let events = [
            ActivityEvent(id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
                          occurredAt: Date(timeIntervalSince1970: 1_000_000_000), kind: .failed,
                          detail: "PRIVATE_DETAIL_ALPHA synthetic-root-alpha/secret-alpha.dat"),
            ActivityEvent(id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
                          occurredAt: Date(timeIntervalSince1970: 1_000_000_001), kind: .proposed,
                          detail: "PRIVATE_DETAIL_BETA synthetic-root-beta/secret-beta.log"),
            ActivityEvent(id: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
                          occurredAt: Date(timeIntervalSince1970: 1_000_000_002), kind: .failed,
                          detail: "PRIVATE_DETAIL_GAMMA synthetic-root-gamma/secret-gamma.txt")
        ]
        let bytes = try DiagnosticExport.json(schemaVersion: 2, events: events, createdAt: Date(timeIntervalSince1970: 0))
        let json = String(decoding: bytes, as: UTF8.self).lowercased()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["product", "version", "schemaVersion", "eventCounts", "createdAt"])
        let counts = try XCTUnwrap(object["eventCounts"] as? [String: Int])
        XCTAssertEqual(counts, ["failed": 2, "proposed": 1])
        for marker in [
            "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222",
            "33333333-3333-4333-8333-333333333333",
            "2001-09-09T01:46:40Z", "2001-09-09T01:46:41Z", "2001-09-09T01:46:42Z",
            "PRIVATE_DETAIL_ALPHA", "PRIVATE_DETAIL_BETA", "PRIVATE_DETAIL_GAMMA",
            "synthetic-root-alpha", "synthetic-root-beta", "synthetic-root-gamma",
            "secret-alpha.dat", "secret-beta.log", "secret-gamma.txt"
        ] {
            XCTAssertFalse(json.contains(marker.lowercased()), "Diagnostic export leaked synthetic marker: \(marker)")
        }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(DiagnosticSummary.self, from: bytes)
        XCTAssertEqual(report.schemaVersion, 2)
        XCTAssertEqual(report.eventCounts, ["failed": 2, "proposed": 1])
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
        XCTAssertEqual(migratedVersion, 5)
        XCTAssertEqual(preservedEvents.map(\.detail), ["fixture-event"])
        XCTAssertEqual(exclusions, [])
    }

    func testPersistentExclusionsRoundTripAsSortedUniquePaths() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-pref-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("store.sqlite")
        do {
            let store = try SQLiteStore(url: url)
            try await store.migrate()
            try await store.saveExclusions(["/tmp/z", "/tmp/a", "/tmp/z"])
            let exclusions = try await store.exclusions()
            XCTAssertEqual(exclusions, ["/tmp/a", "/tmp/z"])
        }

        let reopenedStore = try SQLiteStore(url: url)
        let reopenedExclusions = try await reopenedStore.exclusions()
        XCTAssertEqual(reopenedExclusions, ["/tmp/a", "/tmp/z"])
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

    func testLegacyImportRollsBackLateMarkerFailureAndRetriesSamePreview() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-legacy-rollback-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("coretend-preferences-v1.json")
        let bytes = Data("{\"version\":1,\"excludedPaths\":[\"/tmp/selected\"],\"language\":\"en\"}\n".utf8)
        try bytes.write(to: source)
        let database = root.appendingPathComponent("store.sqlite")
        let store = try SQLiteStore(url: database)
        try await store.migrate()
        let importer = LegacyPreferencesImporter()
        let preview = try importer.preview(sourceURL: source)

        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &handle), SQLITE_OK)
        defer { sqlite3_close(handle) }
        XCTAssertEqual(sqlite3_exec(handle, "CREATE TRIGGER reject_legacy_marker BEFORE INSERT ON legacy_imports BEGIN SELECT RAISE(ABORT, 'fixture marker failure'); END", nil, nil, nil), SQLITE_OK)

        do {
            _ = try await importer.importCopy(preview, into: store)
            XCTFail("marker failure must reject the import")
        } catch let error as StoreError {
            XCTAssertEqual(error, .statement("fixture marker failure"))
        }
        let failedExclusions = try await store.exclusions()
        let failedLanguage = try await store.languagePreference()
        let failedEvents = try await store.events()
        XCTAssertEqual(failedExclusions, [])
        XCTAssertNil(failedLanguage)
        XCTAssertEqual(failedEvents, [])
        var counts: OpaquePointer?
        let countSQL = "SELECT (SELECT COUNT(*) FROM preferences), (SELECT COUNT(*) FROM activity_events), (SELECT COUNT(*) FROM legacy_imports)"
        XCTAssertEqual(sqlite3_prepare_v2(handle, countSQL, -1, &counts, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(counts), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(counts, 0), 0)
        XCTAssertEqual(sqlite3_column_int(counts, 1), 0)
        XCTAssertEqual(sqlite3_column_int(counts, 2), 0)
        sqlite3_finalize(counts)
        XCTAssertEqual(try Data(contentsOf: source), bytes)

        XCTAssertEqual(sqlite3_exec(handle, "DROP TRIGGER reject_legacy_marker", nil, nil, nil), SQLITE_OK)
        let firstRetry = try await importer.importCopy(preview, into: store)
        let secondRetry = try await importer.importCopy(preview, into: store)
        let importedExclusions = try await store.exclusions()
        let importedLanguage = try await store.languagePreference()
        XCTAssertEqual(firstRetry, .imported)
        XCTAssertEqual(secondRetry, .alreadyImported)
        XCTAssertEqual(importedExclusions, ["/tmp/selected"])
        XCTAssertEqual(importedLanguage, "en")
        let events = try await store.events()
        XCTAssertEqual(events.map(\.kind), [.migrationImported])
        XCTAssertEqual(events.map(\.detail), ["legacy_preferences_v1:\(preview.sourceDigest)"])
        XCTAssertEqual(sqlite3_prepare_v2(handle, countSQL, -1, &counts, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(counts), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(counts, 0), 2)
        XCTAssertEqual(sqlite3_column_int(counts, 1), 1)
        XCTAssertEqual(sqlite3_column_int(counts, 2), 1)
        sqlite3_finalize(counts)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
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

    func testLegacyImporterRejectsNamedPipeWithoutBlocking() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-legacy-pipe-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let pipe = root.appendingPathComponent("coretend-preferences-v1.json")
        XCTAssertEqual(mkfifo(pipe.path, mode_t(0o600)), 0)
        XCTAssertThrowsError(try LegacyPreferencesImporter().preview(sourceURL: pipe)) { error in
            XCTAssertEqual(error as? LegacyImportError, .unavailableSource)
        }
    }

    func testVersionTwoMigrationPreservesEventsAndAddsPerformanceHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-v2-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fixture.sqlite")
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &handle), SQLITE_OK)
        let sql = "CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, occurred_at REAL NOT NULL, kind TEXT NOT NULL, detail TEXT NOT NULL); INSERT INTO activity_events VALUES ('11111111-1111-1111-1111-111111111111', 10, 'proposed', 'retained'); CREATE TABLE preferences (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL); INSERT INTO preferences VALUES ('language', 'fr'); CREATE TABLE legacy_imports (digest TEXT PRIMARY KEY NOT NULL, imported_at REAL NOT NULL); PRAGMA user_version = 2;"
        XCTAssertEqual(sqlite3_exec(handle, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(handle)
        let store = try SQLiteStore(url: url)
        try await store.migrate()
        try await store.migrate()
        let version = try await store.schemaVersion()
        let events = try await store.events()
        let language = try await store.languagePreference()
        let samples = try await store.performanceSamples()
        XCTAssertEqual(version, 5)
        XCTAssertEqual(events.map(\.detail), ["retained"])
        XCTAssertEqual(language, "fr")
        XCTAssertEqual(samples, [])
    }

    func testVersionThreeMigrationAddsSavedFilesWithoutChangingExistingRows() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-v3-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fixture.sqlite")
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &handle), SQLITE_OK)
        let sql = "CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, occurred_at REAL NOT NULL, kind TEXT NOT NULL, detail TEXT NOT NULL); INSERT INTO activity_events VALUES ('11111111-1111-1111-1111-111111111111', 10, 'proposed', 'v3-retained'); CREATE TABLE preferences (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL); INSERT INTO preferences VALUES ('language', 'fr'); CREATE TABLE legacy_imports (digest TEXT PRIMARY KEY NOT NULL, imported_at REAL NOT NULL); CREATE TABLE performance_samples (id TEXT PRIMARY KEY NOT NULL, measured_at REAL NOT NULL, load_average_1m REAL, available_bytes INTEGER); INSERT INTO performance_samples VALUES ('22222222-2222-2222-2222-222222222222', 20, NULL, NULL); PRAGMA user_version = 3;"
        XCTAssertEqual(sqlite3_exec(handle, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(handle)
        let store = try SQLiteStore(url: url)
        try await store.migrate(); try await store.migrate()
        let version = try await store.schemaVersion()
        let events = try await store.events()
        let language = try await store.languagePreference()
        let samples = try await store.performanceSamples()
        let files = try await store.savedFiles()
        XCTAssertEqual(version, 5)
        XCTAssertEqual(events.map(\.detail), ["v3-retained"])
        XCTAssertEqual(language, "fr")
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(files, [])
    }

    func testVersionThreeMigrationRollsBackIndexFailureAndRetriesAfterFixtureRepair() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-v3-rollback-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fixture.sqlite")
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &handle), SQLITE_OK)
        defer { sqlite3_close(handle) }
        let fixture = """
        CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, occurred_at REAL NOT NULL, kind TEXT NOT NULL, detail TEXT NOT NULL);
        INSERT INTO activity_events VALUES ('11111111-1111-1111-1111-111111111111', 10, 'proposed', 'v3-event');
        CREATE TABLE preferences (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
        INSERT INTO preferences VALUES ('language', 'fr');
        CREATE TABLE legacy_imports (digest TEXT PRIMARY KEY NOT NULL, imported_at REAL NOT NULL);
        CREATE TABLE performance_samples (id TEXT PRIMARY KEY NOT NULL, measured_at REAL NOT NULL, load_average_1m REAL, available_bytes INTEGER);
        INSERT INTO performance_samples VALUES ('22222222-2222-2222-2222-222222222222', 20, NULL, NULL);
        CREATE TABLE fixture_index_collision (last_seen_at REAL NOT NULL);
        INSERT INTO fixture_index_collision VALUES (30);
        CREATE INDEX saved_files_recency ON fixture_index_collision(last_seen_at DESC);
        PRAGMA user_version = 3;
        """
        XCTAssertEqual(sqlite3_exec(handle, fixture, nil, nil, nil), SQLITE_OK)
        let originalEvent = ActivityEvent(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                                          occurredAt: Date(timeIntervalSince1970: 10), kind: .proposed, detail: "v3-event")
        let originalSample = PerformanceSample(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                                               measuredAt: Date(timeIntervalSince1970: 20), loadAverage1m: nil, availableBytes: nil)
        let store = try SQLiteStore(url: url)
        let backupURL = root.appendingPathComponent("backups/pre-migration.sqlite")
        try FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try sqliteFixtureBackup(from: url, to: backupURL)

        let corruptBackup = root.appendingPathComponent("backups/corrupt.sqlite")
        try Data("not a sqlite database".utf8).write(to: corruptBackup)
        let rejectedRestore = root.appendingPathComponent("backups/rejected-restore.sqlite")
        XCTAssertThrowsError(try sqliteFixtureBackup(from: corruptBackup, to: rejectedRestore))
        XCTAssertFalse(FileManager.default.fileExists(atPath: rejectedRestore.path))

        let restoredURL = root.appendingPathComponent("recovered/pre-migration.sqlite")
        try FileManager.default.createDirectory(at: restoredURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try sqliteFixtureBackup(from: backupURL, to: restoredURL)
        let restored = try SQLiteStore(url: restoredURL)
        let restoredVersion = try await restored.schemaVersion()
        let restoredEvents = try await restored.events()
        let restoredLanguage = try await restored.languagePreference()
        let restoredSamples = try await restored.performanceSamples()
        XCTAssertEqual(restoredVersion, 3)
        XCTAssertEqual(restoredEvents, [originalEvent])
        XCTAssertEqual(restoredLanguage, "fr")
        XCTAssertEqual(restoredSamples, [originalSample])
        var restoredHandle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(restoredURL.path, &restoredHandle), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(restoredHandle, "DROP INDEX saved_files_recency", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_close(restoredHandle), SQLITE_OK)
        try await restored.migrate()
        let migratedRestoreVersion = try await restored.schemaVersion()
        let migratedRestoreEvents = try await restored.events()
        let migratedRestoreLanguage = try await restored.languagePreference()
        let migratedRestoreSamples = try await restored.performanceSamples()
        XCTAssertEqual(migratedRestoreVersion, 5)
        XCTAssertEqual(migratedRestoreEvents, [originalEvent])
        XCTAssertEqual(migratedRestoreLanguage, "fr")
        XCTAssertEqual(migratedRestoreSamples, [originalSample])

        do {
            try await store.migrate()
            XCTFail("preexisting index name must fail after saved_files table creation")
        } catch let error as StoreError {
            XCTAssertEqual(error, .statement("index saved_files_recency already exists"))
        }
        let failedVersion = try await store.schemaVersion()
        let failedEvents = try await store.events()
        let failedLanguage = try await store.languagePreference()
        let failedSamples = try await store.performanceSamples()
        XCTAssertEqual(failedVersion, 3)
        XCTAssertEqual(failedEvents, [originalEvent])
        XCTAssertEqual(failedLanguage, "fr")
        XCTAssertEqual(failedSamples, [originalSample])

        var statement: OpaquePointer?
        let state = "SELECT (SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'saved_files'), (SELECT tbl_name FROM sqlite_master WHERE type = 'index' AND name = 'saved_files_recency'), (SELECT last_seen_at FROM fixture_index_collision)"
        XCTAssertEqual(sqlite3_prepare_v2(handle, state, -1, &statement, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(statement, 0), 0)
        XCTAssertEqual(String(cString: sqlite3_column_text(statement, 1)), "fixture_index_collision")
        XCTAssertEqual(sqlite3_column_double(statement, 2), 30)
        sqlite3_finalize(statement)

        XCTAssertEqual(sqlite3_exec(handle, "DROP INDEX saved_files_recency", nil, nil, nil), SQLITE_OK)
        try await store.migrate()
        let retriedVersion = try await store.schemaVersion()
        let retriedEvents = try await store.events()
        let retriedLanguage = try await store.languagePreference()
        let retriedSamples = try await store.performanceSamples()
        let retriedFiles = try await store.savedFiles()
        XCTAssertEqual(retriedVersion, 5)
        XCTAssertEqual(retriedEvents, [originalEvent])
        XCTAssertEqual(retriedLanguage, "fr")
        XCTAssertEqual(retriedSamples, [originalSample])
        XCTAssertEqual(retriedFiles, [])
        XCTAssertEqual(sqlite3_prepare_v2(handle, "SELECT tbl_name FROM sqlite_master WHERE type = 'index' AND name = 'saved_files_recency'", -1, &statement, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(String(cString: sqlite3_column_text(statement, 0)), "saved_files")
        sqlite3_finalize(statement)
    }

    func testVersionThreeMigrationRejectsPreexistingIncompleteSavedFilesTable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-v3-table-collision-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fixture.sqlite")
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &handle), SQLITE_OK)
        defer { sqlite3_close(handle) }
        let fixture = "CREATE TABLE saved_files (path TEXT PRIMARY KEY NOT NULL, last_seen_at REAL NOT NULL); INSERT INTO saved_files VALUES ('/synthetic/conflict', 10); PRAGMA user_version = 3;"
        XCTAssertEqual(sqlite3_exec(handle, fixture, nil, nil, nil), SQLITE_OK)
        let store = try SQLiteStore(url: url)
        do {
            try await store.migrate()
            XCTFail("an incomplete v3 table must not be adopted as v4")
        } catch let error as StoreError {
            XCTAssertEqual(error, .statement("table saved_files already exists"))
        }
        let version = try await store.schemaVersion()
        XCTAssertEqual(version, 3)
    }

    func testPerformanceHistoryKeepsUnknownSeparateFromZeroAndPrunesOldSamples() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-perf-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = root.appendingPathComponent("fixture.sqlite")
        let store = try SQLiteStore(url: db)
        try await store.migrate()
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        let old = PerformanceSample(measuredAt: now.addingTimeInterval(-31 * 86_400), loadAverage1m: 3, availableBytes: 100)
        let unknown = PerformanceSample(measuredAt: now.addingTimeInterval(-60), loadAverage1m: nil, availableBytes: nil)
        let zero = PerformanceSample(measuredAt: now, loadAverage1m: 0, availableBytes: 0)
        try await store.appendPerformanceSample(old, retentionNow: now)
        try await store.appendPerformanceSample(unknown, retentionNow: now)
        try await store.appendPerformanceSample(zero, retentionNow: now)
        let saved = try await store.performanceSamples()
        XCTAssertEqual(saved, [unknown, zero])
        let reader = try SQLiteStore(url: db, readOnly: true)
        let readOnlySamples = try await reader.performanceSamples()
        XCTAssertEqual(readOnlySamples, [unknown, zero])
        do {
            try await reader.appendPerformanceSample(zero, retentionNow: now)
            XCTFail("read-only store accepted performance write")
        } catch let error as StoreError { XCTAssertEqual(error, .readOnly) }
    }

    func testPerformanceHistoryRejectsNonFiniteTimestamp() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-performance-time-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SQLiteStore(url: root.appendingPathComponent("store.sqlite")); try await store.migrate()
        let sample = PerformanceSample(measuredAt: Date(timeIntervalSince1970: .nan), loadAverage1m: 1, availableBytes: 10)
        do {
            try await store.appendPerformanceSample(sample, retentionNow: Date(timeIntervalSince1970: 100))
            XCTFail("non-finite performance timestamp must be rejected")
        } catch let error as StoreError {
            XCTAssertEqual(error, .statement("invalid performance timestamp"))
        }
        let samples = try await store.performanceSamples()
        XCTAssertTrue(samples.isEmpty)
    }

    func testPerformanceHistoryRejectsNonFiniteRetentionClock() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-retention-clock-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SQLiteStore(url: root.appendingPathComponent("store.sqlite")); try await store.migrate()
        let sample = PerformanceSample(measuredAt: Date(timeIntervalSince1970: 10), loadAverage1m: 1, availableBytes: 10)
        do {
            try await store.appendPerformanceSample(sample, retentionNow: Date(timeIntervalSince1970: .infinity))
            XCTFail("non-finite retention clock must be rejected")
        } catch let error as StoreError {
            XCTAssertEqual(error, .statement("invalid performance timestamp"))
        }
        let samples = try await store.performanceSamples()
        XCTAssertTrue(samples.isEmpty)
    }

    func testSavedFilesKeepOptionalMeasurementsAndFavoritesBeyondRecentRetention() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-saved-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SQLiteStore(url: root.appendingPathComponent("fixture.sqlite"))
        try await store.migrate()
        let now = Date(timeIntervalSince1970: 1_000_000_000)

        try await store.recordRecentFile(path: "/tmp/unknown-item", logicalBytes: nil, allocatedBytes: nil, seenAt: now)
        try await store.setFavorite(path: "/tmp/unknown-item", isFavorite: true, at: now)
        let batch = (0...SQLiteStore.maximumRecentFiles).map { index in
            RecentFileMeasurement(path: "/tmp/recent-\(index)", logicalBytes: Int64(index), allocatedBytes: nil,
                                  seenAt: now.addingTimeInterval(Double(index + 1)))
        }
        try await store.recordRecentFiles(batch)

        let files = try await store.savedFiles()
        XCTAssertEqual(files.filter(\.isFavorite).map(\.path), ["/tmp/unknown-item"])
        XCTAssertNil(files.first(where: { $0.path == "/tmp/unknown-item" })?.logicalBytes)
        XCTAssertEqual(files.filter { !$0.isFavorite }.count, SQLiteStore.maximumRecentFiles)
        XCTAssertFalse(files.contains(where: { $0.path == "/tmp/recent-0" }))
    }

    func testSavedFileWritesValidateAbsolutePathsAndNonnegativeSizes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-saved-invalid-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SQLiteStore(url: root.appendingPathComponent("fixture.sqlite")); try await store.migrate()

        do {
            try await store.recordRecentFile(path: "relative/file", logicalBytes: 1, allocatedBytes: 1)
            XCTFail("relative saved-file path accepted")
        } catch let error as StoreError { XCTAssertEqual(error, .statement("invalid saved-file path")) }
        do {
            try await store.recordRecentFile(path: "/tmp/file", logicalBytes: -1, allocatedBytes: nil)
            XCTFail("negative saved-file size accepted")
        } catch let error as StoreError { XCTAssertEqual(error, .statement("invalid saved-file measurement")) }
    }

    func testRecentFileBatchValidationIsAtomicBeforeDatabaseWrites() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-saved-batch-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SQLiteStore(url: root.appendingPathComponent("fixture.sqlite")); try await store.migrate()
        let batch = [RecentFileMeasurement(path: "/tmp/valid", logicalBytes: 5, allocatedBytes: 4),
                     RecentFileMeasurement(path: "relative/invalid", logicalBytes: 3, allocatedBytes: nil)]

        do {
            try await store.recordRecentFiles(batch)
            XCTFail("invalid batch was accepted")
        } catch let error as StoreError { XCTAssertEqual(error, .statement("invalid saved-file path")) }
        let saved = try await store.savedFiles()
        XCTAssertEqual(saved, [])
    }
}

private func sqliteFixtureBackup(from sourceURL: URL, to destinationURL: URL) throws {
    guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
        throw NSError(domain: "SQLiteFixtureBackup", code: Int(SQLITE_CANTOPEN))
    }
    let stagingURL = destinationURL.deletingLastPathComponent()
        .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).partial")
    var source: OpaquePointer?
    var destination: OpaquePointer?
    var backup: OpaquePointer?
    var sourceOpen = false
    var destinationOpen = false
    var installed = false
    defer {
        if let backup { _ = sqlite3_backup_finish(backup) }
        if destinationOpen, let destination { _ = sqlite3_close_v2(destination) }
        if sourceOpen, let source { _ = sqlite3_close_v2(source) }
        if !installed { try? FileManager.default.removeItem(at: stagingURL) }
    }

    let sourceResult = sqlite3_open_v2(sourceURL.path, &source, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
    guard sourceResult == SQLITE_OK, let sourceHandle = source else {
        throw NSError(domain: "SQLiteFixtureBackup", code: Int(sourceResult))
    }
    sourceOpen = true
    let destinationResult = sqlite3_open_v2(stagingURL.path, &destination,
                                            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_EXCLUSIVE | SQLITE_OPEN_FULLMUTEX, nil)
    guard destinationResult == SQLITE_OK, let destinationHandle = destination else {
        throw NSError(domain: "SQLiteFixtureBackup", code: Int(destinationResult))
    }
    destinationOpen = true
    guard let backupHandle = sqlite3_backup_init(destinationHandle, "main", sourceHandle, "main") else {
        throw NSError(domain: "SQLiteFixtureBackup", code: Int(sqlite3_errcode(destinationHandle)))
    }
    backup = backupHandle
    let stepResult = sqlite3_backup_step(backupHandle, -1)
    let finishResult = sqlite3_backup_finish(backupHandle)
    backup = nil
    guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
        throw NSError(domain: "SQLiteFixtureBackup", code: Int(finishResult == SQLITE_OK ? stepResult : finishResult))
    }

    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(destinationHandle, "PRAGMA integrity_check", -1, &statement, nil) == SQLITE_OK,
          let statement else { throw NSError(domain: "SQLiteFixtureBackup", code: Int(sqlite3_errcode(destinationHandle))) }
    guard sqlite3_step(statement) == SQLITE_ROW,
          let integrity = sqlite3_column_text(statement, 0), String(cString: integrity) == "ok",
          sqlite3_step(statement) == SQLITE_DONE else {
        sqlite3_finalize(statement)
        throw NSError(domain: "SQLiteFixtureBackup", code: Int(SQLITE_CORRUPT))
    }
    sqlite3_finalize(statement)

    guard sqlite3_close_v2(destinationHandle) == SQLITE_OK else { throw NSError(domain: "SQLiteFixtureBackup", code: Int(SQLITE_BUSY)) }
    destinationOpen = false
    guard sqlite3_close_v2(sourceHandle) == SQLITE_OK else { throw NSError(domain: "SQLiteFixtureBackup", code: Int(SQLITE_BUSY)) }
    sourceOpen = false
    try FileManager.default.moveItem(at: stagingURL, to: destinationURL)
    installed = true
}
