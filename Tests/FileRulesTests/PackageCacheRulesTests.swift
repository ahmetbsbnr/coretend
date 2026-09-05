// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
import SafetyCore
@testable import FileRules

@Suite("Package cache rules")
struct PackageCacheRulesTests {
    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ path: String, home: URL, count: Int = 127) throws -> URL {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 42, count: count).write(to: url)
        return url
    }

    private func scan(_ rules: [ScanRule], home: URL, excluded: [String] = []) async -> [ScanFinding] {
        var findings: [ScanFinding] = []
        for await event in ScanEngine(configuration: ScanConfiguration(home: home, excludedPaths: excluded)).run(rules: rules) {
            if case let .finding(finding) = event { findings.append(finding) }
        }
        return findings
    }

    @Test(arguments: PackageCacheRules.all.map(\.id))
    func absentAndEmptyAreNotFindings(ruleID: String) async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let rule = try #require(PackageCacheRules.all.first { $0.id == ruleID })
        #expect(await scan([rule], home: home).isEmpty)
        for root in rule.roots(home) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        #expect(await scan([rule], home: home).isEmpty)
    }

    @Test(arguments: PackageCacheRules.all.map(\.id))
    func presentSizeAndPathSafety(ruleID: String) async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let rule = try #require(PackageCacheRules.all.first { $0.id == ruleID })
        for root in rule.roots(home) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try Data(repeating: 1, count: 127).write(to: root.appendingPathComponent("cache.bin"))
        }
        let found = await scan([rule], home: home)
        #expect(found.count == rule.roots(home).count)
        #expect(found.allSatisfy { $0.logicalSize == 127 && $0.ruleID == rule.id && $0.risk == rule.risk })
        let validator = PathValidator(allowedRoots: rule.roots(home), regularFilesOnly: true)
        for finding in found { #expect(try validator.validate(finding.url).path == finding.url.standardizedFileURL.path) }
        #expect(throws: SafetyError.self) { try validator.validate(home.appendingPathComponent("Documents/secret")) }
    }

    @Test func swiftPMKeepsRepositoriesRegistriesAndConfigurationOutOfEveryCleanupRule() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let cache = try write("Library/Caches/org.swift.swiftpm/manifests/manifest.db", home: home)
        for path in ["Library/Caches/org.swift.swiftpm/repositories/repo/source.swift",
                     "Library/Caches/org.swift.swiftpm/registry/downloads/package.zip",
                     "Library/Caches/org.swift.swiftpm/package-metadata/metadata.db",
                     ".swiftpm/configuration/registries.json", ".swiftpm/security/token", "Project/Package.swift"] {
            _ = try write(path, home: home)
        }
        let found = await scan(UserCleanupRules.all, home: home)
        #expect(found.map { $0.url.standardizedFileURL } == [cache.standardizedFileURL])
        #expect(found.first?.ruleID == PackageCacheRules.swiftPM.id)
    }

    @Test func homebrewNeverTargetsCellarCaskroomTapsOrServices() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let cache = try write("Library/Caches/Homebrew/downloads/bottle.tar.gz", home: home)
        for path in ["Cellar/tool/bin/tool", "Caskroom/App.app/data", "homebrew/Library/Taps/source.rb", "homebrew/etc/config"] {
            _ = try write(path, home: home)
        }
        #expect(await scan([PackageCacheRules.homebrew], home: home).map { $0.url.standardizedFileURL } == [cache.standardizedFileURL])
        #expect(PackageCacheRules.homebrew.roots(home) == [home.appendingPathComponent("Library/Caches/Homebrew")])
    }

    @Test func npmOnlyCacacheNeverConfigOrCredentials() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let cache = try write(".npm/_cacache/content-v2/package", home: home)
        for path in [".npmrc", ".npm/.npmrc", ".npm/token", ".npm/_logs/debug.log", ".npm/_npx/tool/index.js", "Project/node_modules/a/index.js"] {
            _ = try write(path, home: home)
        }
        #expect(await scan([PackageCacheRules.npm], home: home).map { $0.url.standardizedFileURL } == [cache.standardizedFileURL])
    }

    @Test func pnpmKnownStoresExcludeUnknownLayoutsAndVirtualLinks() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let known = try write("Library/pnpm/store/v10/files/ab/content", home: home)
        for path in ["Library/pnpm/store/v10/links/pkg/index.js", "Library/pnpm/store/v11/files/content",
                     "Library/pnpm/store/v99/data", "Library/pnpm/global/tool.js", ".pnpm-store/config.json"] {
            _ = try write(path, home: home)
        }
        #expect(await scan([PackageCacheRules.pnpm], home: home).map { $0.url.standardizedFileURL } == [known.standardizedFileURL])
    }

    @Test func yarnClassicAndBerryAreDisjointAndBerryRequiresReview() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        _ = try write("Library/Caches/Yarn/v6/npm-a/index.js", home: home)
        _ = try write(".yarn/berry/cache/a.zip", home: home)
        for path in ["Project/.yarn/cache/a.zip", ".yarnrc.yml", ".yarn/berry/metadata/a.json", ".yarn/releases/yarn.cjs"] {
            _ = try write(path, home: home)
        }
        let found = await scan([PackageCacheRules.yarn, PackageCacheRules.yarnBerry], home: home)
        #expect(found.count == 2)
        #expect(found.first { $0.ruleID == PackageCacheRules.yarn.id }?.preselected == true)
        #expect(found.first { $0.ruleID == PackageCacheRules.yarnBerry.id }?.preselected == false)
        #expect(PackageCacheRules.yarnBerry.risk == .medium)
    }

    @Test func generalCachesDoNotCountDedicatedRulesTwice() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        for rule in PackageCacheRules.all {
            let root = try #require(rule.roots(home).first)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try Data(repeating: 1, count: 100).write(to: root.appendingPathComponent("entry"))
        }
        let found = await scan(UserCleanupRules.all, home: home)
        #expect(found.count == 6)
        #expect(Set(found.map(\.url)).count == 6)
        #expect(found.reduce(0) { $0 + $1.logicalSize } == 600)
        #expect(!found.contains { $0.ruleID == "user.caches" })
    }

    @Test func rootAndNestedSymlinksAreNeverFollowed() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let project = try write("Project/source.swift", home: home).deletingLastPathComponent()
        let root = try #require(PackageCacheRules.npm.roots(home).first)
        try FileManager.default.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: project)
        #expect(await scan([PackageCacheRules.npm], home: home).isEmpty)
        let brew = try #require(PackageCacheRules.homebrew.roots(home).first)
        try FileManager.default.createDirectory(at: brew, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: brew.appendingPathComponent("nested"), withDestinationURL: project)
        #expect(await scan([PackageCacheRules.homebrew], home: home).isEmpty)
    }

    @Test func exclusionsCanExcludeAnEntireRuleRoot() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        _ = try write(".npm/_cacache/content", home: home)
        #expect(await scan([PackageCacheRules.npm], home: home,
                           excluded: [home.appendingPathComponent(".npm").path]).isEmpty)
    }

    @Test func xcodeArchiveBundleIsOfferedAsACompleteReviewUnit() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let path = "Library/Developer/Xcode/Archives/2026-01-01/Synthetic.xcarchive"
        _ = try write(path + "/Products/Applications/Synthetic.app/Contents/MacOS/Synthetic", home: home)
        _ = try write(path + "/dSYMs/Synthetic.app.dSYM/Contents/Resources/DWARF/Synthetic", home: home)
        let archive = home.appendingPathComponent(path)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-40 * 86400)], ofItemAtPath: archive.path)
        let found = await scan([UserCleanupRules.xcodeArchives], home: home)
        #expect(found.count == 1)
        #expect(found.first?.url.standardizedFileURL.path == archive.standardizedFileURL.path)
        #expect(found.first?.logicalSize == 254)
        #expect(found.first?.preselected == false)
        let sink = PackageAuditSink()
        let result = await CleanupExecution.execute(found, home: home, sink: sink)
        #expect(result.executed.count == 1)
        #expect(!FileManager.default.fileExists(atPath: archive.path))
        #expect(await sink.stages == [.approved, .executed])
    }

    @Test func archiveContainingAnExcludedFileIsNeverPartiallyOffered() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let path = "Library/Developer/Xcode/Archives/Old.xcarchive"
        let protected = try write(path + "/dSYMs/symbols", home: home)
        _ = try write(path + "/Info.plist", home: home)
        let archive = home.appendingPathComponent(path)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-40 * 86400)], ofItemAtPath: archive.path)
        #expect(await scan([UserCleanupRules.xcodeArchives], home: home, excluded: [protected.path]).isEmpty)
        let findings = await scan([UserCleanupRules.xcodeArchives], home: home)
        let result = await CleanupExecution.execute(findings, home: home, excludedPaths: [protected.path])
        #expect(result.executed.isEmpty)
        #expect(try Data(contentsOf: protected).count == 127)
    }

    @Test func cacheDirectorySubstitutionAfterApprovalIsRejectedAtExecution() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let cache = try write(".npm/_cacache/item", home: home)
        let center = SafetyCenter(validator: PathValidator(allowedRoots: PackageCacheRules.npm.roots(home), regularFilesOnly: true))
        let approved = try await center.approve(url: cache, logicalSize: 127, ruleID: PackageCacheRules.npm.id, risk: .low)
        try FileManager.default.moveItem(at: cache, to: cache.appendingPathExtension("saved"))
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let result = await center.execute([approved])
        #expect(result.executed.isEmpty)
        #expect(result.skipped.count == 1)
        #expect(FileManager.default.fileExists(atPath: cache.path))
    }

    @Test func cacheSymlinkSwapAfterApprovalCannotReachAnotherAllowedFile() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let cache = try write(".npm/_cacache/item", home: home)
        let target = try write(".npm/_cacache/other", home: home)
        let center = SafetyCenter(validator: PathValidator(allowedRoots: PackageCacheRules.npm.roots(home), regularFilesOnly: true))
        let approved = try await center.approve(url: cache, logicalSize: 127, ruleID: PackageCacheRules.npm.id, risk: .low)
        try FileManager.default.moveItem(at: cache, to: cache.appendingPathExtension("saved"))
        try FileManager.default.createSymbolicLink(at: cache, withDestinationURL: target)
        #expect(await center.execute([approved]).executed.isEmpty)
        #expect(try Data(contentsOf: target).count == 127)
    }

    @Test func safetyCenterExecutesRealPackageFindingAndPreservesProjectHardLink() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let cache = try write("Library/pnpm/store/v10/files/ab/content", home: home)
        let project = home.appendingPathComponent("Project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let linked = project.appendingPathComponent("linked-package")
        try FileManager.default.linkItem(at: cache, to: linked)
        let found = await scan([PackageCacheRules.pnpm], home: home)
        let sink = PackageAuditSink()
        let result = await CleanupExecution.execute(found, home: home, sink: sink)
        #expect(result.executed.count == 1)
        #expect(result.processedBytes == 127)
        #expect(!FileManager.default.fileExists(atPath: cache.path))
        #expect(try Data(contentsOf: linked).count == 127)
        #expect(await sink.stages == [.approved, .executed])
    }

    @Test func executionRejectsSpoofedRuleAndNewExclusion() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let cache = try write(".npm/_cacache/content", home: home)
        let found = await scan([PackageCacheRules.npm], home: home)
        #expect(await CleanupExecution.execute(found, home: home, excludedPaths: [cache.path]).executed.isEmpty)
        let source = try write("Project/source.swift", home: home)
        let spoof = ScanFinding(url: source, logicalSize: 127, allocatedSize: nil, modificationDate: nil,
                                ruleID: PackageCacheRules.npm.id, category: "Cleanup", explanation: "",
                                confidence: 0.9, risk: .low, preselected: true)
        #expect(await CleanupExecution.execute([spoof], home: home).executed.isEmpty)
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: cache.path))
    }
}

private actor PackageAuditSink: SafetyAuditSink {
    var stages: [SafetyAuditEvent.Stage] = []
    func recordSafetyEvent(_ event: SafetyAuditEvent) { stages.append(event.stage) }
}
