import Foundation
import ImageIO
import CoreGraphics
import Darwin

public struct SimilarImagePair: Sendable, Equatable {
    public let first: URL
    public let second: URL
    public let differingBits: Int
    public var id: String { first.path + "\u{0}" + second.path }
}

public struct SimilarImageReport: Sendable, Equatable {
    public let candidates: [SimilarImagePair]
    public let skippedCount: Int
}

/// Local advisory matcher using 64-bit difference hashes. Similarity is a visual heuristic, not proof of duplicates.
public struct SimilarImageEngine: Sendable {
    public let maximumFileBytes: Int64
    public let maximumCandidates: Int
    public let maximumDifferingBits: Int

    public init(maximumFileBytes: Int64 = 100 * 1024 * 1024, maximumCandidates: Int = 5_000, maximumDifferingBits: Int = 8) {
        self.maximumFileBytes = max(0, maximumFileBytes)
        self.maximumCandidates = max(0, maximumCandidates)
        self.maximumDifferingBits = max(0, min(64, maximumDifferingBits))
    }

    public func findSimilar(in urls: [URL]) async throws -> SimilarImageReport {
        var hashes: [(URL, UInt64)] = []
        var skipped = 0
        for url in urls.prefix(maximumCandidates) {
            try Task.checkCancellation()
            guard Self.imageExtensions.contains(url.pathExtension.lowercased()), let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  Int64(size) <= maximumFileBytes, let hash = Self.hash(url) else { skipped += 1; continue }
            hashes.append((url, hash))
        }
        skipped += max(0, urls.count - maximumCandidates)
        var pairs: [SimilarImagePair] = []
        for i in hashes.indices {
            try Task.checkCancellation()
            for j in hashes.indices where j > i {
                let distance = (hashes[i].1 ^ hashes[j].1).nonzeroBitCount
                if distance <= maximumDifferingBits {
                    pairs.append(.init(first: hashes[i].0, second: hashes[j].0, differingBits: distance))
                }
            }
        }
        return .init(candidates: pairs.sorted { $0.differingBits == $1.differingBits ? $0.first.path < $1.first.path : $0.differingBits < $1.differingBits }, skippedCount: skipped)
    }

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp", "gif", "webp"]

    private static func hash(_ url: URL) -> UInt64? {
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 9, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        var pixels = [UInt8](repeating: 0, count: 9 * 8 * 4)
        guard let context = CGContext(data: &pixels, width: 9, height: 8, bitsPerComponent: 8, bytesPerRow: 36,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: 9, height: 8))
        var result: UInt64 = 0
        for y in 0..<8 { for x in 0..<8 {
            let left = luminance(pixels, x: x, y: y)
            let right = luminance(pixels, x: x + 1, y: y)
            if left > right { result |= 1 << (y * 8 + x) }
        }}
        return result
    }

    private static func luminance(_ pixels: [UInt8], x: Int, y: Int) -> Int {
        let index = (y * 9 + x) * 4
        return (299 * Int(pixels[index]) + 587 * Int(pixels[index + 1]) + 114 * Int(pixels[index + 2])) / 1000
    }
}
