// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
@testable import SystemMetrics

@Suite("MetricsCollector")
struct MetricsTests {
    @Test func snapshotHasPlausibleValues() async {
        let collector = MetricsCollector()
        _ = await collector.snapshot()          // prime CPU ticks
        let snap = await collector.snapshot()
        #expect(snap.memoryTotalBytes > 1_000_000_000)
        #expect(snap.memoryUsedBytes > 0)
        #expect(snap.memoryUsedBytes < snap.memoryTotalBytes * 2)
        #expect(snap.diskTotalBytes > 10_000_000_000)
        #expect(snap.diskFreeBytes >= 0)
        #expect(snap.cpuUsedFraction >= 0 && snap.cpuUsedFraction <= 1)
        #expect(["normal", "warning", "critical"].contains(snap.memoryPressureLevel))
        #expect(snap.uptimeSeconds > 0)
    }
}
