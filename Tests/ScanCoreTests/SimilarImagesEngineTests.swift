import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ScanCore

/// End-to-end: real image files on disk → Vision feature prints → grouped
/// output. Also proves a corrupt image is skipped rather than crashing/hanging.
@Suite("SimilarImagesEngine end-to-end")
struct SimilarImagesEngineTests {
    let root: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-sim-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    private func cleanup() { try? FileManager.default.removeItem(at: root) }

    /// Writes a solid-color PNG so Vision has a real decodable image.
    @discardableResult
    private func writePNG(_ name: String, gray: CGFloat) throws -> URL {
        let url = root.appendingPathComponent(name)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CocoaError(.featureUnsupported)
        }
        ctx.setFillColor(red: gray, green: gray, blue: gray, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        let image = ctx.makeImage()!
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
        return url
    }

    @Test func identicalImagesGroupAndCorruptIsSkipped() async throws {
        defer { cleanup() }
        // Two byte-identical images → identical feature prints → one group.
        let a = try writePNG("a.png", gray: 0.5)
        try FileManager.default.copyItem(at: a, to: root.appendingPathComponent("b.png"))
        // A corrupt file with an image extension must be skipped, never crash.
        try Data("not a real image".utf8).write(to: root.appendingPathComponent("broken.png"))
        // A non-image is never collected.
        try Data("text".utf8).write(to: root.appendingPathComponent("notes.txt"))

        var groups: [SimilarImageGroup] = []
        for await event in SimilarImagesEngine(roots: [root]).run() {
            if case let .finished(g) = event { groups = g }
        }
        #expect(groups.count == 1)
        #expect(groups.first?.urls.count == 2)
    }
}
