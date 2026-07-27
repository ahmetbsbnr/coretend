import Testing
import Foundation
@testable import ScanCore

@Suite("SimilarImageGroup best-resolution marking")
struct SimilarImagesGroupTests {
    @Test("highest real pixel count wins, never a guess")
    func bestResolutionByPixels() {
        let low = URL(fileURLWithPath: "/tmp/low.jpg")
        let high = URL(fileURLWithPath: "/tmp/high.jpg")
        let group = SimilarImageGroup(
            id: "g", urls: [low, high], totalBytes: 200,
            pixelCounts: [low: Int64(640 * 480), high: Int64(4000 * 3000)])
        #expect(group.bestResolutionURL == high)
    }

    @Test("missing pixel data defaults to zero, never crashes or fabricates")
    func missingPixelDataIsSafe() {
        let known = URL(fileURLWithPath: "/tmp/known.jpg")
        let unknown = URL(fileURLWithPath: "/tmp/unknown.jpg")
        let group = SimilarImageGroup(
            id: "g", urls: [known, unknown], totalBytes: 200,
            pixelCounts: [known: 100])
        #expect(group.bestResolutionURL == known)
    }
}
