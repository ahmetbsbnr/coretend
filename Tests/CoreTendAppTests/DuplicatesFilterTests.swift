import Testing
import Foundation
@testable import ScanCore
@testable import CoreTendApp

private struct FixedVolumeResolver: VolumeResolving {
    let table: [String: VolumeInfo]
    func volumeInfo(for url: URL) -> VolumeInfo? { table[url.path] }
}

/// `filteredGroups` is the exact projection DuplicatesView renders — proves
/// the search/volume wiring on top of ClutterFiltering's pure functions
/// (already unit-tested on their own in ClutterFilteringTests).
@Suite("DuplicatesViewModel filtering")
@MainActor
struct DuplicatesFilterTests {
    @Test func searchMatchesIfAnyCopyMatches() {
        let m = DuplicatesViewModel()
        m.groups = [
            DuplicateGroup(id: "a", fileSize: 100,
                           urls: [URL(fileURLWithPath: "/tmp/a/photo.jpg"), URL(fileURLWithPath: "/tmp/b/photo.jpg")]),
            DuplicateGroup(id: "b", fileSize: 100,
                           urls: [URL(fileURLWithPath: "/tmp/a/report.pdf"), URL(fileURLWithPath: "/tmp/b/report.pdf")]),
        ]
        m.searchText = "photo"
        #expect(m.filteredGroups.map(\.id) == ["a"])
    }

    @Test func volumeFilterKeepsGroupIfAnyCopyIsOnSelectedVolume() {
        let resolver = FixedVolumeResolver(table: [
            "/tmp/internal/dup.dat": VolumeInfo(id: "internal-uuid", name: "Macintosh HD"),
            "/tmp/backup/dup.dat": VolumeInfo(id: "backup-uuid", name: "Backup"),
        ])
        let m = DuplicatesViewModel(volumeResolver: resolver)
        m.groups = [DuplicateGroup(id: "a", fileSize: 10,
                                   urls: [URL(fileURLWithPath: "/tmp/internal/dup.dat"),
                                          URL(fileURLWithPath: "/tmp/backup/dup.dat")])]
        m.selectedVolumeID = "backup-uuid"
        #expect(m.filteredGroups.map(\.id) == ["a"]) // group spans both -> stays visible
        m.selectedVolumeID = "some-other-uuid"
        #expect(m.filteredGroups.isEmpty)
    }

    @Test func noFilterShowsAllGroups() {
        let m = DuplicatesViewModel()
        m.groups = [DuplicateGroup(id: "a", fileSize: 10, urls: [URL(fileURLWithPath: "/tmp/x.dat"), URL(fileURLWithPath: "/tmp/y.dat")])]
        #expect(m.filteredGroups.count == 1)
    }

    @Test func exportCSVIncludesSelectionAndKeeperRecommendation() {
        let m = DuplicatesViewModel()
        let keep = URL(fileURLWithPath: "/tmp/Documents/report.csv")
        let remove = URL(fileURLWithPath: "/tmp/Documents/Copy \"A\"/report.csv")
        m.groups = [DuplicateGroup(id: "hash-a", fileSize: 42, urls: [keep, remove])]
        m.selectedPaths = [remove.path]

        let csv = m.exportCSV(language: .en)

        #expect(csv.contains("\"group_id\",\"path\",\"file_name\",\"directory\",\"size_bytes\""))
        #expect(csv.contains("\"hash-a\",\"/tmp/Documents/report.csv\",\"report.csv\",\"/tmp/Documents\",\"42\""))
        #expect(csv.contains("\"false\",\"true\",\"Shallowest path wins; alphabetical order breaks ties. Not based on file age.\""))
        #expect(csv.contains("\"/tmp/Documents/Copy \"\"A\"\"/report.csv\""))
        #expect(csv.contains("\"true\",\"false\",\"\""))
    }
}

@Suite("SimilarImagesViewModel filtering")
@MainActor
struct SimilarImagesFilterTests {
    @Test func searchMatchesIfAnyMemberMatches() {
        let m = SimilarImagesViewModel()
        m.groups = [
            SimilarImageGroup(id: "a", urls: [URL(fileURLWithPath: "/tmp/beach1.jpg"), URL(fileURLWithPath: "/tmp/beach2.jpg")],
                              totalBytes: 100, pixelCounts: [:]),
            SimilarImageGroup(id: "b", urls: [URL(fileURLWithPath: "/tmp/city1.jpg"), URL(fileURLWithPath: "/tmp/city2.jpg")],
                              totalBytes: 100, pixelCounts: [:]),
        ]
        m.searchText = "beach"
        #expect(m.filteredGroups.map(\.id) == ["a"])
    }

    @Test func volumeFilterKeepsClusterIfAnyMemberIsOnSelectedVolume() {
        let resolver = FixedVolumeResolver(table: [
            "/tmp/internal/img1.jpg": VolumeInfo(id: "internal-uuid", name: "Macintosh HD"),
            "/tmp/external/img2.jpg": VolumeInfo(id: "external-uuid", name: "Backup"),
        ])
        let m = SimilarImagesViewModel(volumeResolver: resolver)
        m.groups = [SimilarImageGroup(id: "a",
                                      urls: [URL(fileURLWithPath: "/tmp/internal/img1.jpg"), URL(fileURLWithPath: "/tmp/external/img2.jpg")],
                                      totalBytes: 100, pixelCounts: [:])]
        m.selectedVolumeID = "external-uuid"
        #expect(m.filteredGroups.map(\.id) == ["a"])
        m.selectedVolumeID = "nonexistent-uuid"
        #expect(m.filteredGroups.isEmpty)
    }
}
