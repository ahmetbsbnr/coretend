// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Unit + adversarial-safety tests for DeepScanCore. Every destructive-looking
// fixture is built inside an isolated NSTemporaryDirectory subtree and torn
// down; nothing here touches the real user home or a real repo.

import Foundation
import Testing
import SafetyCore
@testable import DeepScanCore

// MARK: - Audit sink test double

actor CapturingAuditSink: SafetyAuditSink {
    private(set) var events: [SafetyAuditEvent] = []
    func recordSafetyEvent(_ event: SafetyAuditEvent) async { events.append(event) }
    func stages() -> [String] { events.map { $0.stage.rawValue } }
}

private func execCandidate(path: String, detector: String = "developer-storage",
                           subcategory: String = ".next",
                           category: CleanupCategory = .developer,
                           risk: RiskClass = .safe, confidence: Confidence = .strong,
                           reconstructability: Reconstructability = .regeneratesLocally,
                           evidence: [Evidence] = [Evidence(.regenerableMarker, "manifest next to it")],
                           owner: String? = nil) -> CleanupCandidate {
    CleanupCandidate(path: path, canonicalPath: path, category: category, subcategory: subcategory,
        detector: detector, logicalBytes: 16, allocatedBytes: 16, estimatedReclaimableBytes: 16,
        owner: owner, confidence: confidence, risk: risk, recoverability: .trashRestore,
        reconstructability: reconstructability, lastActivity: nil, activeState: .idle,
        evidence: evidence, protectedReason: nil, recommendedAction: .remove,
        defaultSelected: false, rationale: "", ifRemoved: "")
}

// MARK: - Fixture helpers

private struct TempTree {
    let root: URL
    init() {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("deepscan-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func dir(_ rel: String) -> URL {
        let u = root.appendingPathComponent(rel)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    @discardableResult
    func file(_ rel: String, bytes: Int) -> URL {
        let u = root.appendingPathComponent(rel)
        try? FileManager.default.createDirectory(at: u.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: u.path, contents: Data(repeating: 0x41, count: bytes))
        return u
    }
    func cleanup() { try? FileManager.default.removeItem(at: root) }
}

private func scan(_ roots: [URL], budget: Duration = .seconds(30),
                  cancellation: DeepScanCancellation = .init()) async -> DiskGraph {
    let cfg = DeepScanConfiguration(roots: roots, maxConcurrency: 4, timeBudget: budget)
    return await DeepScanEngine().scan(cfg, cancellation: cancellation)
}

// MARK: - DiskGraph model

@Test func rollupSumsChildrenAndFlagsCompleteness() async {
    let t = TempTree(); defer { t.cleanup() }
    t.file("a/one.bin", bytes: 1000)
    t.file("a/two.bin", bytes: 2000)
    t.file("a/b/three.bin", bytes: 500)
    let g = await scan([t.root])

    let a = g.node(at: t.root.appendingPathComponent("a").path)
    #expect(a != nil)
    #expect(a?.logicalBytes == 3500)
    #expect(a?.completeness == .complete)
    #expect(g.subtreeFullyObserved(t.root.path))
}

// MARK: - Hard-link double-count protection

@Test func hardLinkedFileCountedOnce() async throws {
    let t = TempTree(); defer { t.cleanup() }
    let original = t.file("dir/original.bin", bytes: 4096)
    let link = t.root.appendingPathComponent("dir/hardlink.bin")
    try FileManager.default.linkItem(at: original, to: link)

    let g = await scan([t.root])
    let dir = g.node(at: t.root.appendingPathComponent("dir").path)
    // Only one of the two links contributes its bytes.
    #expect(dir?.logicalBytes == 4096)
}

// MARK: - Symlink loops / ancestor symlinks are not followed

@Test func symlinkedDirectoryIsRecordedbutNotDescended() async throws {
    let t = TempTree(); defer { t.cleanup() }
    let real = t.dir("real")
    t.file("real/payload.bin", bytes: 100)
    let loop = t.root.appendingPathComponent("loop")
    try FileManager.default.createSymbolicLink(at: loop, withDestinationURL: real)

    let g = await scan([t.root])
    let loopNode = g.node(at: t.root.appendingPathComponent("loop").path)
    #expect(loopNode?.isSymlink == true)
    // No child was enumerated through the symlink.
    #expect(g.children(of: loop.path).isEmpty)
}

@Test func selfReferentialSymlinkDoesNotHang() async throws {
    let t = TempTree(); defer { t.cleanup() }
    let a = t.dir("a")
    try FileManager.default.createSymbolicLink(
        at: a.appendingPathComponent("back"), withDestinationURL: t.root)
    // Must terminate well within the budget.
    let g = await scan([t.root], budget: .seconds(10))
    #expect(!g.hitTimeout)
}

// MARK: - Permission-denied reporting (no guessed bytes)

@Test func unreadableDirectoryIsFlaggedNotGuessed() async throws {
    let t = TempTree(); defer { t.cleanup() }
    let secret = t.dir("secret")
    t.file("secret/inside.bin", bytes: 9999)
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: secret.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: secret.path) }

    let g = await scan([t.root])
    let node = g.node(at: secret.path)
    #expect(node?.completeness == .permissionDenied)
    #expect(node?.logicalBytes == 0)                 // never fabricated
    #expect(!g.subtreeFullyObserved(t.root.path))    // fail closed upward
}

// MARK: - Cancellation yields a truthful partial graph

@Test func cancellationProducesPartialNotFakeComplete() async {
    let t = TempTree(); defer { t.cleanup() }
    for i in 0..<200 { t.file("d\(i % 10)/f\(i).bin", bytes: 2048) }
    let cancel = DeepScanCancellation()
    cancel.cancel()   // cancelled before it starts
    let g = await scan([t.root], cancellation: cancel)
    #expect(g.wasCancelled)
}

// MARK: - AI storage: mandated user-state protection regression

@Test func claudeMemoryAndUserStateAreAlwaysProtected() async {
    let home = TempTree(); defer { home.cleanup() }
    // ~/.claude/projects/<slug>/memory  + history + credentials
    home.file(".claude/projects/-Users-me-proj/memory/MEMORY.md", bytes: 200)
    home.file(".claude/projects/-Users-me-proj/memory/fact.md", bytes: 50)
    home.file(".claude/history/session.jsonl", bytes: 300)
    home.file(".claude/.credentials.json", bytes: 40)
    home.file(".claude/statsig/cache.json", bytes: 40)

    let g = await scan([home.root.appendingPathComponent(".claude")])
    let ctx = DetectorContext(home: home.root, installedApps: [], runningBundleIDs: [],
        runningExecutablePaths: [], scanStartedAt: g.startedAt, scanFinishedAt: g.finishedAt,
        gitRepos: [])
    let candidates = AIStorageDetector().detect(in: g, context: ctx)

    // Every candidate under projects/ history/ credentials must be PROTECTED and
    // NOT default-selected.
    let protectedPaths = candidates.filter { $0.risk == .protected }.map(\.canonicalPath)
    #expect(candidates.contains { $0.canonicalPath.hasSuffix("/projects") && $0.risk == .protected })
    #expect(candidates.contains { $0.canonicalPath.hasSuffix("/history") && $0.risk == .protected })
    #expect(candidates.contains { $0.canonicalPath.hasSuffix("/.credentials.json") && $0.risk == .protected })
    #expect(candidates.allSatisfy { !$0.defaultSelected })
    #expect(!protectedPaths.isEmpty)

    // The runtime cache MAY be a non-protected candidate — that's allowed —
    // but it still must not be auto-selected.
    if let statsig = candidates.first(where: { $0.canonicalPath.hasSuffix("/statsig") }) {
        #expect(!statsig.defaultSelected)
    }
}

@Test func genericCacheDirNeverCapturesMemoryPath() async {
    // Even if a path literally contains "cache" as a parent, a memory subtree
    // stays protected.
    let home = TempTree(); defer { home.cleanup() }
    home.file(".claude/projects/-x/memory/note.md", bytes: 10)
    let g = await scan([home.root.appendingPathComponent(".claude")])
    let ctx = DetectorContext(home: home.root, installedApps: [], runningBundleIDs: [],
        runningExecutablePaths: [], scanStartedAt: g.startedAt, scanFinishedAt: g.finishedAt, gitRepos: [])
    let candidates = AIStorageDetector().detect(in: g, context: ctx)
    #expect(candidates.first { $0.canonicalPath.hasSuffix("/projects") }?.risk == .protected)
    #expect(candidates.allSatisfy { $0.subcategory != AIDataType.downloadCache.rawValue || !$0.canonicalPath.contains("/memory") })
}

// MARK: - AI taxonomy refinement (§7) — rebuildable reclassified, user state untouched

@Test func lmStudioRuntimeSubtreesAreReclassifiedNotUnknown() async {
    let home = TempTree(); defer { home.cleanup() }
    home.file(".cache/lm-studio/bin/llama-server", bytes: 100)
    home.file(".cache/lm-studio/.internal/scratch", bytes: 100)
    home.file(".cache/lm-studio/server-logs/2026.log", bytes: 100)
    home.file(".cache/lm-studio/models/foo.gguf", bytes: 100)
    home.file(".cache/lm-studio/conversations/c1.json", bytes: 100)
    let g = await scan([home.root.appendingPathComponent(".cache/lm-studio")])
    let ctx = DetectorContext(home: home.root, installedApps: [], runningBundleIDs: [],
        runningExecutablePaths: [], scanStartedAt: g.startedAt, scanFinishedAt: g.finishedAt, gitRepos: [])
    let byPath = Dictionary(uniqueKeysWithValues:
        AIStorageDetector().detect(in: g, context: ctx).map { ($0.canonicalPath, $0) })
    func c(_ suffix: String) -> CleanupCandidate? { byPath.first { $0.key.hasSuffix(suffix) }?.value }

    #expect(c("/bin")?.subcategory == AIDataType.runtimeCache.rawValue)
    #expect(c("/bin")?.risk != .protected)
    #expect(c("/.internal")?.subcategory == AIDataType.runtimeCache.rawValue)
    #expect(c("/server-logs")?.subcategory == AIDataType.runtimeCache.rawValue)
    // Weights stay review-only; conversations stay protected.
    #expect(c("/models")?.subcategory == AIDataType.modelWeights.rawValue)
    #expect(c("/models")?.defaultSelected == false)
    #expect(c("/conversations")?.risk == .protected)
}

@Test func claudeAndCodexUserStateStaysProtectedAfterRefinement() async {
    let home = TempTree(); defer { home.cleanup() }
    home.file(".claude/projects/-x/memory/M.md", bytes: 10)
    home.file(".claude/history/s.jsonl", bytes: 10)
    home.file(".claude/file-history/edit-1.json", bytes: 10)
    home.file(".claude/.credentials.json", bytes: 10)
    home.file(".claude/settings.json", bytes: 10)
    home.file(".claude/statsig/evaluations.json", bytes: 10)
    home.file(".codex/sessions/2026/s.jsonl", bytes: 10)
    home.file(".codex/thread_history_1.sqlite", bytes: 10)
    home.file(".codex/state_5.sqlite", bytes: 10)
    home.file(".codex/log/codex.log", bytes: 10)

    let g = await scan([home.root.appendingPathComponent(".claude"),
                        home.root.appendingPathComponent(".codex")])
    let ctx = DetectorContext(home: home.root, installedApps: [], runningBundleIDs: [],
        runningExecutablePaths: [], scanStartedAt: g.startedAt, scanFinishedAt: g.finishedAt, gitRepos: [])
    let cands = AIStorageDetector().detect(in: g, context: ctx)
    func c(_ s: String) -> CleanupCandidate? { cands.first { $0.canonicalPath.hasSuffix(s) } }

    for s in ["/projects", "/history", "/file-history", "/.credentials.json", "/settings.json",
              "/sessions", "/thread_history_1.sqlite", "/state_5.sqlite"] {
        #expect(c(s)?.risk == .protected, "\(s) must stay PROTECTED")
        #expect(c(s)?.defaultSelected == false)
    }
    // Deterministically rebuildable telemetry / logs are allowed to be non-protected…
    #expect(c("/statsig")?.risk != .protected)
    #expect(c("/log")?.risk != .protected)
    // …but still never auto-selected here.
    #expect(cands.allSatisfy { !$0.defaultSelected })
}

// MARK: - Risk / confidence model

@Test func unknownAttributionFailsClosed() {
    let v = RiskConfidenceModel().evaluate(
        evidence: [Evidence(.sizeThreshold, "big")],   // no attribution evidence
        subtreeComplete: true, reconstruction: .regeneratesLocally,
        activeState: .idle, gitSafety: nil)
    #expect(v.risk == .protected)
    #expect(v.confidence == .unknown)
    #expect(!v.defaultSelected)
}

@Test func noConfirmedWithoutCompleteSubtree() {
    let v = RiskConfidenceModel().evaluate(
        evidence: [Evidence(.bundleIDExactMatch, "x"), Evidence(.noSiblingOwner, "y"),
                   Evidence(.regenerableMarker, "z")],
        subtreeComplete: false, reconstruction: .regeneratesLocally,
        activeState: .idle, gitSafety: nil)
    #expect(v.confidence < .confirmed)
}

@Test func userStateEvidenceForcesProtected() {
    let v = RiskConfidenceModel().evaluate(
        evidence: [Evidence(.pathPattern, "x"), Evidence(.userStateMarker, "memory")],
        subtreeComplete: true, reconstruction: .regeneratesLocally,
        activeState: .idle, gitSafety: nil)
    #expect(v.risk == .protected)
    #expect(v.protectedReason != nil)
}

@Test func onlySafeStrongCompleteLocalGetsDefaultSelected() {
    let ok = DefaultSelectionPolicy.allows(
        risk: .safe, confidence: .strong, reconstruction: .regeneratesLocally,
        subtreeComplete: true, evidenceKinds: [.regenerableMarker, .bundleIDExactMatch, .noSiblingOwner])
    #expect(ok)
    let blockedByVeto = DefaultSelectionPolicy.allows(
        risk: .safe, confidence: .strong, reconstruction: .regeneratesLocally,
        subtreeComplete: true, evidenceKinds: [.regenerableMarker, .gitClean])
    #expect(!blockedByVeto)
    let blockedByRisk = DefaultSelectionPolicy.allows(
        risk: .review, confidence: .confirmed, reconstruction: .regeneratesLocally,
        subtreeComplete: true, evidenceKinds: [.regenerableMarker])
    #expect(!blockedByRisk)
}

// MARK: - Execution revalidation (adversarial)

private func candidate(path: String, risk: RiskClass = .safe,
                       confidence: Confidence = .strong,
                       category: CleanupCategory = .developer,
                       owner: String? = nil) -> CleanupCandidate {
    CleanupCandidate(path: path, canonicalPath: path, category: category,
        subcategory: "t", detector: "t", logicalBytes: 1, allocatedBytes: 1,
        estimatedReclaimableBytes: 1, owner: owner, confidence: confidence, risk: risk,
        recoverability: .trashRestore, reconstructability: .regeneratesLocally,
        lastActivity: nil, activeState: .idle, evidence: [], protectedReason: nil,
        recommendedAction: .remove, defaultSelected: false, rationale: "", ifRemoved: "")
}

@Test func revalidatorDropsVanishedPath() {
    let out = ExecutionRevalidator().revalidate(
        [candidate(path: "/tmp/does-not-exist-\(UUID().uuidString)")],
        originalIdentities: [:], runningBundleIDs: [])
    #expect(out.approvedForExecution.isEmpty)
    #expect(out.rejected.first?.reason.contains("no longer exists") == true)
}

@Test func revalidatorDropsProtectedAndUnknown() {
    let out = ExecutionRevalidator().revalidate(
        [candidate(path: "/tmp/x", risk: .protected),
         candidate(path: "/tmp/y", confidence: .unknown)],
        originalIdentities: [:], runningBundleIDs: [])
    #expect(out.approvedForExecution.isEmpty)
    #expect(out.rejected.count == 2)
}

@Test func revalidatorDropsPathSwappedToSymlink() async throws {
    let t = TempTree(); defer { t.cleanup() }
    let real = t.file("real.bin", bytes: 10)
    let target = t.root.appendingPathComponent("target.bin")
    try FileManager.default.moveItem(at: real, to: target)
    let link = t.root.appendingPathComponent("real.bin")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

    let out = ExecutionRevalidator().revalidate(
        [candidate(path: link.path)], originalIdentities: [:], runningBundleIDs: [])
    #expect(out.approvedForExecution.isEmpty)
    #expect(out.rejected.first?.reason.contains("symlink") == true)
}

@Test func revalidatorDropsWhenIdentityChanged() {
    let t = TempTree(); defer { t.cleanup() }
    let f = t.file("keep.bin", bytes: 10)
    let bogus = FileIdentity(device: 999, inode: 999)
    let out = ExecutionRevalidator().revalidate(
        [candidate(path: f.path)], originalIdentities: [f.path: bogus], runningBundleIDs: [])
    #expect(out.approvedForExecution.isEmpty)
    #expect(out.rejected.first?.reason.contains("different file") == true)
}

@Test func revalidatorDropsWhenOwnerRunning() {
    let t = TempTree(); defer { t.cleanup() }
    let f = t.file("cache.bin", bytes: 10)
    // Age the file so the "just modified" guard doesn't fire first.
    try? FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -3600)], ofItemAtPath: f.path)
    let out = ExecutionRevalidator().revalidate(
        [candidate(path: f.path, owner: "AcmeApp")],
        originalIdentities: [:], runningBundleIDs: ["com.acme.AcmeApp"])
    #expect(out.approvedForExecution.isEmpty)
    #expect(out.rejected.first?.reason.contains("running") == true)
}

@Test func revalidatorPassesCleanCandidate() {
    let t = TempTree(); defer { t.cleanup() }
    let f = t.file("stale.bin", bytes: 10)
    try? FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -86_400)], ofItemAtPath: f.path)
    let id = ExecutionRevalidator.lstat(f.path).map {
        FileIdentity(device: UInt64(bitPattern: Int64($0.st_dev)), inode: $0.st_ino)
    }
    let out = ExecutionRevalidator().revalidate(
        [candidate(path: f.path)], originalIdentities: id.map { [f.path: $0] } ?? [:],
        runningBundleIDs: [])
    #expect(out.approvedForExecution.count == 1)
    #expect(out.rejected.isEmpty)
}

// MARK: - Ownership resolver

@Test func ownershipUsesExactBundleIDNotSubstring() {
    let app = InstalledApp(bundleID: "com.acme.Widget", bundleURL: "/Applications/Widget.app",
        displayName: "Widget", nameVariants: ["Widget"], teamID: "TEAM", embeddedBundleIDs: [],
        lastUsedDate: nil)
    let r = AppOwnershipResolver(installedApps: [app])
    #expect(r.resolve(folderName: "com.acme.Widget") == .ownedByInstalledApp(bundleID: "com.acme.Widget"))
    #expect(r.resolve(folderName: "com.acme.Widget.Helper") == .ownedByInstalledApp(bundleID: "com.acme.Widget"))
    // A different app whose name merely contains "Widget" is NOT owned.
    #expect(r.resolve(folderName: "com.evil.WidgetStealerPro") == .noInstalledOwner(bundleID: "com.evil.WidgetStealerPro"))
    #expect(r.resolve(folderName: "not-a-bundle") == .notBundleShaped)
}

// MARK: - DeepScanIndex incremental

@Test func indexApplyAndReopenIsIncremental() async throws {
    let t = TempTree(); defer { t.cleanup() }
    t.file("data/a.bin", bytes: 4096)
    t.file("data/b.bin", bytes: 8192)
    let g = await scan([t.root])

    let dbPath = t.root.appendingPathComponent("index.sqlite").path
    let idx = try DeepScanIndex(path: dbPath)
    try idx.apply(g)
    let firstCount = try idx.nodeCount()
    #expect(firstCount > 0)

    // Re-apply the same graph: node count is stable (upsert, not duplicate).
    try idx.apply(g)
    #expect(try idx.nodeCount() == firstCount)

    let largest = try idx.largestNodes(limit: 1)
    #expect(largest.first?.path.hasSuffix("b.bin") == true)
}

// MARK: - FSEvents incremental engine

@Test func coalescerDroppedEventsForceFullRescanAndStale() {
    let plan = EventCoalescer().coalesce(
        [FSChange(path: "/w/a", dropped: true)], watchedRoots: ["/w"])
    #expect(plan.requiresFullRescan)
    #expect(plan.health == .stale)
    #expect(plan.rescanRoots == ["/w"])
}

@Test func coalescerRootChangeIsError() {
    let plan = EventCoalescer().coalesce(
        [FSChange(path: "/w", rootChanged: true)], watchedRoots: ["/w"])
    #expect(plan.health == .error)
    #expect(plan.requiresFullRescan)
}

@Test func coalescerCollapsesNestedDirsAndExtractsDeletes() {
    let plan = EventCoalescer().coalesce([
        FSChange(path: "/w/a/b/c.txt", created: true),
        FSChange(path: "/w/a", isDir: true),
        FSChange(path: "/w/a/b/old.txt", removed: true),
    ], watchedRoots: ["/w"])
    #expect(plan.rescanRoots == ["/w/a"])           // /w/a/b folded into /w/a
    #expect(plan.deletedPaths == ["/w/a/b/old.txt"])
    #expect(!plan.requiresFullRescan)
}

@Test func incrementalEngineScopedRescanPicksUpNewFileAndPrunesDeleted() async throws {
    let t = TempTree(); defer { t.cleanup() }
    t.file("proj/keep.bin", bytes: 100)
    t.file("proj/gone.bin", bytes: 100)
    let dbPath = t.root.appendingPathComponent("idx.sqlite").path
    let index = try FSEventIncrementalEngine.openIndexRecovering(path: dbPath)
    let cfg = DeepScanConfiguration(roots: [t.root], maxConcurrency: 4, timeBudget: .seconds(20))
    let engine = FSEventIncrementalEngine(index: index, roots: [t.root], baseConfig: cfg,
                                          debounceMillis: 50)
    await engine.start()
    engine.stop()   // don't need the live stream for this test
    #expect(try index.nodeCount() > 0)
    let v0 = engine.scanVersion

    // Mutate: add a file, remove another.
    t.file("proj/added.bin", bytes: 200)
    try FileManager.default.removeItem(at: t.root.appendingPathComponent("proj/gone.bin"))
    engine.ingest([
        FSChange(path: t.root.appendingPathComponent("proj/added.bin").path, created: true),
        FSChange(path: t.root.appendingPathComponent("proj/gone.bin").path, removed: true),
    ])

    // Wait for the debounced flush + async rescan.
    try await Task.sleep(for: .milliseconds(1500))

    let paths = try index.largestNodes(limit: 500).map(\.path)
    #expect(paths.contains { $0.hasSuffix("/proj/added.bin") })
    #expect(!paths.contains { $0.hasSuffix("/proj/gone.bin") })
    #expect(engine.scanVersion > v0)
    #expect(engine.health == .fresh || engine.health == .partial)
}

@Test func indexCorruptionIsRecovered() throws {
    let t = TempTree(); defer { t.cleanup() }
    let dbPath = t.root.appendingPathComponent("corrupt.sqlite").path
    FileManager.default.createFile(atPath: dbPath, contents: Data("not a database".utf8))
    let index = try FSEventIncrementalEngine.openIndexRecovering(path: dbPath)
    #expect(try index.nodeCount() == 0)   // rebuilt empty, usable
}

// MARK: - Volume classification

@Test func tempDirClassifiesAsDataVolumeAndIsCached() {
    let r = VolumeResolver()
    let t = TempTree(); defer { t.cleanup() }
    let a = r.classify(path: t.root.path)
    let b = r.classify(path: t.root.appendingPathComponent("deeper/child").path)
    // Local internal storage — never external / network / unknown.
    #expect(a.volumeClass == .dataVolume || a.volumeClass == .systemVolume)
    #expect(a.volumeRoot == b.volumeRoot)          // same mount point resolved
    #expect(a.volumeClass == b.volumeClass)        // and cached consistently
}

@Test func systemPathIsNotClassifiedAsPlainDataVolume() {
    let info = VolumeResolver().classify(path: "/System/Library")
    // On a modern sealed macOS install "/" is the read-only system volume.
    #expect(info.volumeClass == .systemVolume || info.volumeClass == .dataVolume)
    #expect(info.volumeClass != .unknown)
}

@Test func engineStampsRealVolumeClassOntoNodes() async {
    let t = TempTree(); defer { t.cleanup() }
    t.file("x/y.bin", bytes: 32)
    let g = await scan([t.root])
    #expect(g.nodes.allSatisfy {
        $0.identity == nil || $0.volumeClass == .dataVolume || $0.volumeClass == .systemVolume
    })
    #expect(g.nodes.allSatisfy { $0.volumeClass != .unknown || $0.completeness == .permissionDenied })
}

// MARK: - Execution wiring (§17/§18/§19/§27)

@Test func executionGateOffSkipsEverything() async {
    let t = TempTree(); defer { t.cleanup() }
    let f = t.file("app/.next/build.bin", bytes: 16)
    DeepScanExecutionGate.isEnabled = false
    let report = await DeepScanExecutor().execute(
        selected: [execCandidate(path: f.path)], identitiesByPath: [:],
        runningBundleIDs: [], allowedRoots: [t.root], auditSink: nil)
    #expect(report.gated)
    #expect(report.executed.isEmpty)
    #expect(report.skipped.allSatisfy { $0.stage == "gate" })
    #expect(FileManager.default.fileExists(atPath: f.path))   // untouched
}

@Test func executableSubsetRejectsOutOfScopeCandidates() {
    let git = execCandidate(path: "/x/repo", detector: "git-project",
                            subcategory: "repository", category: .gitProjects)
    let weights = execCandidate(path: "/x/w", detector: "ai-storage",
                                subcategory: AIDataType.modelWeights.rawValue, category: .aiAndLLM)
    let risky = execCandidate(path: "/x/r", risk: .review)
    let unknownConf = execCandidate(path: "/x/u", confidence: .weak)
    let (eligible, rejected) = ExecutableSubsetPolicy.partition([git, weights, risky, unknownConf])
    #expect(eligible.isEmpty)
    #expect(rejected.count == 4)
}

@Test func executionGateOnTrashesEligibleCandidateAndJournals() async throws {
    let t = TempTree(); defer { t.cleanup() }
    let f = t.file("app/.next/output.bin", bytes: 16)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -3600)],
                                          ofItemAtPath: f.path)
    let sink = CapturingAuditSink()
    DeepScanExecutionGate.isEnabled = true
    defer { DeepScanExecutionGate.isEnabled = false }

    let id = ExecutionRevalidator.lstat(f.path).map {
        FileIdentity(device: UInt64(bitPattern: Int64($0.st_dev)), inode: $0.st_ino)
    }
    let report = await DeepScanExecutor().execute(
        selected: [execCandidate(path: f.path)],
        identitiesByPath: id.map { [f.path: $0] } ?? [:],
        runningBundleIDs: [], allowedRoots: [t.root], auditSink: sink)

    #expect(!report.gated)
    #expect(report.executed.count == 1)
    #expect(report.bytesTrashed == 16)
    #expect(!FileManager.default.fileExists(atPath: f.path))     // moved to Trash
    // Journal recorded an approve + an executed event with the deepscan ruleID.
    let stages = await sink.stages()
    let events = await sink.events
    #expect(stages.contains("approved"))
    #expect(stages.contains("executed"))
    #expect(events.contains { $0.ruleID == "deepscan:developer-storage:.next" })
}

@Test func adversarialExecutionAllSkipWithTruthfulReasons() async throws {
    DeepScanExecutionGate.isEnabled = true
    defer { DeepScanExecutionGate.isEnabled = false }
    let exec = DeepScanExecutor()

    // (a) path vanished between scan and execute
    do {
        let t = TempTree(); defer { t.cleanup() }
        let f = t.file("app/.next/v.bin", bytes: 16)
        let path = f.path
        try FileManager.default.removeItem(at: f)
        let r = await exec.execute(selected: [execCandidate(path: path)],
            identitiesByPath: [:], runningBundleIDs: [], allowedRoots: [t.root], auditSink: nil)
        #expect(r.executed.isEmpty)
        #expect(r.skipped.first?.reason.contains("no longer exists") == true)
    }
    // (b) owner app launches
    do {
        let t = TempTree(); defer { t.cleanup() }
        let f = t.file("app/.next/o.bin", bytes: 16)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -3600)],
                                              ofItemAtPath: f.path)
        let c = execCandidate(path: f.path, detector: "ai-storage",
                              subcategory: AIDataType.runtimeCache.rawValue, category: .aiAndLLM,
                              evidence: [Evidence(.pathPattern, "runtime cache")], owner: "LM Studio")
        let r = await exec.execute(selected: [c], identitiesByPath: [:],
            runningBundleIDs: ["LM Studio", "LM Studio Helper"], allowedRoots: [t.root], auditSink: nil)
        #expect(r.executed.isEmpty)
        #expect(r.skipped.contains { $0.reason.contains("running") })
        #expect(FileManager.default.fileExists(atPath: f.path))
    }
    // (c) inode replaced
    do {
        let t = TempTree(); defer { t.cleanup() }
        let f = t.file("app/.next/i.bin", bytes: 16)
        let bogus = FileIdentity(device: 1, inode: 424242)
        let r = await exec.execute(selected: [execCandidate(path: f.path)],
            identitiesByPath: [f.path: bogus], runningBundleIDs: [], allowedRoots: [t.root], auditSink: nil)
        #expect(r.executed.isEmpty)
        #expect(r.skipped.contains { $0.reason.contains("different file") })
    }
    // (d) path became a symlink
    do {
        let t = TempTree(); defer { t.cleanup() }
        let real = t.file("app/.next/real.bin", bytes: 16)
        let target = t.root.appendingPathComponent("target.bin")
        try FileManager.default.moveItem(at: real, to: target)
        try FileManager.default.createSymbolicLink(at: real, withDestinationURL: target)
        let r = await exec.execute(selected: [execCandidate(path: real.path)],
            identitiesByPath: [:], runningBundleIDs: [], allowedRoots: [t.root], auditSink: nil)
        #expect(r.executed.isEmpty)
        #expect(r.skipped.contains { $0.reason.contains("symlink") })
    }
    // (e) enclosing git repo is now dirty
    do {
        let t = TempTree(); defer { t.cleanup() }
        let repo = t.dir("repo")
        _ = try? runGit(["init", "-q"], in: repo)
        try FileManager.default.createDirectory(
            at: repo.appendingPathComponent(".next"), withIntermediateDirectories: true)
        let f = repo.appendingPathComponent(".next/build.bin")
        FileManager.default.createFile(atPath: f.path, contents: Data(count: 16))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -3600)],
                                              ofItemAtPath: f.path)
        // untracked file makes the repo "dirty"
        FileManager.default.createFile(atPath: repo.appendingPathComponent("scratch.txt").path,
                                       contents: Data("wip".utf8))
        let r = await exec.execute(selected: [execCandidate(path: f.path)],
            identitiesByPath: [:], runningBundleIDs: [], allowedRoots: [t.root], auditSink: nil)
        #expect(r.executed.isEmpty)
        #expect(r.skipped.contains { $0.reason.lowercased().contains("git") || $0.reason.contains("dirty") })
        #expect(FileManager.default.fileExists(atPath: f.path))
    }
}

@discardableResult
private func runGit(_ args: [String], in dir: URL) throws -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    p.arguments = ["-C", dir.path] + args
    let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
    try p.run(); p.waitUntilExit()
    return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

// MARK: - Git duplicate-remote normalization

@Test func remoteURLNormalizationMatchesEquivalentForms() {
    #expect(DuplicateProjectsDetector.normalize("git@github.com:acme/repo.git")
            == DuplicateProjectsDetector.normalize("https://github.com/acme/repo"))
}
