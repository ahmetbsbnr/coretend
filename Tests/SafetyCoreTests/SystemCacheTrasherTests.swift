import Darwin
import XCTest
@testable import SafetyCore

final class SystemCacheTrasherTests: XCTestCase {
    private var root: URL!
    private var caches: URL!
    private var trash: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-syscache-\(UUID())", isDirectory: true)
        caches = root.appendingPathComponent("Caches", isDirectory: true)
        trash = root.appendingPathComponent("home/.Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func make(_ name: String) throws -> URL {
        let item = caches.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: item, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: item.appendingPathComponent("blob"))
        return item
    }

    func testMovesACacheIntoTheTrashAndUndoPutsItBack() throws {
        let item = try make("org.example.app")
        let trasher = SystemCacheTrasher(cachesRoot: caches)
        let moved = try trasher.trash(item, into: trash, owner: getuid())
        XCTAssertEqual(moved.path, trash.appendingPathComponent("org.example.app").path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.appendingPathComponent("blob").path))
        try TrashRestorer().restore(moved, to: item)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.appendingPathComponent("blob").path))
    }

    func testNeverReplacesWhatIsAlreadyInTheTrash() throws {
        let item = try make("org.example.app")
        let earlier = trash.appendingPathComponent("org.example.app")
        try Data("earlier".utf8).write(to: earlier)
        let moved = try SystemCacheTrasher(cachesRoot: caches).trash(item, into: trash, owner: getuid())
        XCTAssertEqual(moved.lastPathComponent, "org.example.app 2")
        XCTAssertEqual(try Data(contentsOf: earlier), Data("earlier".utf8))
    }

    func testRefusesAppleCachesLinksAndDeeperItems() throws {
        let trasher = SystemCacheTrasher(cachesRoot: caches)
        let apple = try make("com.apple.Safari")
        XCTAssertThrowsError(try trasher.trash(apple, into: trash, owner: getuid()))
        let deeper = try make("org.example.app").appendingPathComponent("blob")
        XCTAssertThrowsError(try trasher.trash(deeper, into: trash, owner: getuid()))
        let link = caches.appendingPathComponent("org.example.link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        XCTAssertThrowsError(try trasher.trash(link, into: trash, owner: getuid()))
        XCTAssertThrowsError(try trasher.trash(caches.appendingPathComponent("missing"), into: trash, owner: getuid()))
    }

    func testRefusesATrashThatIsNotThePersonsOwnFolder() throws {
        let item = try make("org.example.app")
        let trasher = SystemCacheTrasher(cachesRoot: caches)
        // Wrong name, wrong owner, or a link standing in for the Trash.
        XCTAssertThrowsError(try trasher.trash(item, into: root, owner: getuid()))
        XCTAssertThrowsError(try trasher.trash(item, into: trash, owner: getuid() + 1))
        let elsewhere = root.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let linkedHome = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createDirectory(at: linkedHome, withIntermediateDirectories: true)
        let linkedTrash = linkedHome.appendingPathComponent(".Trash")
        try FileManager.default.createSymbolicLink(at: linkedTrash, withDestinationURL: elsewhere)
        XCTAssertThrowsError(try trasher.trash(item, into: linkedTrash, owner: getuid()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: elsewhere.path), [])
    }
}
