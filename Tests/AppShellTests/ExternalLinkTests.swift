import XCTest
@testable import AppShell

final class ExternalLinkTests: XCTestCase {
    func testOpenNamesASpace() {
        XCTAssertEqual(ExternalLink(URL(string: "coretend://open/clean")!), .open(.clean))
        XCTAssertEqual(ExternalLink(URL(string: "coretend://open/apps")!), .open(.apps))
        // 2.0 names and unknown names land on the space that holds them, or Home.
        XCTAssertEqual(ExternalLink(URL(string: "coretend://open/duplicates")!), .open(.space))
        XCTAssertEqual(ExternalLink(URL(string: "coretend://open/nowhere")!), .open(.home))
        XCTAssertEqual(ExternalLink(URL(string: "coretend://open")!), .open(.home))
    }

    func testScanNeedsAnAbsolutePath() {
        XCTAssertEqual(ExternalLink(URL(string: "coretend://scan?path=/tmp/a%20b")!), .scan(URL(fileURLWithPath: "/tmp/a b", isDirectory: true)))
        XCTAssertEqual(ExternalLink(URL(string: "coretend://scan?path=/tmp/x/../y")!), .scan(URL(fileURLWithPath: "/tmp/y", isDirectory: true)))
        XCTAssertNil(ExternalLink(URL(string: "coretend://scan?path=relative")!))
        XCTAssertNil(ExternalLink(URL(string: "coretend://scan")!))
    }

    func testAFolderOpenedWithTheAppIsScanned() {
        XCTAssertEqual(ExternalLink(URL(fileURLWithPath: "/tmp/folder", isDirectory: true)), .scan(URL(fileURLWithPath: "/tmp/folder", isDirectory: true)))
    }

    func testOtherLinksAreIgnored() {
        XCTAssertNil(ExternalLink(URL(string: "https://coretend.ahmetbsbnr.com/open/clean")!))
        XCTAssertNil(ExternalLink(URL(string: "coretend://delete?path=/tmp")!))
    }

    func testSnapshotRoundTripsThroughAContainer() throws {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent("coretend-group-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: container) }
        XCTAssertNil(SharedSnapshot.load(from: container))
        let snapshot = SharedSnapshot(reclaimableBytes: 7_100_000_000, surveyedAt: Date(timeIntervalSince1970: 1_800_000_000))
        snapshot.save(to: container)
        XCTAssertEqual(SharedSnapshot.load(from: container), snapshot)
        XCTAssertNil(SharedSnapshot.load(from: nil))
    }
}
