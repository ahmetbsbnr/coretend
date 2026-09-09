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
    static var buildNumber: String { bundleVersion }

    /// "beta" for a marketing version carrying a prerelease label, else "stable".
    static var releaseChannel: String {
        marketingVersion.contains("-") ? "beta" : "stable"
    }

    private static func value(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
