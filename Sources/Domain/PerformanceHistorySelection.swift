import Foundation
import Persistence

public enum PerformanceHistorySelection {
    /// Resolves a chart cursor to a real known observation; never computes an interpolated value.
    public static func nearestKnownSample(to date: Date, in samples: [PerformanceSample]) -> PerformanceSample? {
        let cursor = date.timeIntervalSince1970
        guard cursor.isFinite else { return nil }
        return samples
            .filter { $0.loadAverage1m?.isFinite == true && $0.measuredAt.timeIntervalSince1970.isFinite }
            .min { lhs, rhs in
                let leftDistance = abs(lhs.measuredAt.timeIntervalSince1970 - cursor)
                let rightDistance = abs(rhs.measuredAt.timeIntervalSince1970 - cursor)
                if leftDistance == rightDistance { return lhs.measuredAt > rhs.measuredAt }
                return leftDistance < rightDistance
            }
    }
}
