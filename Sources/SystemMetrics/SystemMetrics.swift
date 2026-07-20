import Foundation
import Darwin

/// A snapshot of live system health data. All values read locally via Mach/sysctl.
public struct MetricsSnapshot: Sendable {
    public let date: Date
    public let cpuUsedFraction: Double          // 0...1 across all cores
    public let memoryUsedBytes: Int64
    public let memoryTotalBytes: Int64
    public let memoryPressureLevel: String      // "normal" | "warning" | "critical"
    public let diskFreeBytes: Int64
    public let diskTotalBytes: Int64
    public let uptimeSeconds: Int64
    public let thermalState: String
    public let networkBytesPerSecond: Int64  // combined in+out, since previous sample (0 on first sample)

    public var memoryUsedFraction: Double {
        memoryTotalBytes > 0 ? Double(memoryUsedBytes) / Double(memoryTotalBytes) : 0
    }
    public var diskUsedFraction: Double {
        diskTotalBytes > 0 ? 1 - Double(diskFreeBytes) / Double(diskTotalBytes) : 0
    }
}

/// Samples system metrics. CPU usage needs two tick samples; the collector
/// keeps the previous sample between calls.
public actor MetricsCollector {
    private var previousTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var previousNetwork: (bytes: UInt64, date: Date)?

    public init() {}

    public func snapshot() -> MetricsSnapshot {
        MetricsSnapshot(
            date: Date(),
            cpuUsedFraction: cpuUsage(),
            memoryUsedBytes: memoryUsed(),
            memoryTotalBytes: Int64(ProcessInfo.processInfo.physicalMemory),
            memoryPressureLevel: memoryPressure(),
            diskFreeBytes: diskFree().free,
            diskTotalBytes: diskFree().total,
            uptimeSeconds: Int64(ProcessInfo.processInfo.systemUptime),
            thermalState: thermalStateName(),
            networkBytesPerSecond: networkThroughput())
    }

    /// Combined in+out bytes/sec across all non-loopback interfaces, derived
    /// from the cumulative counters `getifaddrs` exposes (delta over wall time).
    private func networkThroughput() -> Int64 {
        var totalBytes: UInt64 = 0
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return 0 }
        defer { freeifaddrs(first) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            defer { cursor = ifa.pointee.ifa_next }
            let flags = Int32(ifa.pointee.ifa_flags)
            guard flags & IFF_LOOPBACK == 0, flags & IFF_UP != 0,
                  ifa.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                  let data = ifa.pointee.ifa_data else { continue }
            let network = data.withMemoryRebound(to: if_data.self, capacity: 1) { $0.pointee }
            totalBytes += UInt64(network.ifi_ibytes) + UInt64(network.ifi_obytes)
        }
        let now = Date()
        defer { previousNetwork = (totalBytes, now) }
        guard let prev = previousNetwork else { return 0 }
        let elapsed = now.timeIntervalSince(prev.date)
        guard elapsed > 0, totalBytes >= prev.bytes else { return 0 }
        return Int64(Double(totalBytes - prev.bytes) / elapsed)
    }

    private func cpuUsage() -> Double {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let ticks = (user: UInt64(info.cpu_ticks.0), system: UInt64(info.cpu_ticks.1),
                     idle: UInt64(info.cpu_ticks.2), nice: UInt64(info.cpu_ticks.3))
        defer { previousTicks = ticks }
        guard let prev = previousTicks else { return 0 }
        let user = ticks.user &- prev.user
        let system = ticks.system &- prev.system
        let idle = ticks.idle &- prev.idle
        let nice = ticks.nice &- prev.nice
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return Double(user + system + nice) / Double(total)
    }

    private func memoryUsed() -> Int64 {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let pageBytes = Int64(pageSize)
        // Used = active + wired + compressed (matches Activity Monitor's notion closely).
        let used = Int64(stats.active_count) + Int64(stats.wire_count) + Int64(stats.compressor_page_count)
        return used * pageBytes
    }

    private func memoryPressure() -> String {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else {
            return "normal"
        }
        switch level {
        case 2: return "warning"
        case 4: return "critical"
        default: return "normal"
        }
    }

    private func diskFree() -> (free: Int64, total: Int64) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let values = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey,
        ]) else { return (0, 0) }
        return (values.volumeAvailableCapacityForImportantUsage ?? 0,
                Int64(values.volumeTotalCapacity ?? 0))
    }

    private func thermalStateName() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}
