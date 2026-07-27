import Testing
import Foundation
@testable import CoreTendApp

@Suite("ClutterSearch")
struct ClutterSearchTests {
    @Test func exactMatch() {
        #expect(ClutterSearch.matches(fileName: "report.pdf", path: "/Users/x/Downloads/report.pdf", query: "report.pdf"))
    }

    @Test func partialMatch() {
        #expect(ClutterSearch.matches(fileName: "vacation-photo-final.heic", path: "/x/vacation-photo-final.heic", query: "vacation"))
    }

    @Test func caseInsensitive() {
        #expect(ClutterSearch.matches(fileName: "Invoice2024.pdf", path: "/x/Invoice2024.pdf", query: "invoice"))
        #expect(ClutterSearch.matches(fileName: "invoice2024.pdf", path: "/x/invoice2024.pdf", query: "INVOICE"))
    }

    @Test func noMatch() {
        #expect(!ClutterSearch.matches(fileName: "report.pdf", path: "/x/report.pdf", query: "zzz-nomatch"))
    }

    @Test func accentedCharactersMatchReasonably() {
        #expect(ClutterSearch.matches(fileName: "résumé-final.docx", path: "/x/résumé-final.docx", query: "resume"))
        #expect(ClutterSearch.matches(fileName: "café-notes.txt", path: "/x/café-notes.txt", query: "café"))
    }

    @Test func matchesOnContainingPathToo() {
        #expect(ClutterSearch.matches(fileName: "video.mov", path: "/Users/x/Movies/Vacation2024/video.mov", query: "vacation2024"))
    }

    @Test func emptyQueryMatchesEverything() {
        #expect(ClutterSearch.matches(fileName: "anything.zip", path: "/x/anything.zip", query: ""))
        #expect(ClutterSearch.matches(fileName: "anything.zip", path: "/x/anything.zip", query: "   "))
    }

    @Test func clearingSearchRestoresFullList() {
        let names = ["a.pdf", "b.pdf", "c.pdf"]
        let filtered = names.filter { ClutterSearch.matches(fileName: $0, path: "/x/\($0)", query: "a") }
        #expect(filtered == ["a.pdf"])
        let cleared = names.filter { ClutterSearch.matches(fileName: $0, path: "/x/\($0)", query: "") }
        #expect(cleared == names)
    }
}

/// Deterministic fake resolver: maps specific paths to fixed volumes, so
/// tests never touch a real disk or real external drives.
private struct FakeVolumeResolver: VolumeResolving {
    let table: [String: VolumeInfo]
    func volumeInfo(for url: URL) -> VolumeInfo? { table[url.path] }
}

@Suite("ClutterExclusions.normalize")
struct ClutterExclusionsNormalizeTests {
    @Test func absolutePathPassesThrough() {
        #expect(ClutterExclusions.normalize("/Users/x/Downloads") == "/Users/x/Downloads")
    }

    @Test func relativePathIsInvalid() {
        #expect(ClutterExclusions.normalize("Downloads") == nil)
    }

    @Test func emptyPathIsInvalid() {
        #expect(ClutterExclusions.normalize("") == nil)
        #expect(ClutterExclusions.normalize("   ") == nil)
    }

    @Test func trailingSlashIsStripped() {
        #expect(ClutterExclusions.normalize("/Users/x/Downloads/") == "/Users/x/Downloads")
    }

    @Test func rootIsLeftAsIs() {
        #expect(ClutterExclusions.normalize("/") == "/")
    }

    @Test func symlinkPathStillNormalizesLikeAnyOtherPath() {
        // No symlink resolution here by design -- ScanEngine's exclusion
        // check is a plain string prefix match, so a symlink's own path
        // excludes exactly like any other path would.
        #expect(ClutterExclusions.normalize("/Users/x/Desktop/link-to-somewhere") == "/Users/x/Desktop/link-to-somewhere")
    }

    @Test func volumeNotCurrentlyMountedStillNormalizes() {
        // Excluding a path on a volume that happens to be unmounted right
        // now must still succeed -- the exclusion should take effect the
        // next time that volume (or a same-path local folder) is scanned.
        #expect(ClutterExclusions.normalize("/Volumes/Backup/OldStuff") == "/Volumes/Backup/OldStuff")
    }
}

@Suite("ClutterExclusions.targetPath / isExcluded")
struct ClutterExclusionsTargetTests {
    @Test func fileTargetIsTheFileItself() {
        let url = URL(fileURLWithPath: "/Users/x/Downloads/big.zip")
        #expect(ClutterExclusions.targetPath(for: url, asFolder: false) == "/Users/x/Downloads/big.zip")
    }

    @Test func folderTargetIsTheContainingDirectory() {
        let url = URL(fileURLWithPath: "/Users/x/Downloads/big.zip")
        #expect(ClutterExclusions.targetPath(for: url, asFolder: true) == "/Users/x/Downloads")
    }

    @Test func excludingParentFolderCoversChildFile() {
        let exclusions = ["/Users/x/Downloads"]
        #expect(ClutterExclusions.isExcluded("/Users/x/Downloads/big.zip", exclusions: exclusions))
        #expect(ClutterExclusions.isExcluded("/Users/x/Downloads/nested/deep.zip", exclusions: exclusions))
        #expect(!ClutterExclusions.isExcluded("/Users/x/Documents/other.zip", exclusions: exclusions))
    }

    @Test func exactFileExclusionDoesNotCoverSiblings() {
        let exclusions = ["/Users/x/Downloads/big.zip"]
        #expect(ClutterExclusions.isExcluded("/Users/x/Downloads/big.zip", exclusions: exclusions))
        #expect(!ClutterExclusions.isExcluded("/Users/x/Downloads/other.zip", exclusions: exclusions))
    }

    @Test func addingSamePathTwiceStaysASingleTarget() {
        // Store dedup itself is proven in StoreTests.exclusionsUniqueAndRemovable;
        // this just proves the UI computes the identical target both times,
        // so the duplicate insert really is a no-op duplicate, not a new path.
        let url = URL(fileURLWithPath: "/Users/x/Downloads/big.zip")
        let first = ClutterExclusions.targetPath(for: url, asFolder: false)
        let second = ClutterExclusions.targetPath(for: url, asFolder: false)
        #expect(first == second)
    }
}

@Suite("ClutterVolumeGrouping")
struct ClutterVolumeGroupingTests {
    @Test func internalVolume() {
        let resolver = FakeVolumeResolver(table: ["/Users/x/a.pdf": VolumeInfo(id: "macintosh-hd-uuid", name: "Macintosh HD")])
        let url = URL(fileURLWithPath: "/Users/x/a.pdf")
        #expect(ClutterVolumeGrouping.matches(url, volumeID: "macintosh-hd-uuid", resolver: resolver))
        #expect(!ClutterVolumeGrouping.matches(url, volumeID: "other-volume", resolver: resolver))
    }

    @Test func externalVolume() {
        let resolver = FakeVolumeResolver(table: ["/Volumes/Backup/a.pdf": VolumeInfo(id: "backup-uuid", name: "Backup")])
        let url = URL(fileURLWithPath: "/Volumes/Backup/a.pdf")
        let volumes = ClutterVolumeGrouping.availableVolumes(for: [url], resolver: resolver)
        #expect(volumes == [VolumeInfo(id: "backup-uuid", name: "Backup")])
    }

    @Test func volumeUnavailableAfterUnmountFallsBackToSentinelNotDropped() {
        // Resolver returns nil (as it would for a URL whose volume vanished
        // after the scan) -> must surface as `.unavailable`, not disappear.
        let resolver = FakeVolumeResolver(table: [:])
        let url = URL(fileURLWithPath: "/Volumes/GoneNow/x.pdf")
        let volumes = ClutterVolumeGrouping.availableVolumes(for: [url], resolver: resolver)
        #expect(volumes == [VolumeInfo.unavailable])
        #expect(ClutterVolumeGrouping.matches(url, volumeID: VolumeInfo.unavailable.id, resolver: resolver))
    }

    @Test func twoVolumesSharingADisplayNameStayDistinctByIdentifier() {
        let resolver = FakeVolumeResolver(table: [
            "/Volumes/Untitled/a.pdf": VolumeInfo(id: "disk-1-uuid", name: "Untitled"),
            "/Volumes/Untitled 1/b.pdf": VolumeInfo(id: "disk-2-uuid", name: "Untitled"),
        ])
        let urlA = URL(fileURLWithPath: "/Volumes/Untitled/a.pdf")
        let urlB = URL(fileURLWithPath: "/Volumes/Untitled 1/b.pdf")
        let volumes = ClutterVolumeGrouping.availableVolumes(for: [urlA, urlB], resolver: resolver)
        #expect(volumes.count == 2)
        #expect(Set(volumes.map(\.id)) == ["disk-1-uuid", "disk-2-uuid"])
        #expect(ClutterVolumeGrouping.matches(urlA, volumeID: "disk-1-uuid", resolver: resolver))
        #expect(!ClutterVolumeGrouping.matches(urlB, volumeID: "disk-1-uuid", resolver: resolver))
    }

    @Test func cloudFileVolumeStillResolves() {
        // Cloud-synced files (e.g. iCloud Drive) still live on a real local
        // volume identifier — no special-casing needed here (remote-vs-local
        // hydration is a ScanCore/SyncState concern, not a volume-filter one).
        let resolver = FakeVolumeResolver(table: [
            "/Users/x/Library/Mobile Documents/com~apple~CloudDocs/f.pdf": VolumeInfo(id: "macintosh-hd-uuid", name: "Macintosh HD"),
        ])
        let url = URL(fileURLWithPath: "/Users/x/Library/Mobile Documents/com~apple~CloudDocs/f.pdf")
        #expect(ClutterVolumeGrouping.matches(url, volumeID: "macintosh-hd-uuid", resolver: resolver))
    }

    @Test func noFilterMatchesEverything() {
        let resolver = FakeVolumeResolver(table: [:])
        let url = URL(fileURLWithPath: "/anything")
        #expect(ClutterVolumeGrouping.matches(url, volumeID: nil, resolver: resolver))
    }
}
