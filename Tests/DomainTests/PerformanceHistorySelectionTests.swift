import XCTest
import Persistence
@testable import Domain

final class PerformanceHistorySelectionTests: XCTestCase {
    func testSelectionSnapsToNearestMeasuredKnownPoint() {
        let earlier = PerformanceSample(measuredAt: Date(timeIntervalSince1970: 10), loadAverage1m: 0.5, availableBytes: nil)
        let later = PerformanceSample(measuredAt: Date(timeIntervalSince1970: 20), loadAverage1m: 1.5, availableBytes: nil)
        let unknown = PerformanceSample(measuredAt: Date(timeIntervalSince1970: 15), loadAverage1m: nil, availableBytes: nil)

        XCTAssertEqual(PerformanceHistorySelection.nearestKnownSample(to: Date(timeIntervalSince1970: 17), in: [earlier, unknown, later]), later)
    }

    func testSelectionBreaksTiesTowardLaterObservationAndRejectsInvalidCursor() {
        let earlier = PerformanceSample(measuredAt: Date(timeIntervalSince1970: 10), loadAverage1m: 0.5, availableBytes: nil)
        let later = PerformanceSample(measuredAt: Date(timeIntervalSince1970: 20), loadAverage1m: 1.5, availableBytes: nil)
        XCTAssertEqual(PerformanceHistorySelection.nearestKnownSample(to: Date(timeIntervalSince1970: 15), in: [earlier, later]), later)
        XCTAssertNil(PerformanceHistorySelection.nearestKnownSample(to: Date(timeIntervalSince1970: .nan), in: [earlier, later]))
    }
}
