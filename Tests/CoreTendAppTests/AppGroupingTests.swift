import Testing
import Foundation
import AppDiscovery
@testable import CoreTendApp

private func app(name: String, bundleID: String?, sizeMB: Int64, lastUsedDaysAgo: Int?) -> InstalledApp {
    InstalledApp(
        name: name, bundleIdentifier: bundleID, version: "1.0",
        path: URL(fileURLWithPath: "/Applications/\(name).app"),
        sizeBytes: sizeMB * 1_000_000, architectures: ["arm64"],
        lastUsedDate: lastUsedDaysAgo.map { Calendar.current.date(byAdding: .day, value: -$0, to: Date())! },
        isQuarantined: false)
}

@Suite("Applications grouping")
struct AppGroupingTests {
    @Test("groups by publisher from bundle id, unknowns fall back honestly")
    func publisherGrouping() {
        let apps = [
            app(name: "A", bundleID: "com.acme.A", sizeMB: 10, lastUsedDaysAgo: 1),
            app(name: "B", bundleID: "com.acme.B", sizeMB: 20, lastUsedDaysAgo: 1),
            app(name: "C", bundleID: nil, sizeMB: 5, lastUsedDaysAgo: nil),
        ]
        let groups = AppGroupingLogic.groups(for: apps, by: .publisher)
        let acme = groups.first { $0.id == "Acme" }
        #expect(acme?.apps.count == 2)
        #expect(groups.first { $0.id == "Unknown" }?.apps.count == 1)
    }

    @Test("size buckets never invent data, use real byte thresholds")
    func sizeGrouping() {
        let apps = [
            app(name: "Small", bundleID: "com.x.s", sizeMB: 10, lastUsedDaysAgo: nil),
            app(name: "Big", bundleID: "com.x.b", sizeMB: 2000, lastUsedDaysAgo: nil),
        ]
        let groups = AppGroupingLogic.groups(for: apps, by: .size)
        #expect(groups.first { $0.id == "Under 50 MB" }?.apps.map { $0.name } == ["Small"])
        #expect(groups.first { $0.id == "Over 1 GB" }?.apps.map { $0.name } == ["Big"])
    }

    @Test("last-used buckets: nil date is Unknown, never guessed")
    func lastUsedGrouping() {
        let apps = [
            app(name: "Recent", bundleID: "com.x.r", sizeMB: 1, lastUsedDaysAgo: 2),
            app(name: "Stale", bundleID: "com.x.s", sizeMB: 1, lastUsedDaysAgo: 500),
            app(name: "Never", bundleID: "com.x.n", sizeMB: 1, lastUsedDaysAgo: nil),
        ]
        let groups = AppGroupingLogic.groups(for: apps, by: .lastUsed)
        #expect(groups.first { $0.id == "This week" }?.apps.map { $0.name } == ["Recent"])
        #expect(groups.first { $0.id == "Over a year ago" }?.apps.map { $0.name } == ["Stale"])
        #expect(groups.first { $0.id == "Unknown" }?.apps.map { $0.name } == ["Never"])
    }

    @Test("grouping by none returns a single group preserving all apps")
    func noneGrouping() {
        let apps = [app(name: "A", bundleID: "com.a.a", sizeMB: 1, lastUsedDaysAgo: nil)]
        let groups = AppGroupingLogic.groups(for: apps, by: .none)
        #expect(groups.count == 1)
        #expect(groups[0].apps.count == 1)
    }
}
