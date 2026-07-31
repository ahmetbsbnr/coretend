import Testing
import Foundation
import Persistence
@testable import CoreTendApp

@Suite("Favorites & Recents")
struct FavoritesRecentsTests {
    @Test("an existing, readable path reports exists and isReadable true")
    func existingReadablePath() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let location = FavoriteLocation(path: dir.path, isQuickLink: false, record: nil)
        #expect(location.exists)
        #expect(location.isReadable)
        #expect(location.displayName == dir.lastPathComponent)
    }

    @Test("a path that was deleted after being favorited is reported missing, never throws")
    func missingPathReportsFalse() {
        let path = "/tmp/coretend-does-not-exist-\(UUID().uuidString)"
        let location = FavoriteLocation(path: path, isQuickLink: false, record: nil)
        #expect(!location.exists)
    }

    @Test("isFavorite/lastScanned/lastBytes mirror the underlying record, or read as unset without one")
    func recordMirroring() {
        let withRecord = FavoriteLocation(
            path: "/tmp/x", isQuickLink: false,
            record: LocationRecord(path: "/tmp/x", isFavorite: true, lastScanned: Date(), lastBytes: 42))
        #expect(withRecord.isFavorite)
        #expect(withRecord.lastBytes == 42)

        let withoutRecord = FavoriteLocation(path: "/tmp/y", isQuickLink: true, record: nil)
        #expect(!withoutRecord.isFavorite)
        #expect(withoutRecord.lastScanned == nil)
        #expect(withoutRecord.lastBytes == nil)
    }

    @Test("a favorite that is also a quick link is excluded from the Favorites section, so it isn't shown twice")
    func quickLinkFavoriteNotDuplicated() {
        let favorites = [
            LocationRecord(path: "/Users/x/Downloads", isFavorite: true, lastScanned: nil, lastBytes: nil),
            LocationRecord(path: "/Users/x/Projects", isFavorite: true, lastScanned: nil, lastBytes: nil),
        ]
        let result = FavoritesRecentsViewModel.excludingQuickLinks(
            favorites, quickLinkPaths: ["/Users/x/Downloads", "/Users/x/Desktop", "/Users/x/Documents"])
        #expect(result.map(\.path) == ["/Users/x/Projects"])
    }

    @Test("no overlap leaves every favorite in place")
    func noOverlapKeepsAll() {
        let favorites = [LocationRecord(path: "/Users/x/Projects", isFavorite: true, lastScanned: nil, lastBytes: nil)]
        let result = FavoritesRecentsViewModel.excludingQuickLinks(favorites, quickLinkPaths: [])
        #expect(result.count == 1)
    }
}
