import Foundation
import ProductContract
import Persistence
import Darwin

public enum ThermalState: String, Sendable, Equatable { case nominal, fair, serious, critical, unknown }

public struct SystemSnapshot: Sendable, Equatable {
    public let measuredAt: Date
    public let availableBytes: ProductMeasurement<Int64>
    public let totalBytes: ProductMeasurement<Int64>
    public let activeProcessorCount: Int
    public let physicalMemoryBytes: Int64
    public let uptimeSeconds: TimeInterval
    public let thermalState: ThermalState
    public let loadAverage1m: ProductMeasurement<Double>

    public init(measuredAt: Date, availableBytes: ProductMeasurement<Int64>, totalBytes: ProductMeasurement<Int64>,
                activeProcessorCount: Int, physicalMemoryBytes: Int64, uptimeSeconds: TimeInterval, thermalState: ThermalState,
                loadAverage1m: ProductMeasurement<Double> = .unknown(reason: "not_measured")) {
        self.measuredAt = measuredAt; self.availableBytes = availableBytes; self.totalBytes = totalBytes
        self.activeProcessorCount = activeProcessorCount; self.physicalMemoryBytes = physicalMemoryBytes
        self.uptimeSeconds = uptimeSeconds; self.thermalState = thermalState
        self.loadAverage1m = loadAverage1m
    }

    public var performanceSample: PerformanceSample {
        let load: Double? = if case .known(let value) = loadAverage1m, value.isFinite, value >= 0 { value } else { nil }
        let available: Int64? = if case .known(let value) = availableBytes, value >= 0 { value } else { nil }
        return PerformanceSample(measuredAt: measuredAt, loadAverage1m: load, availableBytes: available)
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
        var loadValues = [Double](repeating: 0, count: 3)
        let loadCount = loadValues.withUnsafeMutableBufferPointer { getloadavg($0.baseAddress, 3) }
        let load: ProductMeasurement<Double> = loadCount >= 1 && loadValues[0].isFinite && loadValues[0] >= 0
            ? .known(loadValues[0]) : .unknown(reason: "load_average_unavailable")
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
                              uptimeSeconds: process.systemUptime, thermalState: thermal, loadAverage1m: load)
    }
}

/// Memory in use as macOS reports it (active + wired + compressed pages), read with
/// host_statistics64. Unknown when the call fails; never estimated.
public enum MemoryUsage {
    public static func usedBytes() -> ProductMeasurement<Int64> {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return .unknown(reason: "host_statistics64_failed") }
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS, pageSize > 0 else { return .unknown(reason: "host_page_size_failed") }
        let pages = Int64(stats.active_count) + Int64(stats.wire_count) + Int64(stats.compressor_page_count)
        return .known(pages * Int64(pageSize))
    }

    /// Used share of physical memory (0…1), only from known values.
    public static func fraction(used: ProductMeasurement<Int64>, physical: Int64) -> Double? {
        guard case .known(let value) = used, physical > 0, value >= 0 else { return nil }
        return min(Double(value) / Double(physical), 1)
    }
}
