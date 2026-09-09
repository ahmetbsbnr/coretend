// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import DeepScanCore

private func cand(_ path: String, category: CleanupCategory = .developer,
                  risk: RiskClass = .review, confidence: Confidence = .probable,
                  bytes: Int64 = 1_000, owner: String? = nil, subcategory: String = "x",
                  activity: Date? = nil, reconstruct: Reconstructability = .regeneratesLocally,
                  defaultSelected: Bool = false, protectedReason: String? = nil) -> CleanupCandidate {
    CleanupCandidate(path: path, canonicalPath: path, category: category, subcategory: subcategory,
        detector: "t", logicalBytes: bytes, allocatedBytes: bytes, estimatedReclaimableBytes: bytes,
        owner: owner, confidence: confidence, risk: risk, recoverability: .trashRestore,
        reconstructability: reconstruct, lastActivity: activity, activeState: .idle,
        evidence: [Evidence(.pathPattern, "matched a pattern")],
        protectedReason: protectedReason, recommendedAction: risk == .protected ? .keep : .review,
        defaultSelected: defaultSelected, rationale: "A \(subcategory)", ifRemoved: "rebuilds")
}

// MARK: - humanized labels

@Test func displayRowHasNoRawEnumNames() {
    let row = DeepScanDisplayRow(cand("/x/.next", risk: .safe, confidence: .strong))
    #expect(row.risk == "Low")
    #expect(row.confidence == "Strong")
    #expect(row.reconstructability == "Rebuilds locally")
    #expect(!row.whyBullets.isEmpty)
    #expect(row.defaultAction == .review)   // safe but not defaultSelected
}

@Test func protectedRowShowsDashReclaimableAndReason() {
    let row = DeepScanDisplayRow(cand("/x/mem", risk: .protected,
        protectedReason: "user memory"))
    #expect(row.estimatedReclaimable == "—")
    #expect(row.isProtected)
    #expect(row.protectedReason == "user memory")
    #expect(row.defaultAction == .keep)
}

// MARK: - filter / sort / page

@Test func filteringByRiskConfidenceCategorySearchSize() {
    let items = [
        cand("/a/.next", category: .developer, risk: .safe, confidence: .strong, bytes: 5_000),
        cand("/b/models", category: .aiAndLLM, risk: .protected, confidence: .unknown, bytes: 9_000, owner: "LM Studio"),
        cand("/c/tmp", category: .temporaryFiles, risk: .review, confidence: .probable, bytes: 100),
    ]
    var m = DeepScanResultsModel(items)
    m.filter.category = .developer
    #expect(m.filteredCount == 1)
    m.filter = DeepScanFilter(); m.filter.reviewableOnly = true
    #expect(m.filteredCount == 2)                       // protected excluded
    m.filter = DeepScanFilter(); m.filter.protectedOnly = true
    #expect(m.filteredCount == 1)
    m.filter = DeepScanFilter(); m.filter.minBytes = 1_000
    #expect(m.filteredCount == 2)
    m.filter = DeepScanFilter(); m.filter.searchText = "lm studio"
    #expect(m.filteredCount == 1)
    m.filter = DeepScanFilter(); m.filter.maxRisk = .review
    #expect(m.filteredCount == 2)                       // safe + review, not protected
}

@Test func sortModesOrderCorrectly() {
    let old = Date(timeIntervalSinceNow: -1_000_000)
    let new = Date(timeIntervalSinceNow: -10)
    let items = [
        cand("/small", risk: .safe, bytes: 10, activity: old),
        cand("/big", risk: .highRisk, bytes: 9_999, activity: new),
    ]
    var m = DeepScanResultsModel(items)
    m.sort = .size
    #expect(m.page(offset: 0, limit: 10).first?.candidate.canonicalPath == "/big")
    m.sort = .risk
    #expect(m.page(offset: 0, limit: 10).first?.candidate.risk == .highRisk)
    m.sort = .lastActivity
    #expect(m.page(offset: 0, limit: 10).first?.candidate.canonicalPath == "/big")
}

@Test func pagingStaysBoundedAtFiftyThousandCandidates() {
    var items: [CleanupCandidate] = []
    items.reserveCapacity(50_000)
    for i in 0..<50_000 {
        items.append(cand("/n/\(i)/file", risk: i % 7 == 0 ? .protected : .review,
                          bytes: Int64(i % 5000)))
    }
    var m = DeepScanResultsModel(items)
    m.filter.reviewableOnly = true
    m.sort = .size
    let t0 = DispatchTime.now().uptimeNanoseconds
    let page = m.page(offset: 400, limit: 200)
    let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
    #expect(page.count == 200)
    #expect(ms < 200)   // filter + sort + slice over 50k stays well under a frame budget * 12
    print("[perf] 50k-candidate filter+sort+page: \(String(format: "%.1f", ms)) ms")
}

// MARK: - grouping

@Test func aiToolGroupingSeparatesToolThenDataType() {
    let items = [
        cand("/lm/models/a", category: .aiAndLLM, risk: .review, bytes: 900,
             owner: "LM Studio", subcategory: AIDataType.modelWeights.rawValue),
        cand("/lm/bin/b", category: .aiAndLLM, risk: .safe, bytes: 100,
             owner: "LM Studio", subcategory: AIDataType.runtimeCache.rawValue),
        cand("/cx/sessions/c", category: .aiAndLLM, risk: .protected, bytes: 50,
             owner: "Codex", subcategory: AIDataType.conversationHistory.rawValue,
             protectedReason: "history"),
    ]
    let groups = DeepScanGrouping.aiTools(items)
    #expect(groups.map(\.tool).sorted() == ["Codex", "LM Studio"])
    let lm = groups.first { $0.tool == "LM Studio" }!
    #expect(lm.buckets.contains { $0.dataType == "Models" })
    #expect(lm.buckets.contains { $0.dataType == "Runtime cache" })
    let cx = groups.first { $0.tool == "Codex" }!
    #expect(cx.buckets.first?.allProtected == true)
}

@Test func categoryGroupsRankByReviewableBytes() {
    let items = [
        cand("/a", category: .developer, risk: .safe, bytes: 10_000),
        cand("/b", category: .cloud, risk: .protected, bytes: 99_999),
        cand("/c", category: .temporaryFiles, risk: .safe, bytes: 20_000),
    ]
    let g = DeepScanGrouping.categories(items)
    #expect(g.first?.category == .temporaryFiles)     // most reviewable bytes
    #expect(g.first { $0.category == .cloud }?.reviewableBytes == 0)
    #expect(g.first { $0.category == .cloud }?.protectedCount == 1)
}

// MARK: - cleanup plan

@Test func cleanupPlanSeparatesProtectedAndSummarizes() {
    let a = cand("/a/.next", risk: .safe, confidence: .strong, bytes: 4_000, reconstruct: .regeneratesLocally)
    let b = cand("/b/node_modules", risk: .review, bytes: 8_000, reconstruct: .networkRedownload)
    let prot = cand("/c/memory", risk: .protected, bytes: 1_000, protectedReason: "user state")
    let plan = DeepScanCleanupPlan.build(selectedIDs: [a.id, b.id, prot.id], from: [a, b, prot])
    #expect(plan.selected.count == 2)
    #expect(plan.protectedHeldBack.count == 1)
    #expect(plan.totalLogicalBytes == 12_000)
    #expect(plan.riskSummary["Low"] == 1)
    #expect(plan.riskSummary["Review"] == 1)
    #expect(plan.rebuildCostSummary["Re-downloads"] == 1)
    #expect(plan.movedToTrash.count == 2)
}

@Test func cleanupPlanFlagsChangedSinceScanFromRevalidation() {
    let a = cand("/a/.next", risk: .safe, confidence: .strong)
    let reval = RevalidationOutcome(
        approvedForExecution: [],
        rejected: [.init(candidate: a, reason: "App is now running")])
    let plan = DeepScanCleanupPlan.build(selectedIDs: [a.id], from: [a], revalidation: reval)
    #expect(plan.changedSinceScan.first?.reason == "App is now running")
    #expect(plan.movedToTrash.isEmpty)
}

// MARK: - progress model

@Test func progressModelReportsRealPhaseOrdinalNotFakePercent() {
    var p = DeepScanProgressModel()
    p.phase = .analyzingGit
    #expect(p.phaseIndex > 0)
    #expect(p.phaseIndex < p.phaseCount)
    p.phase = .cancelledPartial
    #expect(p.isPartial)
}

// MARK: - settings + history

@Test func settingsRoundTripAndTolerantDecode() throws {
    let t = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ds-settings-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: t) }
    var s = DeepScanSettings.default
    s.gitNetworkVerificationEnabled = true
    s.scanExternalVolumes = true
    try s.save(to: t)
    #expect(DeepScanSettings.load(from: t).gitNetworkVerificationEnabled)

    // Missing keys fall back to defaults, not a decode failure.
    try Data(#"{"aiAnalysisEnabled":false}"#.utf8).write(to: t)
    let partial = DeepScanSettings.load(from: t)
    #expect(partial.aiAnalysisEnabled == false)
    #expect(partial.developerAnalysisEnabled == true)
}

@Test func settingsCannotDisableSafetyProtections() {
    // The settings type simply has no such field. Detector set always routes
    // through the same risk model; cloud detector stays protected-only.
    let mirror = Mirror(reflecting: DeepScanSettings.default)
    let names = mirror.children.compactMap { $0.label }
    #expect(!names.contains { $0.lowercased().contains("protection") })
    #expect(!names.contains { $0.lowercased().contains("safety") })
    #expect(!names.contains { $0.lowercased().contains("trash") })
}

@Test func scanHistoryRecordsAndReadsBack() throws {
    let t = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ds-hist-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: t) }
    let idx = try DeepScanIndex(path: t.path)
    try idx.recordScanRun(startedAt: Date(timeIntervalSinceNow: -30), finishedAt: Date(),
        scope: "~ (home)", permissions: "Full Disk Access", nodeCount: 128_000,
        candidateCount: 230, logicalBytes: 9_000_000_000, allocatedBytes: 8_000_000_000,
        partial: false, errorCount: 2)
    let rows = try idx.recentScans(limit: 5)
    #expect(rows.count == 1)
    #expect(rows[0].candidateCount == 230)
    #expect(rows[0].permissions == "Full Disk Access")
    #expect(rows[0].errorCount == 2)
    #expect(rows[0].partial == false)
}
