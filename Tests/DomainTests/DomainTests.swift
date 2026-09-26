import XCTest
import ProductContract
import SafetyCore
import Persistence
@testable import Domain

final class ApplicationAssociationMatcherTests: XCTestCase {
    func testRequiresExactBundleIdentifierComponentOrFilenameStem() {
        let id = "org.example.PhotoTool"
        XCTAssertTrue(ApplicationAssociationMatcher.matches(URL(fileURLWithPath: "/fixture/org.example.PhotoTool/settings.json"), bundleIdentifier: id))
        XCTAssertTrue(ApplicationAssociationMatcher.matches(URL(fileURLWithPath: "/fixture/org.example.PhotoTool.plist"), bundleIdentifier: id))
        XCTAssertFalse(ApplicationAssociationMatcher.matches(URL(fileURLWithPath: "/fixture/org.example.PhotoTool2/settings.json"), bundleIdentifier: id))
        XCTAssertFalse(ApplicationAssociationMatcher.matches(URL(fileURLWithPath: "/fixture/prefix-org.example.PhotoTool.plist"), bundleIdentifier: id))
        XCTAssertFalse(ApplicationAssociationMatcher.matches(URL(fileURLWithPath: "/fixture/data"), bundleIdentifier: ""))
    }
}

final class DomainTests: XCTestCase {
    func testSnapshotServicePreservesKnownAndUnknownValues() {
        let expected = SystemSnapshot(measuredAt: Date(timeIntervalSince1970: 100),
                                      availableBytes: .known(500), totalBytes: .unknown(reason: "permission unavailable"),
                                      activeProcessorCount: 8, physicalMemoryBytes: 16_000,
                                      uptimeSeconds: 120, thermalState: .unknown)
        let service = SystemSnapshotService(reader: FixedSnapshotReader(value: expected))
        XCTAssertEqual(service.snapshot(), expected)
    }

    func testUnknownStorageIsNotConvertedToZero() {
        let snapshot = SystemSnapshot(measuredAt: .now, availableBytes: .unknown(reason: "unavailable"),
                                      totalBytes: .unknown(reason: "unavailable"), activeProcessorCount: 4,
                                      physicalMemoryBytes: 8_000, uptimeSeconds: 1, thermalState: .nominal)
        if case .unknown(let reason) = snapshot.availableBytes { XCTAssertEqual(reason, "unavailable") }
        else { XCTFail("unknown storage must not become a numeric value") }
    }
}

private struct FixedSnapshotReader: SystemSnapshotReading {
    let value: SystemSnapshot
    func read() -> SystemSnapshot { value }
}

final class ApplicationDiscoveryTests: XCTestCase {
    func testDiscoversOnlyTopLevelAppBundlesUnderInjectedFixtureRoot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-apps-\(UUID())", isDirectory: true)
        let app = root.appendingPathComponent("Fixture.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let info: [String: Any] = ["CFBundleIdentifier": "test.fixture", "CFBundleName": "Fixture", "CFBundleShortVersionString": "1.2"]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        let nested = root.appendingPathComponent("Nested", isDirectory: true).appendingPathComponent("Hidden.app", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let nestedContents = nested.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedContents, withIntermediateDirectories: true)
        try data.write(to: nestedContents.appendingPathComponent("Info.plist"))

        let report = ApplicationDiscoveryService().discover(in: root)
        XCTAssertEqual(report.applications.map(\.bundleIdentifier), ["test.fixture"])
        XCTAssertEqual(report.applications.first?.version, "1.2")
        guard let updateAvailability = report.applications.first?.updateAvailability else { return XCTFail("missing update state") }
        if case .unknown(reason: "update_source_not_checked") = updateAvailability { }
        else { XCTFail("updates must stay unknown until a source is checked") }
    }

    func testSymlinkedBundleMetadataIsNotReadOutsideSelectedTree() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-apps-\(UUID())", isDirectory: true)
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-external-info-\(UUID()).plist")
        let app = root.appendingPathComponent("Fixture.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: outside) }
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "external.fixture"], format: .xml, options: 0)
        try plist.write(to: outside)
        try FileManager.default.createSymbolicLink(at: contents.appendingPathComponent("Info.plist"), withDestinationURL: outside)
        let report = ApplicationDiscoveryService().discover(in: root)
        XCTAssertTrue(report.applications.isEmpty)
        XCTAssertEqual(report.issues.first?.reason, "bundle_metadata_unavailable")
    }
}

final class CodeSignatureModelTests: XCTestCase {
    func testSignatureReportContainsOnlySignatureStateAndOptionalIdentity() {
        let report = CodeSignatureReport(state: .valid, identifier: "example.app", teamIdentifier: nil, statusCode: 0)
        XCTAssertEqual(report.state, .valid)
        XCTAssertEqual(report.identifier, "example.app")
        XCTAssertNil(report.teamIdentifier)
    }
}

final class FileActionServiceTests: XCTestCase {
    func testConfirmedActionLogsBeforeAndAfterFixtureTrashMove() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-action-\(UUID())", isDirectory: true)
        let trashRoot = root.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("candidate.tmp")
        try Data("fixture".utf8).write(to: file)
        let store = try SQLiteStore(url: root.appendingPathComponent("events.sqlite"))
        try await store.migrate()
        let service = FileActionService(validator: PathValidator(),
                                        executor: SafeActionExecutor(allowedRoots: [root], allowedRules: ["cleanup.fixture"], trash: DomainFixtureTrash(trashRoot: trashRoot)),
                                        store: store, allowedRoots: [root], allowedRuleIDs: ["cleanup.fixture"])
        let review = try service.prepareReview([FileActionSelection(url: file, ruleID: "cleanup.fixture")])
        let proposalRecorded = await service.recordProposal(review)
        XCTAssertTrue(proposalRecorded)
        let confirmed = try service.confirm(review, accepted: true)
        let report = await service.execute(confirmed)
        guard let firstResult = report.items.first, case .movedToTrash(let original, _) = firstResult.outcome else { return XCTFail("expected fixture Trash move") }
        XCTAssertEqual(original, file.path)
        XCTAssertTrue(firstResult.historyRecorded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let events = try await store.events()
        XCTAssertEqual(events.map(\.kind), [.proposed, .approved, .movedToTrash])
    }

    func testDeclinedReviewNeverCallsTrashOrRemovesSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-action-\(UUID())", isDirectory: true)
        let trashRoot = root.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("candidate.tmp")
        try Data("fixture".utf8).write(to: file)
        let store = try SQLiteStore(url: root.appendingPathComponent("events.sqlite")); try await store.migrate()
        let trash = DomainFixtureTrash(trashRoot: trashRoot)
        let service = FileActionService(validator: PathValidator(), executor: SafeActionExecutor(allowedRoots: [root], allowedRules: ["cleanup.fixture"], trash: trash), store: store, allowedRoots: [root], allowedRuleIDs: ["cleanup.fixture"])
        let review = try service.prepareReview([FileActionSelection(url: file, ruleID: "cleanup.fixture")])
        XCTAssertThrowsError(try service.confirm(review, accepted: false))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        let declinedCallCount = await trash.callCount
        XCTAssertEqual(declinedCallCount, 0)
    }

    func testAuditWriteFailureBlocksTrashCall() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-action-\(UUID())", isDirectory: true)
        let trashRoot = root.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("candidate.tmp")
        try Data("fixture".utf8).write(to: file)
        let db = root.appendingPathComponent("events.sqlite")
        let writer = try SQLiteStore(url: db); try await writer.migrate()
        let readOnlyStore = try SQLiteStore(url: db, readOnly: true)
        let trash = DomainFixtureTrash(trashRoot: trashRoot)
        let service = FileActionService(validator: PathValidator(), executor: SafeActionExecutor(allowedRoots: [root], allowedRules: ["cleanup.fixture"], trash: trash), store: readOnlyStore, allowedRoots: [root], allowedRuleIDs: ["cleanup.fixture"])
        let batch = try service.confirm(service.prepareReview([FileActionSelection(url: file, ruleID: "cleanup.fixture")]), accepted: true)
        let report = await service.execute(batch)
        XCTAssertEqual(report.items.first?.outcome, .failed(.auditUnavailable))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        let blockedCallCount = await trash.callCount
        XCTAssertEqual(blockedCallCount, 0)
    }
}

private actor DomainFixtureTrash: TrashClient {
    let trashRoot: URL
    private(set) var callCount = 0
    init(trashRoot: URL) { self.trashRoot = trashRoot }
    func moveToTrash(_ url: URL) async throws -> URL {
        callCount += 1
        let destination = trashRoot.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }
}
