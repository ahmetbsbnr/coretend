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
