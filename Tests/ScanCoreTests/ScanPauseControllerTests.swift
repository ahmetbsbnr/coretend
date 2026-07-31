import Testing
import Foundation
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
}
