import Foundation
import ProductContract

public enum ThermalState: String, Sendable, Equatable { case nominal, fair, serious, critical, unknown }

public struct SystemSnapshot: Sendable, Equatable {
    public let measuredAt: Date
    public let availableBytes: ProductMeasurement<Int64>
    public let totalBytes: ProductMeasurement<Int64>
    public let activeProcessorCount: Int
    public let physicalMemoryBytes: Int64
    public let uptimeSeconds: TimeInterval
    public let thermalState: ThermalState

    public init(measuredAt: Date, availableBytes: ProductMeasurement<Int64>, totalBytes: ProductMeasurement<Int64>,
                activeProcessorCount: Int, physicalMemoryBytes: Int64, uptimeSeconds: TimeInterval, thermalState: ThermalState) {
        self.measuredAt = measuredAt; self.availableBytes = availableBytes; self.totalBytes = totalBytes
        self.activeProcessorCount = activeProcessorCount; self.physicalMemoryBytes = physicalMemoryBytes
        self.uptimeSeconds = uptimeSeconds; self.thermalState = thermalState
    }
}

public protocol SystemSnapshotReading: Sendable { func read() -> SystemSnapshot }

public struct SystemSnapshotService: Sendable {
    private let reader: any SystemSnapshotReading
    public init(reader: any SystemSnapshotReading = MacOSSystemSnapshotReader()) { self.reader = reader }
    public func snapshot() -> SystemSnapshot { reader.read() }
}

public struct MacOSSystemSnapshotReader: SystemSnapshotReading {
    public init() {}
    public func read() -> SystemSnapshot {
        let now = Date()
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/")
        let available = (attributes?[.systemFreeSize] as? NSNumber).map { ProductMeasurement.known($0.int64Value) }
            ?? .unknown(reason: "volume_measurement_unavailable")
        let total = (attributes?[.systemSize] as? NSNumber).map { ProductMeasurement.known($0.int64Value) }
            ?? .unknown(reason: "volume_measurement_unavailable")
        let process = ProcessInfo.processInfo
        let thermal: ThermalState
        switch process.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .unknown
        }
        return SystemSnapshot(measuredAt: now, availableBytes: available, totalBytes: total,
                              activeProcessorCount: process.activeProcessorCount,
                              physicalMemoryBytes: Int64(min(UInt64(Int64.max), process.physicalMemory)),
                              uptimeSeconds: process.systemUptime, thermalState: thermal)
    }
}
