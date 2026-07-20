import Testing
import Foundation
import Persistence
@testable import MacCareApp

@Suite("Menu bar status")
struct MenuBarStatusTests {
    @Test("never claims protection when ClamAV is missing, even with a clean scan on record")
    func honestWhenClamAVMissing() {
        let activity = [ActivityRecord(kind: .scan, summary: "Malware scan: 0 findings", itemCount: 0, bytes: 0, dryRun: true)]
        let status = MenuBarStatus.protectionStatus(clamAvailable: false, activity: activity)
        #expect(status.text.contains("not installed"))
        #expect(status.isWarning)
    }

    @Test("reports clean scan as protected when ClamAV is present")
    func protectedWhenClean() {
        let activity = [ActivityRecord(kind: .scan, summary: "Malware scan: 0 findings", itemCount: 0, bytes: 0, dryRun: true)]
        let status = MenuBarStatus.protectionStatus(clamAvailable: true, activity: activity)
        #expect(status.text.hasPrefix("Protected"))
        #expect(!status.isWarning)
    }

    @Test("surfaces a threat finding as a warning")
    func warnsOnThreat() {
        let activity = [ActivityRecord(kind: .error, summary: "Malware scan: 2 findings", itemCount: 2, bytes: 0, dryRun: true)]
        let status = MenuBarStatus.protectionStatus(clamAvailable: true, activity: activity)
        #expect(status.isWarning)
        #expect(status.text.contains("2 findings"))
    }

    @Test("no scan on record is reported honestly, not as protected")
    func noScanYet() {
        let status = MenuBarStatus.protectionStatus(clamAvailable: true, activity: [])
        #expect(status.text == "No malware scan run yet")
        #expect(!status.isWarning)
    }

    @Test("last Smart Care summary picks the most recent Smart Care record, ignoring other kinds")
    func lastSmartCare() {
        let activity = [
            ActivityRecord(kind: .scan, summary: "Malware scan: 0 findings", itemCount: 0, bytes: 0, dryRun: true),
            ActivityRecord(kind: .cleanup, summary: "Smart Care: moved 3 items to Trash", itemCount: 3, bytes: 1000, dryRun: false),
        ]
        let summary = MenuBarStatus.lastSmartCareSummary(activity: activity)
        #expect(summary?.hasPrefix("Smart Care: moved 3 items") == true)
    }

    @Test("relative time buckets seconds/minutes/hours/days correctly")
    func relativeTime() {
        let now = Date()
        #expect(MenuBarStatus.relativeTime(now.addingTimeInterval(-30), now: now) == "just now")
        #expect(MenuBarStatus.relativeTime(now.addingTimeInterval(-120), now: now) == "2m ago")
        #expect(MenuBarStatus.relativeTime(now.addingTimeInterval(-7200), now: now) == "2h ago")
        #expect(MenuBarStatus.relativeTime(now.addingTimeInterval(-172_800), now: now) == "2d ago")
    }
}
