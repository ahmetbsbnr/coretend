// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
@testable import CoreTendApp

@Suite("Menu bar attention detection")
struct MenuBarAttentionTests {
    @Test("normal readings never trigger attention")
    func normalIsQuiet() {
        #expect(!MenuBarIconModel.needsAttention(thermalState: "nominal", memoryPressureLevel: "normal", diskFreeBytes: 50_000_000_000))
    }

    @Test("critical thermal state triggers attention")
    func criticalThermal() {
        #expect(MenuBarIconModel.needsAttention(thermalState: "critical", memoryPressureLevel: "normal", diskFreeBytes: 50_000_000_000))
    }

    @Test("critical memory pressure triggers attention")
    func criticalMemory() {
        #expect(MenuBarIconModel.needsAttention(thermalState: "nominal", memoryPressureLevel: "critical", diskFreeBytes: 50_000_000_000))
    }

    @Test("low free disk space triggers attention")
    func lowDisk() {
        #expect(MenuBarIconModel.needsAttention(thermalState: "nominal", memoryPressureLevel: "normal", diskFreeBytes: 1_000_000_000))
    }
}
