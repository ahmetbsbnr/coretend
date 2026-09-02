// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import SafetyCore
@testable import FileRules

@Suite("UserCleanupRules")
struct UserCleanupRulesTests {
    @Test func allRulesHaveStableUniqueIDs() {
        let ids = UserCleanupRules.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.contains("user.caches"))
    }

    @Test func noRuleTargetsUserContent() {
        let home = URL(fileURLWithPath: "/Users/testuser")
        let forbidden = PathValidator.userContentRoots(home: home)
        for rule in UserCleanupRules.all {
            for root in rule.roots(home) {
                for banned in forbidden {
                    #expect(!PathValidator.isPath(root.path, under: banned),
                            "\(rule.id) targets user content: \(root.path)")
                }
            }
        }
    }

    @Test func newInstallerAndArchiveRulesAreDownloadsScopedAndOptIn() {
        let home = URL(fileURLWithPath: "/Users/testuser")
        let downloads = home.appendingPathComponent("Downloads").path
        for id in ["user.oldinstallers", "user.oldarchives"] {
            let rule = UserCleanupRules.all.first { $0.id == id }
            #expect(rule != nil, "\(id) missing")
            guard let rule else { continue }
            #expect(rule.preselect == false, "\(id) must never be auto-selected")
            #expect(rule.minimumAgeDays >= 30, "\(id) needs an age threshold")
            #expect(rule.roots(home).allSatisfy { $0.path == downloads },
                    "\(id) must be Downloads-only")
        }
    }

    @Test func installerMatcherOnlyMatchesInstallerExtensions() {
        let rule = UserCleanupRules.oldInstallers
        let base = URL(fileURLWithPath: "/Users/testuser/Downloads")
        #expect(rule.matches?(base.appendingPathComponent("App.dmg")) == true)
        #expect(rule.matches?(base.appendingPathComponent("Tool.PKG")) == true)  // case-insensitive
        #expect(rule.matches?(base.appendingPathComponent("notes.txt")) == false)
        #expect(rule.matches?(base.appendingPathComponent("archive.zip")) == false)
    }

    @Test func archiveMatcherCoversCommonFormatsOnly() {
        let rule = UserCleanupRules.oldArchives
        let base = URL(fileURLWithPath: "/Users/testuser/Downloads")
        for ext in ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar"] {
            #expect(rule.matches?(base.appendingPathComponent("f.\(ext)")) == true, "\(ext) should match")
        }
        #expect(rule.matches?(base.appendingPathComponent("f.dmg")) == false)
        #expect(rule.minimumSizeBytes > 0, "archives need a size floor to skip tiny files")
    }

    @Test func xcodeArchivesRuleIsMediumRiskOptInUnderDeveloper() {
        let home = URL(fileURLWithPath: "/Users/testuser")
        let rule = UserCleanupRules.xcodeArchives
        #expect(rule.preselect == false)
        #expect(rule.risk == .medium)
        #expect(rule.roots(home).first?.path == home.appendingPathComponent("Library/Developer/Xcode/Archives").path)
    }

    @Test func allowedRootsCoverAllRuleRoots() {
        let home = URL(fileURLWithPath: "/Users/testuser")
        let allowed = UserCleanupRules.allowedRoots(home: home).map(\.path)
        for rule in UserCleanupRules.all {
            for root in rule.roots(home) {
                #expect(allowed.contains { PathValidator.isPath(root.path, under: $0) },
                        "\(rule.id) root \(root.path) not covered by deletion allowlist")
            }
        }
    }
}
