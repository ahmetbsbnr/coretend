import XCTest
@testable import ProductContract

final class ProductContractTests: XCTestCase {
    func testCapabilityIDsAreUniqueAndCoverInventory() {
        let ids = Capability.allCases.map(\.rawValue)
        XCTAssertEqual(ids.count, 51)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(ids.contains("safety.execute"))
        XCTAssertTrue(ids.contains("testing.storeisolation"))
    }

    func testManifestHasEightBusinessDestinations() {
        XCTAssertEqual(ProductManifest().destinations.count, 8)
    }

    func testUnknownMeasurementStaysUnknown() {
        let value: ProductMeasurement<Int> = .unknown(reason: "permission denied")
        if case .unknown(let reason) = value { XCTAssertEqual(reason, "permission denied") }
        else { XCTFail("unknown measurement became a numeric value") }
    }
}
