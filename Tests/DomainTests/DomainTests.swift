import XCTest
import ProductContract
import SafetyCore
import Persistence
import Darwin
@testable import Domain

final class QuarantineInspectionTests: XCTestCase {
    func testReportsPresenceAndAbsenceOnFixtureWithoutReadingAttributeValue() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-quarantine-\(UUID())", isDirectory: true)
        let app = root.appendingPathComponent("Fixture.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let inspector = MacOSQuarantineInspector()
        XCTAssertEqual(inspector.inspect(at: app).state, .absent)
        let marker = Data("0081;fixture".utf8)
        let result = app.path.withCString { path in
            "com.apple.quarantine".withCString { name in
                marker.withUnsafeBytes { bytes in setxattr(path, name, bytes.baseAddress, bytes.count, 0, 0) }
            }
        }
        XCTAssertEqual(result, 0)
        XCTAssertEqual(inspector.inspect(at: app).state, .present)
        let alias = root.appendingPathComponent("Alias.app")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: app)
        XCTAssertEqual(inspector.inspect(at: alias).state, .unavailable)
    }
}

final class LaunchAgentInspectionTests: XCTestCase {
    func testReadsOnlyExpectedFieldsFromExplicitFixtureFolderAndPreservesBytes() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let programURL = root.appendingPathComponent("program.plist")
        let argumentsURL = root.appendingPathComponent("arguments.plist")
        let programData = try PropertyListSerialization.data(fromPropertyList: ["Label": "org.fixture.program", "Program": "/fixture/program", "ProgramArguments": ["/ignored/first"]], format: .xml, options: 0)
        let argumentsData = try PropertyListSerialization.data(fromPropertyList: ["Label": "org.fixture.arguments", "ProgramArguments": ["/fixture/agent", "--flag"]], format: .xml, options: 0)
        try programData.write(to: programURL)
        try argumentsData.write(to: argumentsURL)
        let report = LaunchAgentInspector().inspect(in: root)
        XCTAssertEqual(report.candidates.map(\.label), ["org.fixture.arguments", "org.fixture.program"])
        XCTAssertEqual(report.candidates.map(\.executablePath), ["/fixture/agent", "/fixture/program"])
        XCTAssertEqual(report.candidates.map(\.plistURL.lastPathComponent), ["arguments.plist", "program.plist"])
        XCTAssertTrue(report.issues.isEmpty)
        XCTAssertEqual(try Data(contentsOf: programURL), programData)
        XCTAssertEqual(try Data(contentsOf: argumentsURL), argumentsData)
    }

    func testMalformedAndOversizedPlistsAreReportedAsIssues() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("not a plist".utf8).write(to: root.appendingPathComponent("broken.plist"))
        try Data(repeating: 0x41, count: LaunchAgentInspector.maximumPlistBytes + 1).write(to: root.appendingPathComponent("large.plist"))
        let report = LaunchAgentInspector().inspect(in: root)
        XCTAssertEqual(Set(report.issues.map(\.reason)), [.malformedPlist, .plistTooLarge])
        XCTAssertTrue(report.candidates.isEmpty)
    }

    func testSkipsSymlinksAndNonPlistFiles() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let external = root.appendingPathComponent("external.plist")
        let contents = try PropertyListSerialization.data(fromPropertyList: ["Label": "org.fixture.external", "Program": "/fixture/external"], format: .xml, options: 0)
        try contents.write(to: external)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked.plist"), withDestinationURL: external)
        try contents.write(to: root.appendingPathComponent("ignored.txt"))
        let report = LaunchAgentInspector().inspect(in: root)
        XCTAssertEqual(report.candidates.map(\.label), ["org.fixture.external"])
        XCTAssertTrue(report.issues.isEmpty)
    }

    func testOpenedDirectoryDescriptorKeepsReadsInsideSelectedFolderAfterPathReplacement() throws {
        let parent = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: parent) }
        let selected = parent.appendingPathComponent("selected", isDirectory: true)
        let renamed = parent.appendingPathComponent("renamed", isDirectory: true)
        let outside = parent.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: selected, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let selectedData = try PropertyListSerialization.data(fromPropertyList: ["Label": "org.selected"], format: .xml, options: 0)
        let outsideData = try PropertyListSerialization.data(fromPropertyList: ["Label": "org.outside"], format: .xml, options: 0)
        try selectedData.write(to: selected.appendingPathComponent("entry.plist"))
        try outsideData.write(to: outside.appendingPathComponent("entry.plist"))
        let directoryDescriptor = selected.path.withCString { open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC) }
        XCTAssertGreaterThanOrEqual(directoryDescriptor, 0)
        defer { if directoryDescriptor >= 0 { _ = close(directoryDescriptor) } }

        try FileManager.default.moveItem(at: selected, to: renamed)
        try FileManager.default.createSymbolicLink(at: selected, withDestinationURL: outside)

        let result = try LaunchAgentInspector.readPlistData(named: "entry.plist", relativeTo: directoryDescriptor)
        XCTAssertEqual(result, selectedData)
        XCTAssertNotEqual(result, outsideData)
    }

    func testCapsPlistCandidatesAndReportsTruncation() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let contents = try PropertyListSerialization.data(fromPropertyList: ["Label": "org.fixture", "Program": "/fixture/program"], format: .xml, options: 0)
        for index in 0...LaunchAgentInspector.maximumCandidates {
            try contents.write(to: root.appendingPathComponent(String(format: "%04d.plist", index)))
        }
        let report = LaunchAgentInspector().inspect(in: root)
        XCTAssertEqual(report.candidates.count, LaunchAgentInspector.maximumCandidates)
        XCTAssertEqual(report.issues.map(\.reason), [.candidateLimitReached])
    }

    private func fixtureRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-launch-agents-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

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
    func testDuplicateReviewRejectsProtectedKeeperAlongsideSelectedCopies() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-duplicate-keeper-\(UUID())", isDirectory: true)
        let trashRoot = root.appendingPathComponent("fixture-trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let keeper = root.appendingPathComponent("keeper.bin")
        let firstCopy = root.appendingPathComponent("copy-a.bin")
        let secondCopy = root.appendingPathComponent("copy-b.bin")
        let bytes = Data("identical fixture bytes".utf8)
        try bytes.write(to: keeper)
        try bytes.write(to: firstCopy)
        try bytes.write(to: secondCopy)

        let store = try SQLiteStore(url: root.appendingPathComponent("events.sqlite"))
        try await store.migrate()
        let allowed = Set(["scan.duplicates"])
        let service = FileActionService(validator: .init(),
                                        executor: SafeActionExecutor(allowedRoots: [root], allowedRules: allowed,
                                                                     trash: DomainFixtureTrash(trashRoot: trashRoot)),
                                        store: store, allowedRoots: [root], allowedRuleIDs: allowed)
        let selections = [
            FileActionSelection(url: keeper, ruleID: "scan.duplicates", isProtectedKeeper: true),
            FileActionSelection(url: firstCopy, ruleID: "scan.duplicates"),
            FileActionSelection(url: secondCopy, ruleID: "scan.duplicates")
        ]

        XCTAssertThrowsError(try service.prepareReview(selections)) { error in
            XCTAssertEqual(error as? ActionReviewError, .protectedKeeperSelected)
        }
        XCTAssertEqual(try Data(contentsOf: keeper), bytes)
        XCTAssertEqual(try Data(contentsOf: firstCopy), bytes)
        XCTAssertEqual(try Data(contentsOf: secondCopy), bytes)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: trashRoot.path).isEmpty)
    }

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
    func testDeclaredHTTPSFeedExposesOnlyItsURLWithAvailabilityUnknown() throws {
        let record = try discoverFixture(updateFeed: "https://updates.example.org/app.xml")
        XCTAssertEqual(record.updateSource, .declaredHTTPSFeed(URL(string: "https://updates.example.org/app.xml")!))
        XCTAssertEqual(record.updateAvailability, .unknown(reason: "update_version_not_checked"))
    }

    func testAbsentFeedHasNoActionableSource() throws {
        let record = try discoverFixture(updateFeed: nil)
        XCTAssertEqual(record.updateSource, .unknown)
        XCTAssertEqual(record.updateAvailability, .unknown(reason: "update_source_not_checked"))
    }

    func testInvalidDeclaredFeedsHaveNoActionableURL() throws {
        let invalidFeeds = [
            "https://[invalid",
            "http://updates.example.org/app.xml",
            "https://user:secret@updates.example.org/app.xml",
            " https://updates.example.org/app.xml ",
            "https://updates.example.org/a b.xml",
            "https://updates.example.org/a\n.xml",
            "https://updates.example.org/\(String(repeating: "a", count: 2_048))"
        ]
        for feed in invalidFeeds {
            let record = try discoverFixture(updateFeed: feed)
            XCTAssertEqual(record.updateSource, .invalidDeclaredFeed, "Unexpected actionable source for \(feed.debugDescription)")
            XCTAssertEqual(record.updateAvailability, .unknown(reason: "update_version_not_checked"))
        }
    }

    private func discoverFixture(updateFeed: String?) throws -> ApplicationRecord {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-update-feed-\(UUID())", isDirectory: true)
        let contents = root.appendingPathComponent("Fixture.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var info: [String: Any] = ["CFBundleIdentifier": "org.example.fixture"]
        info["SUFeedURL"] = updateFeed
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return try XCTUnwrap(ApplicationDiscoveryService().discover(in: root).applications.first)
    }

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
    func testExploreRuleReviewAndApprovalPreserveSourceWhenFixtureTrashFails() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-explore-trash-failure-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("candidate.txt")
        let original = Data("explore fixture".utf8)
        try original.write(to: file)
        let store = try SQLiteStore(url: root.appendingPathComponent("events.sqlite"))
        try await store.migrate()
        let allowed = Set(["scan.explore"])
        let service = FileActionService(validator: .init(),
                                        executor: SafeActionExecutor(allowedRoots: [root], allowedRules: allowed, trash: DomainFailingTrash()),
                                        store: store, allowedRoots: [root], allowedRuleIDs: allowed)
        let review = try service.prepareReview([FileActionSelection(url: file, ruleID: "scan.explore")])

        let proposalRecorded = await service.recordProposal(review)
        XCTAssertTrue(proposalRecorded)
        let approved = try service.confirm(review, accepted: true)
        let report = await service.execute(approved)

        XCTAssertEqual(report.items.first?.outcome, .failed(.trashFailed("synthetic Trash failure")))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try Data(contentsOf: file), original)
        let events = try await store.events()
        XCTAssertEqual(events.map(\.kind), [.proposed, .approved, .failed])
        XCTAssertEqual(events.map(\.detail), [file.path, file.path, "\(file.path) | reason=trash_failed"])
        XCTAssertEqual(events.map(\.failureCode), [nil, nil, "trash_failed"])
    }

    func testConfirmedAppTrashFailurePreservesBundleAndPersistsDistinctAuditEvents() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-app-trash-failure-\(UUID())", isDirectory: true)
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let app = apps.appendingPathComponent("Fixture.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "org.example.fixture"], format: .xml, options: 0)
        let infoURL = contents.appendingPathComponent("Info.plist")
        try plist.write(to: infoURL)
        let record = try XCTUnwrap(ApplicationDiscoveryService().discover(in: apps).applications.first)
        let store = try SQLiteStore(url: root.appendingPathComponent("events.sqlite"))
        try await store.migrate()
        let allowed = Set(["apps.uninstall"])
        let service = FileActionService(validator: .init(),
                                        executor: SafeActionExecutor(allowedRoots: [apps], allowedRules: allowed, trash: DomainFailingTrash()),
                                        store: store, allowedRoots: [apps], allowedRuleIDs: allowed)
        let review = try service.prepareReview([FileActionSelection(url: record.url, ruleID: "apps.uninstall", expectedIdentity: record.fileIdentity)])

        let proposalRecorded = await service.recordProposal(review)
        XCTAssertTrue(proposalRecorded)
        let report = await service.execute(try service.confirm(review, accepted: true))

        XCTAssertEqual(report.reviewID, review.id)
        XCTAssertEqual(report.movedCount, 0)
        XCTAssertEqual(report.items.count, 1)
        XCTAssertEqual(report.items.first?.outcome, .failed(.trashFailed("synthetic Trash failure")))
        XCTAssertEqual(report.items.first?.historyRecorded, true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: app.path))
        XCTAssertEqual(try Data(contentsOf: infoURL), plist)
        let events = try await store.events()
        XCTAssertEqual(events.map(\.kind), [.proposed, .approved, .failed])
        XCTAssertEqual(events.map(\.detail), [record.url.path, record.url.path, "\(record.url.path) | reason=trash_failed"])
        XCTAssertEqual(events.map(\.failureCode), [nil, nil, "trash_failed"])
        XCTAssertFalse(try XCTUnwrap(events.last).detail.contains("synthetic Trash failure"))
    }

    func testReviewedAppBundleMovesToFixtureTrashWithoutAssociatedData() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-app-move-\(UUID())", isDirectory: true)
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let trashRoot = root.appendingPathComponent("fixture-trash", isDirectory: true)
        let app = apps.appendingPathComponent("Fixture.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        let related = root.appendingPathComponent("Application Support", isDirectory: true).appendingPathComponent("org.example.fixture", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: related, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trashRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "org.example.fixture"], format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        try Data("personal fixture".utf8).write(to: related.appendingPathComponent("keep.dat"))
        let record = try XCTUnwrap(ApplicationDiscoveryService().discover(in: apps).applications.first)
        let store = try SQLiteStore(url: root.appendingPathComponent("events.sqlite")); try await store.migrate()
        let allowed = Set(["apps.uninstall"])
        let service = FileActionService(validator: .init(), executor: SafeActionExecutor(allowedRoots: [apps], allowedRules: allowed,
                                        trash: DomainFixtureTrash(trashRoot: trashRoot)), store: store, allowedRoots: [apps], allowedRuleIDs: allowed)
        let review = try service.prepareReview([FileActionSelection(url: record.url, ruleID: "apps.uninstall", expectedIdentity: record.fileIdentity)])
        let proposed = await service.recordProposal(review)
        XCTAssertTrue(proposed)
        let result = await service.execute(try service.confirm(review, accepted: true))
        XCTAssertEqual(result.movedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: app.path))
        XCTAssertEqual(try Data(contentsOf: related.appendingPathComponent("keep.dat")), Data("personal fixture".utf8))
        if case .movedToTrash(_, let destination) = try XCTUnwrap(result.items.first).outcome {
            XCTAssertTrue(FileManager.default.fileExists(atPath: URL(fileURLWithPath: destination).appendingPathComponent("Contents/Info.plist").path))
        } else { XCTFail("bundle did not reach fixture Trash") }
        let events = try await store.events()
        XCTAssertEqual(events.map(\.kind), [.proposed, .approved, .movedToTrash])
    }

    func testAppReplacementBetweenInventoryAndReviewIsRejected() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-app-review-\(UUID())", isDirectory: true)
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let app = apps.appendingPathComponent("Fixture.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "org.example.fixture"], format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        let inventory = ApplicationDiscoveryService().discover(in: apps)
        let record = try XCTUnwrap(inventory.applications.first)
        try FileManager.default.moveItem(at: app, to: root.appendingPathComponent("old.app"))
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        let store = try SQLiteStore(url: root.appendingPathComponent("events.sqlite")); try await store.migrate()
        let allowed = Set(["apps.uninstall"])
        let service = FileActionService(validator: .init(), executor: SafeActionExecutor(allowedRoots: [apps], allowedRules: allowed,
                                        trash: DomainFixtureTrash(trashRoot: root)), store: store, allowedRoots: [apps], allowedRuleIDs: allowed)
        XCTAssertThrowsError(try service.prepareReview([FileActionSelection(url: record.url, ruleID: "apps.uninstall", expectedIdentity: record.fileIdentity)])) { error in
            XCTAssertEqual(error as? PathRefusal, .identityChanged)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: app.path))
    }

    func testDirectoryReplacedAfterReviewDoesNotMoveReplacement() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-uninstall-\(UUID())", isDirectory: true)
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let trashRoot = root.appendingPathComponent("fixture-trash", isDirectory: true)
        try FileManager.default.createDirectory(at: apps, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trashRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = apps.appendingPathComponent("Fixture.app | reason=trash_failed", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let store = try SQLiteStore(url: root.appendingPathComponent("events.sqlite")); try await store.migrate()
        let trash = DomainFixtureTrash(trashRoot: trashRoot)
        let allowed = Set(["apps.uninstall"])
        let service = FileActionService(validator: .init(), executor: SafeActionExecutor(allowedRoots: [apps], allowedRules: allowed, trash: trash),
                                        store: store, allowedRoots: [apps], allowedRuleIDs: allowed)
        let review = try service.prepareReview([FileActionSelection(url: app, ruleID: "apps.uninstall")])
        let proposalRecorded = await service.recordProposal(review)
        XCTAssertTrue(proposalRecorded)
        try FileManager.default.moveItem(at: app, to: root.appendingPathComponent("original.app"))
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let replacement = app.appendingPathComponent("replacement-data")
        try Data("keep".utf8).write(to: replacement)

        let report = await service.execute(try service.confirm(review, accepted: true))
        XCTAssertEqual(report.items.first?.outcome, .failed(.revalidation(.identityChanged)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: replacement.path))
        let calls = await trash.callCount
        XCTAssertEqual(calls, 0)
        let events = try await store.events()
        XCTAssertEqual(events.map(\.kind), [.proposed, .failed])
        XCTAssertEqual(events.last?.detail, app.path)
        XCTAssertNil(events.last?.failureCode)
    }

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
        XCTAssertEqual(events.map(\.failureCode), [nil, nil, nil])
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

private enum DomainFixtureTrashError: Error, CustomStringConvertible {
    case failed
    var description: String { "synthetic Trash failure" }
}

private struct DomainFailingTrash: TrashClient {
    func moveToTrash(_ url: URL) async throws -> URL {
        throw DomainFixtureTrashError.failed
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
