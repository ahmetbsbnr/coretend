import Testing
import UserNotifications
@testable import MacCareApp

@Suite("Settings permissions derivation")
struct SettingsPermissionsTests {
    @Test("Full Disk Access reflects the probed boolean honestly")
    func fullDiskAccess() {
        #expect(SettingsPermissions.fullDiskAccessRow(granted: true).state == .granted)
        #expect(SettingsPermissions.fullDiskAccessRow(granted: false).state == .notGranted)
    }

    @Test("ClamAV row never claims installed when binary missing")
    func clamAV() {
        #expect(SettingsPermissions.clamAVRow(available: false).state == .notGranted)
        #expect(SettingsPermissions.clamAVRow(available: true).state == .granted)
    }

    @Test("Privileged helper is always reported not applicable — MacCare installs none")
    func privilegedHelper() {
        #expect(SettingsPermissions.privilegedHelperRow().state == .notApplicable)
    }

    @Test("Notification status maps denied distinctly from not-yet-requested")
    func notifications() {
        #expect(SettingsPermissions.notificationRow(status: .authorized).state == .granted)
        #expect(SettingsPermissions.notificationRow(status: .denied).state == .denied)
        #expect(SettingsPermissions.notificationRow(status: .notDetermined).state == .notGranted)
    }

    @Test("Menu bar row reflects the toggle")
    func menuBar() {
        #expect(SettingsPermissions.menuBarRow(enabled: true).state == .granted)
        #expect(SettingsPermissions.menuBarRow(enabled: false).state == .notApplicable)
    }

    @Test("Folder exclusions row reports count without pretending to be a grant/deny state")
    func folderAccess() {
        let row = SettingsPermissions.folderAccessRow(exclusionCount: 3)
        #expect(row.detail.contains("3 folders"))
        #expect(row.state == .notApplicable)
    }
}
