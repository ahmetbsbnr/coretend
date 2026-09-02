// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

enum AppMetadata {
    static var marketingVersion: String {
        value(for: "CoreTendMarketingVersion")
            ?? value(for: "CFBundleShortVersionString")
            ?? "unknown"
    }

    static var bundleVersion: String {
        value(for: "CFBundleVersion") ?? "unknown"
    }

    private static func value(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
