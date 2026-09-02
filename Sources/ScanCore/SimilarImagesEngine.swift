import Foundation
import Vision
import UniformTypeIdentifiers
import ImageIO
import CryptoKit

/// A cluster of visually similar images.
public struct SimilarImageGroup: Sendable, Identifiable {
    public let id: String
    public let urls: [URL]
    public let totalBytes: Int64
    /// Pixel width×height per url (0 when unreadable), used only to mark the
    /// suggested best-resolution copy — never to auto-select or delete.
    public let pixelCounts: [URL: Int64]

    /// Highest real pixel-count member; ties fall back to largest file.
    public var bestResolutionURL: URL? {
        urls.max { lhs, rhs in
            let l = pixelCounts[lhs] ?? 0
            let r = pixelCounts[rhs] ?? 0
            return l == r ? false : l < r
        }
    }
}

public enum SimilarImagesEvent: Sendable {
    case progress(processed: Int, total: Int)
    case finished(groups: [SimilarImageGroup])
    case cancelled
    case unavailable(String)
}

/// Groups images by Vision feature-print distance. All processing is local;
/// feature prints are kept in memory only for the run.
public struct SimilarImagesEngine: Sendable {
    public let roots: [URL]
    public let distanceThreshold: Float
    public let maxImages: Int

    public init(roots: [URL], distanceThreshold: Float = 0.55, maxImages: Int = 1500) {
        self.roots = roots
        self.distanceThreshold = distanceThreshold
        self.maxImages = maxImages
    }

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "gif", "tiff", "webp", "bmp"]

    public func run(pauseController: ScanPauseController? = nil) -> AsyncStream<SimilarImagesEvent> {
        let roots = roots
        let threshold = distanceThreshold
        let maxImages = maxImages
        return AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                // Inventory.
                var images: [(URL, Int64)] = []
                for root in roots {
                    await Self.collectImages(in: root, limit: maxImages, into: &images, pauseController: pauseController)
                    if images.count >= maxImages || Task.isCancelled { break }
                }
                guard !Task.isCancelled else {
                    continuation.yield(.cancelled); continuation.finish(); return
                }

                // Feature prints (sequential; Vision already parallelizes internally).
                var prints: [(URL, Int64, VNFeaturePrintObservation)] = []
                for (index, (url, size)) in images.enumerated() {
                    if Task.isCancelled { break }
                    await pauseController?.waitWhilePaused()
                    if index % 16 == 0 {
                        continuation.yield(.progress(processed: index, total: images.count))
                    }
                    let request = VNGenerateImageFeaturePrintRequest()
                    let handler = VNImageRequestHandler(url: url)
                    guard (try? handler.perform([request])) != nil,
                          let observation = request.results?.first as? VNFeaturePrintObservation else { continue }
                    prints.append((url, size, observation))
                }
                guard !Task.isCancelled else {
                    continuation.yield(.cancelled); continuation.finish(); return
                }

                // Greedy clustering against cluster representatives.
                // ponytail: O(n·k) greedy; fine for ≤1500 images, revisit if scaled up.
                var clusters: [[(URL, Int64)]] = []
                var representatives: [VNFeaturePrintObservation] = []
                for (url, size, observation) in prints {
                    if Task.isCancelled { break }
                    await pauseController?.waitWhilePaused()
                    var assigned = false
                    for (index, representative) in representatives.enumerated() {
                        var distance: Float = .greatestFiniteMagnitude
                        try? observation.computeDistance(&distance, to: representative)
                        if distance < threshold {
                            clusters[index].append((url, size))
                            assigned = true
                            break
                        }
                    }
                    if !assigned {
                        clusters.append([(url, size)])
                        representatives.append(observation)
                    }
                }
                let visionGroups = clusters.filter { $0.count > 1 }.map { members -> SimilarImageGroup in
                    var pixelCounts: [URL: Int64] = [:]
                    for (url, _) in members { pixelCounts[url] = Self.pixelCount(of: url) }
                    return SimilarImageGroup(
                        id: members.first!.0.path,
                        urls: members.map(\.0),
                        totalBytes: members.reduce(0) { $0 + $1.1 },
                        pixelCounts: pixelCounts)
                }
                let usedExactFallbackURLs = Set(visionGroups.flatMap(\.urls))
                let exactFallbackGroups = Self.exactImageGroups(from: images.filter { !usedExactFallbackURLs.contains($0.0) })
                let groups = (visionGroups + exactFallbackGroups).sorted { $0.totalBytes > $1.totalBytes }
                continuation.yield(.finished(groups: groups))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Cheap real pixel dimensions read from image metadata — no full decode.
    static func pixelCount(of url: URL) -> Int64 {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int
        else { return 0 }
        return Int64(width) * Int64(height)
    }

    private static func exactImageGroups(from images: [(URL, Int64)]) -> [SimilarImageGroup] {
        var buckets: [String: [(URL, Int64)]] = [:]
        for (url, size) in images {
            guard let digest = fileDigest(url) else { continue }
            buckets["\(size):\(digest)", default: []].append((url, size))
        }
        return buckets.values
            .filter { $0.count > 1 }
            .map { members in
                var pixelCounts: [URL: Int64] = [:]
                for (url, _) in members { pixelCounts[url] = pixelCount(of: url) }
                return SimilarImageGroup(
                    id: members.first!.0.path,
                    urls: members.map(\.0),
                    totalBytes: members.reduce(0) { $0 + $1.1 },
                    pixelCounts: pixelCounts)
            }
    }

    private static func fileDigest(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try? handle.read(upToCount: 64 * 1024)
            guard let data, !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func collectImages(in root: URL,
                                      limit: Int,
                                      into images: inout [(URL, Int64)],
                                      pauseController: ScanPauseController? = nil) async {
        let baseKeys: Set<URLResourceKey> = [.fileSizeKey, .isSymbolicLinkKey, .isDirectoryKey]
        let keys = baseKeys.union(CloudFile.inventoryKeys)
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants, .skipsHiddenFiles]) else { return }
        while let url = enumerator.nextObject() as? URL {
            if images.count >= limit || Task.isCancelled { break }
            await pauseController?.waitWhilePaused()
            // Never look inside Photos libraries.
            if url.pathExtension == "photoslibrary" { enumerator.skipDescendants(); continue }
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            // Never hydrate a remote-only iCloud placeholder just to feature-print it.
            if CloudFile.isRemoteOnly(values) { continue }
            guard values.isDirectory != true,
                  imageExtensions.contains(url.pathExtension.lowercased()) else { continue }
            images.append((url, Int64(values.fileSize ?? 0)))
        }
    }
}
