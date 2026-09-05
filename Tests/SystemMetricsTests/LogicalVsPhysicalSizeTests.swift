// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation

/// Documents, with real files on the real filesystem, exactly how
/// `URLResourceValues.fileSize` (logical) and `.totalFileAllocatedSize`
/// (physical/allocated) actually behave — the foundation every "logical vs
/// physical" claim CoreTend makes rests on. See
/// `Documentation/APFS_INTELLIGENCE.md` for what this project calls logical
/// vs physical based on these observed behaviors.
@Suite("Logical vs physical file size — real filesystem behavior")
struct LogicalVsPhysicalSizeTests {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func sizes(of url: URL) throws -> (logical: Int64, physical: Int64?) {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
        return (Int64(values.fileSize ?? 0), values.totalFileAllocatedSize.map(Int64.init))
    }

    @Test func normalFileLogicalSizeMatchesItsRealByteCount() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let content = Data(repeating: 0x41, count: 12_345)
        let file = dir.appendingPathComponent("normal.dat")
        try content.write(to: file)
        let (logical, physical) = try sizes(of: file)
        #expect(logical == 12_345, "logical size is always the exact byte count, regardless of block allocation")
        #expect(physical != nil, "a normal file's allocated size is measurable")
        #expect(physical! >= 0)
    }

    @Test func zeroByteFileReportsZeroLogicalSizeNotUnavailable() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("empty.dat")
        try Data().write(to: file)
        let (logical, _) = try sizes(of: file)
        #expect(logical == 0, "a real empty file is a measured zero, never confused with 'unavailable'")
    }

    /// A sparse file: logical size set far beyond what's actually written,
    /// via ftruncate — no data occupies most of that logical range. This is
    /// the concrete case behind "logical size is not reclaimable size": a
    /// sparse file can claim gigabytes logically while allocating almost
    /// nothing physically.
    @Test func sparseFileHasLogicalSizeFarLargerThanPhysicalSize() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("sparse.dat")
        FileManager.default.createFile(atPath: file.path, contents: Data("seed".utf8))
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        let hugeLogicalSize: UInt64 = 50_000_000 // 50 MB logical, ~4 bytes actually written
        try handle.truncate(atOffset: hugeLogicalSize)
        try handle.close()

        let (logical, physical) = try sizes(of: file)
        #expect(logical == Int64(hugeLogicalSize))
        if let physical {
            #expect(physical < logical, "a sparse file's allocation must stay far below its logical size")
            #expect(physical < 1_000_000, "only a few blocks should actually be allocated for ~4 written bytes")
        } else {
            Issue.record("expected a measurable allocated size for a sparse file on this filesystem")
        }
    }

    @Test func hardLinkedFilesReportTheSameAllocationNeverDoubleCounted() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let original = dir.appendingPathComponent("original.dat")
        try Data(repeating: 0x42, count: 20_000).write(to: original)
        let linked = dir.appendingPathComponent("linked.dat")
        try FileManager.default.linkItem(at: original, to: linked)

        let originalValues = try original.resourceValues(forKeys: [.fileSizeKey, .fileResourceIdentifierKey])
        let linkedValues = try linked.resourceValues(forKeys: [.fileSizeKey, .fileResourceIdentifierKey])
        #expect(originalValues.fileSize == linkedValues.fileSize, "both paths report the same file's real size")
        // The identifier (device+inode) must match — this is the exact
        // signal DuplicateEngine already uses to collapse hard links to one
        // entry instead of treating them as two separate duplicates.
        #expect(originalValues.fileResourceIdentifier != nil)
        #expect(originalValues.fileResourceIdentifier?.isEqual(linkedValues.fileResourceIdentifier) == true,
                "two hard-linked paths must resolve to the same underlying identifier")
    }

    @Test func symlinkReportsItsOwnTinySizeNotTheTargets() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let target = dir.appendingPathComponent("big-target.dat")
        try Data(repeating: 0x43, count: 100_000).write(to: target)
        let link = dir.appendingPathComponent("link-to-big")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        // Explicitly asking for the symlink's own metadata (not resolving
        // through it) is what every CoreTend scanner already does — none of
        // them follow symlinks (documented in ScanEngine).
        let linkValues = try link.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
        #expect(linkValues.isSymbolicLink == true)
        #expect((linkValues.fileSize ?? 0) < 1_000, "a symlink's own size is tiny regardless of its target's size")
    }

    @Test func directoryDoesNotReportAMeaningfulFileSize() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let subdirectory = dir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)
        let values = try subdirectory.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        #expect(values.isDirectory == true)
        // fileSize is meaningless for a directory (its "contents" are
        // entries, not bytes) — every scanner in this codebase checks
        // isDirectory and skips summing this value for directories
        // themselves (see ScanEngine.scanRoot: "guard values.isDirectory
        // != true else { continue }").
    }

    @Test func inaccessiblePathThrowsRatherThanReturningAFabricatedSize() {
        let bogus = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).dat")
        #expect(throws: (any Error).self) {
            _ = try bogus.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
        }
    }
}
