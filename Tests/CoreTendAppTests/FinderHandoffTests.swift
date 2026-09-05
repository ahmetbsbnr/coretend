// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import FinderShared
@testable import CoreTendApp

/// The host side of the Finder Sync handoff: parse a `coretend://` URL,
/// re-validate the path against the live filesystem, and route through the
/// shared `AppRouter`. No destructive path is reachable from any of it.
@Suite("FinderHandoff — coretend:// URL → validated read-only route")
@MainActor
struct FinderHandoffTests {

    private func sandbox() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("fh-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func aValidFolderURLRoutesToSpaceLensWithThePayloadBuffered() throws {
        AppRouter.shared.resetForTesting()
        defer { AppRouter.shared.resetForTesting() }

        let root = try sandbox(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Photos")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let url = try #require(FinderHandoffURL.make(action: .scanFolder, path: folder.path))
        FinderHandoff.handle(url)

        // Cold launch: buffered as a payload route on the space-lens module…
        #expect(AppRouter.module(for: try #require(AppRouter.shared.pendingRoute)) == .spaceLens)
        // …and the destination view can consume the folder URL exactly once.
        #expect(AppRouter.shared.consumePendingFolderScanURL() == folder.standardizedFileURL)
        #expect(AppRouter.shared.consumePendingFolderScanURL() == nil, "consumed once")
    }

    @Test func aValidImageURLRoutesToPrivacyLab() throws {
        AppRouter.shared.resetForTesting()
        defer { AppRouter.shared.resetForTesting() }

        let root = try sandbox(); defer { try? FileManager.default.removeItem(at: root) }
        let img = root.appendingPathComponent("holiday.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xE0]).write(to: img)

        FinderHandoff.handle(try #require(FinderHandoffURL.make(action: .inspectImage, path: img.path)))

        #expect(AppRouter.module(for: try #require(AppRouter.shared.pendingRoute)) == .privacyLab)
        #expect(AppRouter.shared.consumePendingImageInspectionURL() == img.standardizedFileURL)
    }

    @Test func aValidAppBundleRoutesToProtection() throws {
        AppRouter.shared.resetForTesting()
        defer { AppRouter.shared.resetForTesting() }

        let root = try sandbox(); defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Demo.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)

        FinderHandoff.handle(try #require(FinderHandoffURL.make(action: .inspectApplication, path: app.path)))

        #expect(AppRouter.module(for: try #require(AppRouter.shared.pendingRoute)) == .protection)
        #expect(AppRouter.shared.consumePendingApplicationInspectionURL() == app.standardizedFileURL)
    }

    @Test func aVanishedTargetRoutesToTheDashboardAndInspectsNothing() throws {
        AppRouter.shared.resetForTesting()
        defer { AppRouter.shared.resetForTesting() }

        let missing = "/private/tmp/coretend-does-not-exist-\(UUID().uuidString)/x"
        FinderHandoff.handle(try #require(FinderHandoffURL.make(action: .inspectImage, path: missing)))

        #expect(AppRouter.shared.pendingRoute == .module(.smartCare))
        #expect(AppRouter.shared.consumePendingImageInspectionURL() == nil, "no payload for an invalid selection")
    }

    @Test func aKindMismatchIsRejected_folderURLSentAsAnImage() throws {
        AppRouter.shared.resetForTesting()
        defer { AppRouter.shared.resetForTesting() }

        let root = try sandbox(); defer { try? FileManager.default.removeItem(at: root) }
        FinderHandoff.handle(try #require(FinderHandoffURL.make(action: .inspectImage, path: root.path)))
        #expect(AppRouter.shared.pendingRoute == .module(.smartCare))
    }

    @Test func aMalformedOrHostileURLIsIgnoredEntirely() {
        AppRouter.shared.resetForTesting()
        defer { AppRouter.shared.resetForTesting() }

        for s in ["https://finder/scan-folder?path=/tmp",
                  "coretend://finder/rm-rf?path=/",
                  "coretend://finder/scan-folder?path=/a/../../etc"] {
            FinderHandoff.handle(URL(string: s)!)
            #expect(AppRouter.shared.pendingRoute == nil, "\(s) must not produce any route")
        }
    }

    @Test func aWarmRouteIsDeliveredOnceAsNotifications() throws {
        AppRouter.shared.resetForTesting()
        _ = AppRouter.shared.markReceiverReady()          // receiver is up
        defer { AppRouter.shared.resetForTesting() }

        let root = try sandbox(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Docs")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var navModules: [ModuleID] = []
        var spaceLensURLs: [URL] = []
        let o1 = NotificationCenter.default.addObserver(forName: .mcNavigate, object: nil, queue: nil) {
            if let m = $0.object as? ModuleID { navModules.append(m) }
        }
        let o2 = NotificationCenter.default.addObserver(forName: .mcOpenSpaceLensAt, object: nil, queue: nil) {
            if let u = $0.object as? URL { spaceLensURLs.append(u) }
        }
        defer { NotificationCenter.default.removeObserver(o1); NotificationCenter.default.removeObserver(o2) }

        FinderHandoff.handle(try #require(FinderHandoffURL.make(action: .scanFolder, path: folder.path)))

        #expect(navModules == [.spaceLens])
        #expect(spaceLensURLs == [folder.standardizedFileURL])
        #expect(AppRouter.shared.pendingRoute == nil, "warm: delivered, not buffered")
    }
}
