import Testing
import UserNotifications
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

@Suite("Permission-state formatting")
struct PermissionFormattingTests {
    @Test("authorized statuses read as Authorized")
    func authorized() {
        #expect(PermissionFormatting.notificationLabel(.authorized, language: .en) == "Authorized")
        #expect(PermissionFormatting.notificationLabel(.provisional, language: .en) == "Authorized")
    }

    @Test("denied reads as Denied")
    func denied() {
        #expect(PermissionFormatting.notificationLabel(.denied, language: .en) == "Denied")
    }

    @Test("not determined reads as Not requested, never claims granted")
    func notDetermined() {
        #expect(PermissionFormatting.notificationLabel(.notDetermined, language: .en) == "Not requested")
    }
}
