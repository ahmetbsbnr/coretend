import Foundation

public struct PerformanceSample: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let measuredAt: Date
    public let loadAverage1m: Double?
    public let availableBytes: Int64?

    public init(id: UUID = UUID(), measuredAt: Date, loadAverage1m: Double?, availableBytes: Int64?) {
        self.id = id
        self.measuredAt = measuredAt
        self.loadAverage1m = loadAverage1m
        self.availableBytes = availableBytes
    }
}

public enum PerformanceHistoryPolicy {
    public static let retentionDays = 30
    public static let maximumSamples = 500
}
