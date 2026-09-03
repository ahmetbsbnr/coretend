// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import Persistence

@Suite("CoreTend isolated integration environment")
struct IsolatedEnvironmentTests {
    @Test func testStoreOverrideNeverFallsBackToUserDataInTestMode() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("coretend-integration-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        setenv(TestStoreOverride.markerKey, "1", 1)
        setenv(TestStoreOverride.pathKey, root.path, 1)
        defer {
            unsetenv(TestStoreOverride.markerKey)
            unsetenv(TestStoreOverride.pathKey)
        }

        let resolved = try #require(TestStoreOverride.current.directory)
        #expect(resolved.standardizedFileURL == root.standardizedFileURL)
        #expect(!resolved.path.contains(NSHomeDirectory()))
    }
}
