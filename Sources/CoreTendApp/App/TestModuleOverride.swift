// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

// Test-mode module override; inert unless CORETEND_TEST_MODE is set.

import SwiftUI
import DesignSystem
import SystemMetrics
import Persistence

enum TestModuleOverride {
    static func resolve(environment: [String: String]) -> ModuleID? {
        guard TestStoreOverride.isTestMarkerSet(environment: environment),
              TestStoreOverride.resolve(environment: environment).directory != nil,
              let raw = environment["CORETEND_TEST_MODULE"]?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }
        return ModuleID(testIdentifier: raw)
    }
}
