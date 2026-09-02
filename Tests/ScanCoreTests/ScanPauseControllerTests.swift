// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import SafetyCore
@testable import ScanCore

@Suite("Scan pause / resume")
struct ScanPauseControllerTests {
    @Test func pauseAndResumeReflectIsPaused() async {
        let controller = ScanPauseController()
        #expect(await !controller.isPaused)
        await controller.pause()
        #expect(await controller.isPaused)
        await controller.resume()
        #expect(await !controller.isPaused)
    }

    private func makeRoot(fileCount: Int) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-pause-\(UUID().uuidString)")
        let caches = root.appendingPathComponent("Library/Caches")
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        let payload = Data(repeating: 1, count: 16)
        for i in 0..<fileCount {
            try payload.write(to: caches.appendingPathComponent("f\(i).tmp"))
        }
        return root
    }

    private func rule() -> ScanRule {
        ScanRule(id: "t", name: "t", category: "t", explanation: "t", risk: .low, preselect: true) {
            [$0.appendingPathComponent("Library/Caches")]
        }
    }

    @discardableResult
    private func writePNG(_ url: URL, gray: CGFloat) throws -> URL {
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

    /// A scan paused from the start only produces its findings once resumed —
    /// proven by having the only path to `resume()` go through a delayed Task,
    /// so a `.finished` event with the full count is only reachable if the
    /// pause genuinely held the walk back until that delay elapsed.
    @Test func pausedScanResumesAndCompletesWithCorrectTotals() async throws {
        let fileCount = 200
        let root = try makeRoot(fileCount: fileCount)
        defer { try? FileManager.default.removeItem(at: root) }
        let controller = ScanPauseController()
        await controller.pause()

        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await controller.resume()
        }

        var findings = 0
        var finishedScanned = -1
        for await event in ScanEngine(configuration: ScanConfiguration(home: root))
            .run(rules: [rule()], pauseController: controller) {
            if case .finding = event { findings += 1 }
            if case let .finished(scanned, _) = event { finishedScanned = scanned }
        }
        #expect(findings == fileCount)
        #expect(finishedScanned == fileCount)
    }

    /// Cancellation (the app closing, or the user hitting Cancel) must win
    /// over an unresolved pause — otherwise a paused scan the user forgot
    /// about would block teardown indefinitely.
    @Test func breakingOutWhilePausedStillTearsDownFast() async throws {
        let root = try makeRoot(fileCount: 4000)
        defer { try? FileManager.default.removeItem(at: root) }
        let controller = ScanPauseController()
        await controller.pause()

        let clock = ContinuousClock()
        let start = clock.now
        var sawStarted = false
        for await event in ScanEngine(configuration: ScanConfiguration(home: root))
            .run(rules: [rule()], pauseController: controller) {
            if case .started = event { sawStarted = true }
            break
        }
        let elapsed = start.duration(to: clock.now)
        #expect(sawStarted)
        #expect(elapsed < .seconds(5))
    }

    /// Regression coverage for the old exit-137 shape: many paused waits must
    /// suspend, not pin every cooperative-executor worker thread.
    @Test func manyPausedWaitsResumeWithoutExecutorStarvation() async {
        let clock = ContinuousClock()
        let controller = ScanPauseController()
        await controller.pause()

        let start = clock.now
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<24 {
                group.addTask {
                    await controller.waitWhilePaused()
                }
            }

            Task.detached(priority: .userInitiated) {
                try? await Task.sleep(for: .milliseconds(150))
                await controller.resume()
            }

            var completed = 0
            for await _ in group {
                completed += 1
            }
            #expect(completed == 24)
        }
        #expect(start.duration(to: clock.now) < .seconds(5))
    }

    @Test func pausedSpaceLensScanResumesAndFinishes() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-spacelens-pause-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = Data(repeating: 2, count: 64)
        for i in 0..<50 {
            try payload.write(to: root.appendingPathComponent("space-\(i).dat"))
        }

        let controller = ScanPauseController()
        await controller.pause()
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await controller.resume()
        }

        var finished: SpaceNode?
        for await event in SpaceLensEngine(root: root, minChildSize: 1)
            .run(pauseController: controller) {
            if case let .finished(node) = event { finished = node }
        }

        #expect(finished?.children.count == 50)
    }

    @Test func pausedDuplicateScanResumesAndFindsGroup() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-dupes-pause-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = Data(repeating: 3, count: 128)
        try payload.write(to: root.appendingPathComponent("a.bin"))
        try payload.write(to: root.appendingPathComponent("b.bin"))

        let controller = ScanPauseController()
        await controller.pause()
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await controller.resume()
        }

        var groups = 0
        for await event in DuplicateEngine(roots: [root], minimumSize: 1)
            .run(pauseController: controller) {
            if case .group = event { groups += 1 }
        }

        #expect(groups == 1)
    }

    @Test func pausedSimilarImagesScanResumesAndFinishes() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-similar-pause-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let original = try writePNG(root.appendingPathComponent("a.png"), gray: 0.45)
        try FileManager.default.copyItem(at: original, to: root.appendingPathComponent("b.png"))

        let controller = ScanPauseController()
        await controller.pause()
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await controller.resume()
        }

        var didFinish = false
        for await event in SimilarImagesEngine(roots: [root]).run(pauseController: controller) {
            if case .finished = event { didFinish = true }
        }

        #expect(didFinish)
    }
}
