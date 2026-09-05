// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Testing
import Foundation
import ScanCore
import FileRules
import AppDiscovery
import SystemMetrics
import Persistence
@testable import CoreTendApp

@Suite("Developer Center integration")
struct DeveloperCenterTests {
    private func fixture() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    private func write(_ path: String, home: URL, count: Int = 100) throws -> URL {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 42, count: count).write(to: url)
        return url
    }

    @Test(arguments: PackageCacheRules.all.map(\.id))
    func everyPackageRuleHasExplicitAdvisorAndLocalizedConsequences(ruleID: String) throws {
        let rule = try #require(PackageCacheRules.all.first { $0.id == ruleID })
        let finding = ScanFinding(url: URL(fileURLWithPath: "/fixture/cache"), logicalSize: 1234, allocatedSize: nil,
            modificationDate: nil, ruleID: ruleID, category: "Cleanup", explanation: "", confidence: 0.9,
            risk: rule.risk, preselected: rule.preselect)
        let advisor = AdvisorService.advise(ruleID: ruleID, findings: [finding])
        #expect(advisor.risk == rule.risk)
        #expect(advisor.confidence == .high)
        #expect(advisor.reversibility == .trash)
        #expect(advisor.reclaimableBytes == 1234)
        #expect(advisor.category == .cleanup)
        #expect(!advisor.consequence.isEmpty && !advisor.consequence.hasPrefix("advisor."))
        #expect(advisor.consequence == L("advisor.cleanup.\(ruleID).consequence"))
        #expect(advisor.title == L("timeline.category.cleanup.\(ruleID)"))
        for language: AppLanguage in [.en, .fr] {
            for key in ["timeline.category.cleanup.\(ruleID)"] + ["summary", "reason", "consequence"].map({ "advisor.cleanup.\(ruleID).\($0)" }) {
                let text = LocalizationManager.string(forKey: key, language: language)
                #expect(!text.isEmpty && text != key)
            }
        }
    }

    @Test func packageCachesEnterRecoveryOnceAndReadOnlyStorageNeverDoes() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        for rule in PackageCacheRules.all {
            let root = try #require(rule.roots(home).first)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try Data(repeating: 1, count: 100).write(to: root.appendingPathComponent("cache"))
        }
        _ = try write(DeveloperStorageInspector.simulatorPath + "/synthetic/data", home: home, count: 5000)
        _ = try write(DeveloperStorageInspector.dockerDiskPaths[0], home: home, count: 9000)
        let candidates = await RecoveryPlanService.cleanupCandidates(home: home, store: nil)
        let packages = candidates.filter { $0.candidate.finding.source.hasPrefix("dev.cache.") }
        #expect(packages.count == 6)
        for data in packages {
            #expect(data.candidate.category == (data.candidate.finding.source == PackageCacheRules.yarnBerry.id ? .optional : .recommended))
            #expect(data.candidate.finding.reversibility == .trash)
        }
        let plan = RecoveryPlanBuilder.build(candidates: candidates.map(\.candidate), goal: RecoveryGoal(bytes: 100_000))
        #expect(plan.section(.recommended).candidates.reduce(0) { $0 + $1.reclaimableBytes } == 500)
        #expect(plan.section(.optional).candidates.reduce(0) { $0 + $1.reclaimableBytes } == 100)
        #expect(plan.preselectedIDs.count == 5)
        #expect(!candidates.contains { $0.candidate.id.localizedCaseInsensitiveContains("docker") || $0.candidate.id.localizedCaseInsensitiveContains("simulator") })
        let snapshot = try #require(await DeveloperCenterService.scan(home: home, applicationRoots: [], excludedPaths: []))
        #expect(snapshot.potentiallyRecoverableBytes == 600)
        #expect(snapshot.simulators.logicalBytes == 5000)
        #expect(snapshot.docker.disks[0].logicalBytes == 9000)
        #expect(Set(snapshot.groups.map { $0.advisor.id }).isSubset(of: Set(candidates.map { $0.candidate.id })))
    }

    @Test func swiftPMLeftoverOverlapIsExplicitAndConservative() {
        let home = URL(fileURLWithPath: "/fixture")
        let overlapping = AssociatedItem(kind: .caches, url: home.appendingPathComponent("Library/Caches/org.swift.swiftpm"), sizeBytes: 1000)
        #expect(RecoveryPlanService.overlapsPackageCaches(items: [overlapping], home: home))
        let advisor = AdvisorService.advise(leftovers: [overlapping], isAmbiguous: false)
        let eligibility = RecoveryPlanEligibility.evaluate(advisor, overlapsAnotherSource: true)
        #expect(eligibility.category == .notIncluded)
        #expect(eligibility.exclusionReason == .overlapsAnotherSource)
        let unrelated = AssociatedItem(kind: .caches, url: home.appendingPathComponent("Library/Caches/org.example.app"), sizeBytes: 1000)
        #expect(!RecoveryPlanService.overlapsPackageCaches(items: [unrelated], home: home))
    }

    @Test func scanCapOnlyTotalsRetainedActionableFiles() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        for i in 0..<5 { _ = try write(".npm/_cacache/\(i)", home: home) }
        let snapshot = try #require(await DeveloperCenterService.scan(home: home, applicationRoots: [], excludedPaths: [], limit: 2))
        #expect(snapshot.omittedCount == 3)
        #expect(snapshot.potentiallyRecoverableBytes == 200)
        #expect(snapshot.groups.flatMap(\.findings).count == 2)
    }

    @Test func failedRulePublishesNoPartialActionableBytes() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        _ = try write(".npm/_cacache/ok", home: home)
        let denied = try write(".npm/_cacache/denied/hidden", home: home).deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: denied.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: denied.path) }
        let snapshot = try #require(await DeveloperCenterService.scan(home: home, applicationRoots: [], excludedPaths: []))
        #expect(snapshot.failedRuleIDs.contains(PackageCacheRules.npm.id))
        #expect(snapshot.potentiallyRecoverableBytes == 0)
    }

    @Test func emptyStatesDoNotInventInstalledProductsOrZeroMeasurements() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let snapshot = try #require(await DeveloperCenterService.scan(home: home, applicationRoots: [home.appendingPathComponent("Applications")], excludedPaths: []))
        #expect(snapshot.xcode == .absent)
        #expect(snapshot.rootStates.values.allSatisfy { $0 == .absent })
        #expect(snapshot.failedRuleIDs.isEmpty)
        #expect(snapshot.simulators.logicalBytes == nil)
        #expect(snapshot.docker.availability == .absent)
    }

    @Test @MainActor func sessionCacheAndRefreshAvoidRepeatedScansAndMediumPreselection() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        _ = try write(".npm/_cacache/a", home: home)
        _ = try write(".yarn/berry/cache/a.zip", home: home)
        let model = DeveloperCenterModel(home: home, applicationRoots: [], store: nil)
        await model.loadIfNeeded()
        let date = try #require(model.snapshot?.date)
        #expect(model.selectedBytes == 100)
        #expect(model.selectedFindings.allSatisfy { $0.risk == .low })
        _ = try write(".npm/_cacache/b", home: home)
        await model.loadIfNeeded()
        #expect(model.snapshot?.date == date)
        #expect(model.selectedBytes == 100)
        await model.refresh()
        #expect(model.selectedBytes == 200)
        #expect(model.snapshot?.date != date)
    }

    @Test @MainActor func developerSelectionExecutesThroughSharedCleanupAndJournal() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let store = try Store(path: home.appendingPathComponent("test.sqlite").path)
        let cache = try write(".npm/_cacache/content", home: home)
        let config = try write(".npmrc", home: home)
        let simulator = try write(DeveloperStorageInspector.simulatorPath + "/synthetic/data", home: home)
        let docker = try write(DeveloperStorageInspector.dockerDiskPaths[0], home: home)
        let model = DeveloperCenterModel(home: home, applicationRoots: [], store: store)
        await model.loadIfNeeded()
        #expect(model.selectedFindings.count == 1)
        await model.executeSelection()
        #expect(model.executionResult?.executed.count == 1)
        #expect(model.executionResult?.processedBytes == 100)
        #expect(!FileManager.default.fileExists(atPath: cache.path))
        for url in [config, simulator, docker] { #expect(try Data(contentsOf: url).count == 100) }
        let activity = try await store.activity(limit: 10)
        #expect(activity.contains { $0.kind == .cleanup && $0.bytes == 100 })
        let journal = try await store.safetyLog()
        #expect(journal.count == 2, "durable approval and terminal execution events")
        #expect(try await store.timelineSnapshots().isEmpty, "a Developer-only scan must not masquerade as a full Cleanup snapshot")
        await model.executeSelection()
        #expect(model.executionResult?.executed.count == 1, "cannot execute the stale snapshot a second time")
    }

    @Test @MainActor func cancellationDoesNotPublishPartialSnapshot() async throws {
        let home = try fixture()
        defer { try? FileManager.default.removeItem(at: home) }
        let model = DeveloperCenterModel(home: home, applicationRoots: [], store: nil)
        let task = Task { await model.refresh() }
        task.cancel()
        await task.value
        #expect(model.snapshot == nil)
        #expect(model.phase == .idle)
    }

    @Test func developerIsReachableAndInspectionLabelsLocalize() {
        #expect(SidebarGroup.visibleModules.filter { $0 == .developer }.count == 1)
        #expect(!ModuleID.developer.systemImage.isEmpty)
        for language: AppLanguage in [.en, .fr] {
            for key in ["module.developer", "developer.title", "developer.inspection_only", "developer.review_required",
                        "developer.regenerable", "developer.simulator.unavailable", "developer.docker.unavailable",
                        "developer.state.absent", "developer.state.unavailable", "developer.confirm"] {
                #expect(LocalizationManager.string(forKey: key, language: language) != key)
            }
        }
    }

    @Test func shippedEnglishAndFrenchCataloguesHaveExactKeyParity() throws {
        func table(_ language: AppLanguage) throws -> [String: String] {
            let bundle = try #require(LocalizationManager.bundle(for: language))
            let url = try #require(bundle.url(forResource: "Localizable", withExtension: "strings"))
            return try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        }
        let english = try table(.en), french = try table(.fr)
        #expect(Set(english.keys) == Set(french.keys))
        let developerKeys = english.keys.filter { $0.hasPrefix("developer.") || $0.contains("dev.cache.") }
        #expect(developerKeys.count > 60)
        for key in developerKeys {
            #expect(english[key]?.isEmpty == false && french[key]?.isEmpty == false)
            let formatPattern = /%[0-9$.*]*[df@]/
            #expect(english[key]!.matches(of: formatPattern).map { String($0.output) }
                    == french[key]!.matches(of: formatPattern).map { String($0.output) })
        }
    }

    @Test func noCleanupRuleCanTargetSimulatorOrDockerStorage() {
        let home = URL(fileURLWithPath: "/fixture")
        let inspectionRoots = [home.appendingPathComponent(DeveloperStorageInspector.simulatorPath),
                               home.appendingPathComponent("Library/Containers/com.docker.docker")]
        for rule in UserCleanupRules.all {
            for root in rule.roots(home) {
                for inspection in inspectionRoots {
                    #expect(!root.path.hasPrefix(inspection.path) && !inspection.path.hasPrefix(root.path))
                }
            }
        }
    }
}
