// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

@Suite("Integrity test-data isolation")
struct IntegrityIsolationTests {
    @Test("test mode resolves every scan under the validated temporary store")
    func testModeUsesOnlyTemporaryFixtures() throws {
        let temporaryRoot = "/tmp/coretend-integrity-fixtures-\(UUID().uuidString)"
        let locations = IntegrityScanLocations.resolve(environment: [
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": temporaryRoot,
        ])

        let downloads = try #require(locations.downloads)
        #expect(downloads.path == temporaryRoot + "/IntegrityFixtures/Downloads")
        #expect(locations.loginItems.count == 3)
        #expect(locations.loginItems.allSatisfy { $0.0.path.hasPrefix(temporaryRoot + "/IntegrityFixtures/") })
    }

    @Test("an invalid test override reads nothing and never falls back to personal data")
    func invalidTestOverrideFailsClosed() {
        let locations = IntegrityScanLocations.resolve(environment: [
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": "/Applications/not-a-test-store",
        ])

        #expect(locations.downloads == nil)
        #expect(locations.loginItems.isEmpty)
    }

    @Test("a normal launch keeps the real macOS locations")
    func normalLaunchUsesSuppliedHomeAndSystemLocations() throws {
        let home = URL(fileURLWithPath: "/tmp/coretend-normal-home", isDirectory: true)
        let locations = IntegrityScanLocations.resolve(environment: [:], home: home)

        #expect(try #require(locations.downloads).path == "/tmp/coretend-normal-home/Downloads")
        #expect(locations.loginItems.map { $0.0.path } == [
            "/tmp/coretend-normal-home/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
        ])
    }
}
