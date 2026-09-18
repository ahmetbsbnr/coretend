// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import AppKit
import Testing
import AppDiscovery
@testable import CoreTendApp

@Suite("Application inventory test-data isolation")
struct ApplicationInventoryIsolationTests {
    @Test("test mode confines applications, support data and Caskroom to temporary fixtures")
    func testModeUsesOnlyTemporaryFixtures() throws {
        let temporaryRoot = "/tmp/coretend-app-fixtures-\(UUID().uuidString)"
        let locations = ApplicationInventoryLocations.resolve(environment: [
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": temporaryRoot,
        ])

        #expect(locations.home.path.hasPrefix(temporaryRoot + "/ApplicationFixtures/"))
        #expect(locations.applicationRoots.count == 2)
        #expect(locations.applicationRoots.allSatisfy {
            $0.path.hasPrefix(temporaryRoot + "/ApplicationFixtures/")
        })
        #expect(try #require(locations.systemLibrary).path.hasPrefix(
            temporaryRoot + "/ApplicationFixtures/"
        ))
        #expect(locations.caskroomRoots.allSatisfy {
            $0.hasPrefix(temporaryRoot + "/ApplicationFixtures/")
        })
    }

    @Test("an invalid test override has no application, system or Caskroom roots")
    func invalidTestOverrideFailsClosed() {
        let locations = ApplicationInventoryLocations.resolve(environment: [
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": "/Applications/not-a-test-store",
        ])

        #expect(locations.home.path == "/dev/null")
        #expect(locations.applicationRoots.isEmpty)
        #expect(locations.systemLibrary == nil)
        #expect(locations.caskroomRoots.isEmpty)
        #expect(locations.discovery.discoverApps().isEmpty)
    }

    @Test("a normal launch retains standard macOS inventory roots")
    func normalLaunchUsesStandardLocations() throws {
        let home = URL(fileURLWithPath: "/tmp/coretend-normal-home", isDirectory: true)
        let locations = ApplicationInventoryLocations.resolve(environment: [:], realHome: home)

        #expect(locations.home == home)
        #expect(locations.applicationRoots.map(\.path) == [
            "/Applications",
            "/tmp/coretend-normal-home/Applications",
        ])
        #expect(try #require(locations.systemLibrary).path == "/Library")
        #expect(locations.caskroomRoots == HomebrewCaskIndex.caskroomRoots)
    }
}

/// The appearance override is gone: CoreTend renders in its own appearance and
/// no environment variable changes it. What replaces those three tests is the
/// one property that now matters — that the app pins an appearance at all, and
/// pins the one the palette was measured against.
@Suite("Owned appearance")
@MainActor
struct AppAppearanceTests {
    @Test("the app pins the appearance its palette was designed for")
    func pinsDarkAqua() {
        #expect(AppAppearance.name == .darkAqua)
    }

    /// Applying it must be idempotent and must not depend on a window
    /// existing: it runs in `CoreTendApp.init()`, before any scene is built,
    /// so no view can render in the inherited appearance and then swap.
    @Test("applying is safe before any window exists, and repeatable")
    func applyIsIdempotent() {
        AppAppearance.apply()
        AppAppearance.apply()
        #expect(NSApplication.shared.appearance?.name == AppAppearance.name)
    }
}
