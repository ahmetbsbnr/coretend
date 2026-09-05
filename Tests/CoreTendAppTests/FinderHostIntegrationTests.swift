// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ImageIO
import CoreGraphics
import FinderShared
import IntegrityCore
import SystemMetrics
@testable import CoreTendApp

@Suite("Finder host integration — synthetic read-only selections")
@MainActor
struct FinderHostIntegrationTests {
    private func sandbox() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("finder-integration-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        AppRouter.shared.resetForTesting()
        return root
    }

    private func route(_ action: FinderAction, _ url: URL) throws {
        FinderHandoff.handle(try #require(FinderHandoffURL.make(action: action, path: url.path)))
        _ = AppRouter.shared.markReceiverReady()
    }

    @Test func imageHandoffUsesLivePrivacyInspectorWithoutChangingOriginal() async throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root); AppRouter.shared.resetForTesting() }
        let url = root.appendingPathComponent("synthetic.png")
        let context = try #require(CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
        let original = try Data(contentsOf: url)
        try route(.inspectImage, url)
        let selected = try #require(AppRouter.shared.consumePendingImageInspectionURL())
        let model = PrivacyLabViewModel()
        model.inspect(url: selected)
        for _ in 0..<200 where model.phase != .result { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.inspection?.status == .inspected)
        #expect(try Data(contentsOf: url) == original)
        #expect(AppRouter.shared.pendingRoute == nil)
        #expect(AppRouter.shared.consumePendingImageInspectionURL() == nil)
        model.clear()
        #expect(model.inspection == nil)
        #expect(model.displayName == nil)
    }

    @Test func disappearedImageIsRejectedAtConsumption() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root); AppRouter.shared.resetForTesting() }
        let url = root.appendingPathComponent("photo.jpg")
        try Data().write(to: url)
        try route(.inspectImage, url)
        try FileManager.default.removeItem(at: url)
        #expect(AppRouter.shared.consumePendingImageInspectionURL() == nil)
        #expect(AppRouter.shared.finderSelectionRejected)
        #expect(AppRouter.shared.pendingImageInspectionURL == nil)
    }

    @Test func incompatibleFileIsNeverSentToPrivacyOrIntegrity() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root); AppRouter.shared.resetForTesting() }
        let url = root.appendingPathComponent("notes.txt")
        try Data("synthetic".utf8).write(to: url)
        try route(.inspectImage, url)
        #expect(AppRouter.shared.consumePendingImageInspectionURL() == nil)
        try route(.inspectApplication, url)
        #expect(AppRouter.shared.consumePendingApplicationInspectionURL() == nil)
    }

    @Test func applicationHandoffUsesExistingCodeSignInspector() async throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root); AppRouter.shared.resetForTesting() }
        let app = root.appendingPathComponent("Synthetic.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try route(.inspectApplication, app)
        let selected = try #require(AppRouter.shared.consumePendingApplicationInspectionURL())
        let model = IntegrityViewModel()
        model.inspect(selected)
        for _ in 0..<200 where model.inspectedApp == nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.inspectedApp?.info == CodeSignInspector.inspect(at: app))
        #expect(model.inspectedApp?.info.signatureValid == false)
        #expect(AppRouter.shared.consumePendingApplicationInspectionURL() == nil)
    }

    @Test func folderHandoffScansFixtureWithoutMutationOrPendingCleanup() async throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root); AppRouter.shared.resetForTesting() }
        let file = root.appendingPathComponent("content.bin")
        let bytes = Data(repeating: 42, count: 8192)
        try bytes.write(to: file)
        try route(.scanFolder, root)
        let selected = try #require(AppRouter.shared.consumePendingFolderScanURL())
        let model = SpaceLensViewModel()
        model.start(url: selected, recordVisit: false)
        for _ in 0..<200 where model.phase != .ready { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.phase == .ready)
        #expect(model.root?.isAccessDenied == false)
        #expect((model.root?.size ?? 0) > 0)
        #expect(model.pendingDelete == nil)
        #expect(try Data(contentsOf: file) == bytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["content.bin"])
    }

    @Test func replacementDropsUnconsumedSensitivePayload() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root); AppRouter.shared.resetForTesting() }
        let image = root.appendingPathComponent("photo.jpg")
        try Data().write(to: image)
        AppRouter.shared.route(to: .inspectImage(image))
        AppRouter.shared.route(to: .scanFolder(root))
        #expect(AppRouter.shared.pendingImageInspectionURL == nil)
        #expect(AppRouter.shared.pendingRoute == .scanFolder(root))
        AppRouter.shared.route(to: .module(.smartCare))
        #expect(AppRouter.shared.pendingFolderScanURL == nil)
    }

    @Test func closedWindowBuffersUntilReplacementReceiverAppears() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root); AppRouter.shared.resetForTesting() }
        _ = AppRouter.shared.markReceiverReady()
        AppRouter.shared.markReceiverUnavailable()
        FinderHandoff.handle(try #require(FinderHandoffURL.make(action: .scanFolder, path: root.path)))
        #expect(AppRouter.shared.markReceiverReady() == .scanFolder(root.standardizedFileURL))
        #expect(AppRouter.shared.consumePendingFolderScanURL()?.path == root.path)
        #expect(AppRouter.shared.consumePendingFolderScanURL() == nil)
    }

    @Test func mountedAndAppearingReceiversCannotConsumeTwice() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root); AppRouter.shared.resetForTesting() }
        let image = root.appendingPathComponent("photo.jpg")
        try Data().write(to: image)
        _ = AppRouter.shared.markReceiverReady()
        var consumed: [URL] = []
        let observer = NotificationCenter.default.addObserver(forName: .mcInspectImageAt, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated {
                if let url = AppRouter.shared.consumePendingImageInspectionURL() { consumed.append(url) }
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        try route(.inspectImage, image)
        if let url = AppRouter.shared.consumePendingImageInspectionURL() { consumed.append(url) }
        #expect(consumed == [image])
    }
}
