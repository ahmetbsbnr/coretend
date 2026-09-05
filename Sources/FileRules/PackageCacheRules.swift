// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import ScanCore
import SafetyCore

/// Fixed, user-domain cache locations only. Never reads manager configuration,
/// credentials, projects or subprocess output. Custom stores are unsupported.
public enum PackageCacheRules {
    public static let swiftPM = cache("dev.cache.swiftpm", "SwiftPM cache", paths: [
        "Library/Caches/org.swift.swiftpm/manifests",
        "Library/Caches/org.swift.swiftpm/artifacts",
    ])
    public static let homebrew = cache("dev.cache.homebrew", "Homebrew cache", paths: ["Library/Caches/Homebrew"])
    public static let npm = cache("dev.cache.npm", "npm cache", paths: [".npm/_cacache"])
    // Explicit versions: never walk an unknown layout or the global virtual
    // store's links/projects directories. v3 indices live within files/.
    public static let pnpm = cache("dev.cache.pnpm", "pnpm content store", paths:
        ["Library/pnpm/store", ".pnpm-store"].flatMap { root in
            ["v3/files", "v10/files", "v10/index"].map { "\(root)/\($0)" }
        })
    public static let yarn = cache("dev.cache.yarn", "Yarn Classic cache", paths: ["Library/Caches/Yarn"])
    // PnP loads ZIPs directly: regenerable does not imply harmless to running
    // projects. Separate risk and review policy from Classic's download cache.
    public static let yarnBerry = cache("dev.cache.yarn.berry", "Yarn Berry global cache",
                                       paths: [".yarn/berry/cache"], risk: .medium)

    public static let all = [swiftPM, homebrew, npm, pnpm, yarn, yarnBerry]

    /// Reserve the entire SwiftPM namespace, including its repositories and
    /// metadata, so user.caches cannot accidentally offer the excluded data.
    public static func reservedCacheRoots(home: URL) -> [URL] {
        ["Library/Caches/org.swift.swiftpm", "Library/Caches/Homebrew", "Library/Caches/Yarn"].map {
            home.appendingPathComponent($0)
        }
    }

    private static func cache(_ id: String, _ name: String, paths: [String], risk: RiskLevel = .low) -> ScanRule {
        ScanRule(id: id, name: name, category: "Cleanup",
                 explanation: "Regenerable package cache in supported default locations. Downloads or installs may be needed again.",
                 risk: risk, preselect: risk == .low, minimumSizeBytes: 1) { home in
            paths.map { home.appendingPathComponent($0) }
        }
    }
}
