import XCTest
@testable import Persistence

final class TestStoreOverrideTests: XCTestCase {
    func testNoTestModeUsesProductionStoreLocation() throws {
        let fixture = try Fixture()
        XCTAssertNil(try TestStoreOverride.databaseURL(environment: [:], temporaryRoot: fixture.temporaryRoot, homeDirectory: fixture.home))
    }

    func testTestModeRequiresAllIsolationValuesAndMatchingHomes() throws {
        let fixture = try Fixture()
        let incomplete = ["CORETEND_TEST_MODE": "1"]
        XCTAssertThrowsError(try TestStoreOverride.databaseURL(environment: incomplete, temporaryRoot: fixture.temporaryRoot, homeDirectory: fixture.home))

        var mismatchedHome = fixture.environment
        mismatchedHome["CFFIXED_USER_HOME"] = fixture.root.path
        XCTAssertThrowsError(try TestStoreOverride.databaseURL(environment: mismatchedHome, temporaryRoot: fixture.temporaryRoot, homeDirectory: fixture.home))

        var disabledMode = fixture.environment
        disabledMode["CORETEND_TEST_MODE"] = "0"
        XCTAssertThrowsError(try TestStoreOverride.databaseURL(environment: disabledMode, temporaryRoot: fixture.temporaryRoot, homeDirectory: fixture.home))
    }

    func testTestModeResolvesStoreBelowExplicitTemporaryDirectory() throws {
        let fixture = try Fixture()
        let database = try XCTUnwrap(TestStoreOverride.databaseURL(environment: fixture.environment, temporaryRoot: fixture.temporaryRoot, homeDirectory: fixture.home))
        XCTAssertEqual(database, StoreLocation.databaseURL(applicationSupportDirectory: fixture.storeDirectory))
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.path))
    }

    func testFixtureTrashMustBeBelowTheValidatedStoreAndCannotFollowSymlinks() throws {
        let fixture = try Fixture()
        var environment = fixture.environment
        environment["CORETEND_TEST_TRASH_DIR"] = fixture.storeDirectory.appendingPathComponent("trash", isDirectory: true).path
        let trash = try XCTUnwrap(TestStoreOverride.trashDirectory(
            environment: environment,
            temporaryRoot: fixture.temporaryRoot,
            homeDirectory: fixture.home
        ))
        XCTAssertEqual(trash.path, environment["CORETEND_TEST_TRASH_DIR"])

        environment["CORETEND_TEST_TRASH_DIR"] = fixture.root.appendingPathComponent("outside-trash").path
        XCTAssertThrowsError(try TestStoreOverride.trashDirectory(
            environment: environment,
            temporaryRoot: fixture.temporaryRoot,
            homeDirectory: fixture.home
        ))

        let real = fixture.root.appendingPathComponent("real-trash", isDirectory: true)
        let alias = fixture.storeDirectory.appendingPathComponent("trash-link", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: real)
        environment["CORETEND_TEST_TRASH_DIR"] = alias.path
        XCTAssertThrowsError(try TestStoreOverride.trashDirectory(
            environment: environment,
            temporaryRoot: fixture.temporaryRoot,
            homeDirectory: fixture.home
        ))
    }

    func testFixtureTrashRequiresCompleteFixtureProfile() throws {
        let fixture = try Fixture()
        var environment = fixture.environment
        environment["CORETEND_TEST_TRASH_DIR"] = fixture.storeDirectory.appendingPathComponent("trash").path
        environment.removeValue(forKey: "CORETEND_TEST_MODE")
        XCTAssertThrowsError(try TestStoreOverride.trashDirectory(
            environment: environment,
            temporaryRoot: fixture.temporaryRoot,
            homeDirectory: fixture.home
        ))
    }

    func testStoreCanMigrateInsideFixtureWithoutCreatingProductionLocation() async throws {
        let fixture = try Fixture()
        let database = try XCTUnwrap(TestStoreOverride.databaseURL(environment: fixture.environment, temporaryRoot: fixture.temporaryRoot, homeDirectory: fixture.home))
        try FileManager.default.createDirectory(at: database.deletingLastPathComponent(), withIntermediateDirectories: true)
        let store = try SQLiteStore(url: database)
        try await store.migrate()

        XCTAssertTrue(FileManager.default.fileExists(atPath: database.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.home.appendingPathComponent("Library/Application Support/CoreTend-Reconstruction/records.sqlite").path))
    }

    func testTestModeRejectsHomeTempRootMissingDirectoryAndSymlink() throws {
        let fixture = try Fixture()
        var values = fixture.environment

        values["CORETEND_TEST_STORE_DIR"] = fixture.home.path
        XCTAssertThrowsError(try TestStoreOverride.databaseURL(environment: values, temporaryRoot: fixture.temporaryRoot, homeDirectory: fixture.home))

        values["CORETEND_TEST_STORE_DIR"] = fixture.temporaryRoot.path
        XCTAssertThrowsError(try TestStoreOverride.databaseURL(environment: values, temporaryRoot: fixture.temporaryRoot, homeDirectory: fixture.home))

        values["CORETEND_TEST_STORE_DIR"] = fixture.root.appendingPathComponent("missing").path
        XCTAssertThrowsError(try TestStoreOverride.databaseURL(environment: values, temporaryRoot: fixture.temporaryRoot, homeDirectory: fixture.home))

        let alias = fixture.root.appendingPathComponent("store-link", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.storeDirectory)
        values["CORETEND_TEST_STORE_DIR"] = alias.path
        XCTAssertThrowsError(try TestStoreOverride.databaseURL(environment: values, temporaryRoot: fixture.temporaryRoot, homeDirectory: fixture.home))
    }

    private final class Fixture {
        let root: URL
        let temporaryRoot = FileManager.default.temporaryDirectory
        let home: URL
        let storeDirectory: URL
        let environment: [String: String]

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-store-override-\(UUID().uuidString)", isDirectory: true)
            home = root.appendingPathComponent("profile", isDirectory: true)
            storeDirectory = root.appendingPathComponent("store", isDirectory: true)
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            environment = [
                "CORETEND_TEST_MODE": "1",
                "CORETEND_TEST_STORE_DIR": storeDirectory.path,
                "HOME": home.path,
                "CFFIXED_USER_HOME": home.path
            ]
        }

        deinit { try? FileManager.default.removeItem(at: root) }
    }
}
