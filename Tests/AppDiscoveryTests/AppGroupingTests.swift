import Testing
import Foundation
@testable import AppDiscovery

@Suite("AppGrouping")
struct AppGroupingTests {
    private func app(name: String, bundleID: String?, bytes: Int64, daysAgo: Double?) -> InstalledApp {
        let lastUsed = daysAgo.map { Date().addingTimeInterval(-$0 * 86400) }
        return InstalledApp(name: name, bundleIdentifier: bundleID, version: "1.0",
                             path: URL(fileURLWithPath: "/Applications/\(name).app"),
                             sizeBytes: bytes, architectures: ["arm64"], lastUsedDate: lastUsed)
    }

    @Test func publisherDerivedFromBundleID() {
        let a = app(name: "Safari", bundleID: "com.apple.Safari", bytes: 1, daysAgo: nil)
        #expect(a.publisher == "Apple")
        let b = app(name: "Weird", bundleID: nil, bytes: 1, daysAgo: nil)
        #expect(b.publisher == "Unknown")
        #expect(b.isDataLocationAmbiguous)
    }

    @Test func sizeBucketing() {
        #expect(AppGrouping.sizeBucket(for: 50_000_000) == "Under 100 MB")
        #expect(AppGrouping.sizeBucket(for: 200_000_000) == "100 MB – 500 MB")
        #expect(AppGrouping.sizeBucket(for: 6_000_000_000) == "Over 5 GB")
    }

    @Test func groupedByPublisherSortsByTotalSizeDescending() {
        let apps = [
            app(name: "Big", bundleID: "com.big.App", bytes: 1000, daysAgo: nil),
            app(name: "Small", bundleID: "com.small.App", bytes: 10, daysAgo: nil),
        ]
        let groups = AppGrouping.grouped(apps, by: .publisher)
        #expect(groups.first?.label == "Big")
    }

    @Test func groupedByLastUsedBucketsRecentSeparately() {
        let apps = [
            app(name: "Recent", bundleID: "com.a.App", bytes: 10, daysAgo: 1),
            app(name: "Old", bundleID: "com.b.App", bytes: 10, daysAgo: 400),
        ]
        let groups = AppGrouping.grouped(apps, by: .lastUsed)
        let labels = Set(groups.map(\.label))
        #expect(labels.contains("This week"))
        #expect(labels.contains("Over a year ago"))
    }

    @Test func accessibilityDescriptionFlagsAmbiguousItems() {
        let apps = [app(name: "NoID", bundleID: nil, bytes: 1_000_000, daysAgo: nil)]
        let desc = AppGrouping.accessibilityDescription(label: "Unknown", apps: apps)
        #expect(desc.contains("ambiguous data location"))
    }
}
