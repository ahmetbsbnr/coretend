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

@Suite("Artifact appearance override isolation")
struct TestAppearanceOverrideTests {
    @Test("validated test mode maps light and dark without changing normal settings")
    func validTestModeMapsAppearances() {
        let root = "/tmp/coretend-appearance-\(UUID().uuidString)"
        for (value, expected) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let result = TestAppearanceOverride.resolve(environment: [
                "CORETEND_TEST_MODE": "1",
                "CORETEND_TEST_STORE_DIR": root,
                "CORETEND_TEST_APPEARANCE": value,
            ])
            #expect(result == expected)
        }
    }

    @Test("an invalid test store cannot force application appearance")
    func invalidTestStoreCannotOverrideAppearance() {
        #expect(TestAppearanceOverride.resolve(environment: [
            "CORETEND_TEST_MODE": "1",
            "CORETEND_TEST_STORE_DIR": "/Applications/not-a-test-store",
            "CORETEND_TEST_APPEARANCE": "light",
        ]) == nil)
    }

    @Test("normal launches always leave appearance under system control")
    func normalLaunchDoesNotOverrideAppearance() {
        #expect(TestAppearanceOverride.resolve(environment: [
            "CORETEND_TEST_APPEARANCE": "dark",
        ]) == nil)
    }
}
