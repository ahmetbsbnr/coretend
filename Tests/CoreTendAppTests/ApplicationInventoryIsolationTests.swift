// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import AppKit
import Testing
import AppDiscovery
import DesignSystem
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

/// CoreTend follows the Mac's appearance.
///
/// It used to pin `.darkAqua`, and these tests asserted the pin. Owning a
/// palette and refusing an appearance are different things: the palette is
/// still entirely CoreTend's in both modes — Light is warm paper and a deep
/// teal, never `NSColor.windowBackgroundColor` — but the *choice* of mode
/// belongs to the person using the Mac, and pinning overrode them.
///
/// What is asserted now is the property that replaced the pin: applying leaves
/// the app resolving from the system, and every palette token has a value for
/// each appearance so nothing falls back to an unmeasured colour.
@Suite("System appearance")
@MainActor
struct AppAppearanceTests {

    /// Runs in `CoreTendApp.init()`, before any scene exists, and must be
    /// repeatable without accumulating state.
    @Test("applying is safe before any window exists, and repeatable")
    func applyIsIdempotent() {
        AppAppearance.apply()
        AppAppearance.apply()
        #expect(NSApplication.shared.appearance == nil,
                "a pinned appearance would override the user's choice of Light or Dark")
    }

    /// The light palette is not the system palette. If these ever match the
    /// AppKit defaults, the owned-appearance decision has quietly been lost.
    @Test("light is CoreTend's own, not the system's")
    func lightIsOwned() {
        #expect(MCPalette.ground.light == 0xF7F8F9)
        #expect(MCPalette.teal.light == 0x0F7A72)
        #expect(MCPalette.ground.light != MCPalette.ground.dark)
    }
}
