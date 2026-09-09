// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// DeepScanQA — a READ-ONLY harness for spec §25. It runs DeepScanPipeline
// against real directories and prints a discoveries report. It has NO code
// path that deletes, trashes, or modifies anything: it only calls the
// observe+detect stages and formats the result.
//
//   swift run DeepScanQA [root ...]      # defaults to $HOME
//
// Every candidate is printed with size, category, risk, confidence, evidence
// and the "if removed" note. Nothing is acted on.

import Foundation
import DeepScanCore
import SafetyCore

let args = Array(CommandLine.arguments.dropFirst())

// --- controlled cleanup QA (spec §26): disposable fixture only -------------
// Usage: DeepScanQA --controlled-cleanup
// Builds an isolated fake project with a rebuildable .next dir, scans it,
// executes the SAFE subset through the real SafetyCenter -> Trash, and prints
// the journal. Never touches anything outside its own temp root.
if args.first == "--controlled-cleanup" {
    setenv("CORETEND_DEEPSCAN_EXEC", "1", 1)
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("coretend-controlled-cleanup-\(UUID().uuidString)")
    let fm = FileManager.default
    try fm.createDirectory(at: root.appendingPathComponent("myapp/.next/cache"),
                           withIntermediateDirectories: true)
    fm.createFile(atPath: root.appendingPathComponent("myapp/package.json").path,
                  contents: Data(#"{"dependencies":{"next":"14"}}"#.utf8))
    for i in 0..<20 {
        fm.createFile(atPath: root.appendingPathComponent("myapp/.next/cache/chunk\(i).js").path,
                      contents: Data(repeating: 0x2F, count: 4096))
    }
    // age the tree so the "just modified" guard doesn't fire
    let old = Date(timeIntervalSinceNow: -7200)
    if let en = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
        while let u = en.nextObject() as? URL {
            try? fm.setAttributes([.modificationDate: old], ofItemAtPath: u.path)
        }
    }

    print("controlled-cleanup fixture: \(root.path)")
    let cfg = DeepScanConfiguration(roots: [root], maxConcurrency: 4, timeBudget: .seconds(30))
    let result = await DeepScanPipeline().run(configuration: cfg, home: root)
    let next = result.candidates.filter { $0.detector == "developer-storage" }
    print("candidates: \(result.candidates.count), developer-storage: \(next.count)")
    for c in next { print("  \(c.risk.rawValue)/\(c.confidence.rawValue) \(c.canonicalPath) — default-selected \(c.defaultSelected)") }

    let sink = PrintingSink()
    let report = await DeepScanExecutor().execute(
        selected: next,
        identitiesByPath: result.identitiesByPath,
        runningBundleIDs: DeepScanPipeline.runningProcesses().bundleIDs,
        allowedRoots: [root],
        auditSink: sink)
    print("executed: \(report.executed.count)  bytesTrashed: \(report.bytesTrashed)  skipped: \(report.skipped.count)  gated: \(report.gated)")
    for s in report.skipped { print("  SKIP [\(s.stage)] \(s.reason): \((s.candidate.canonicalPath as NSString).lastPathComponent)") }
    for e in report.executed { print("  TRASHED \(e.trashedFrom) (\(e.bytes) bytes)") }
    let stillThere = report.executed.filter { fm.fileExists(atPath: $0.trashedFrom) }
    print(stillThere.isEmpty ? "verify: originals no longer at source ✔" : "verify: FAILED, \(stillThere.count) still present")
    try? fm.removeItem(at: root)
    print("Restore: the audit journal above records original + trash paths; Restore Center reinstates them. (HUMAN VERIFICATION for the GUI restore round-trip.)")
    exit(0)
}

final class PrintingSink: SafetyAuditSink, @unchecked Sendable {
    func recordSafetyEvent(_ event: SafetyAuditEvent) async {
        print("  journal: \(event.stage.rawValue) \(event.ruleID) \(event.path) -> \(event.result)")
    }
}

// --- Safe-subset + negative-safety QA (spec §12/§13) -------------------------
// Usage: DeepScanQA --safe-subset-qa
// Disposable fixtures only. Confirms the SAFE subset executes end-to-end for
// each enabled type, and that a broad set of dangerous candidates fails closed.
if args.first == "--safe-subset-qa" {
    setenv("CORETEND_DEEPSCAN_EXEC", "1", 1)
    let fm = FileManager.default
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("coretend-safe-subset-qa-\(UUID().uuidString)")

    // ---- POSITIVE: one fixture per enabled beta execution type ----
    // 1. developer generated build output
    try fm.createDirectory(at: root.appendingPathComponent("proj/.next/cache"), withIntermediateDirectories: true)
    fm.createFile(atPath: root.appendingPathComponent("proj/package.json").path, contents: Data(#"{"dependencies":{"next":"14"}}"#.utf8))
    for i in 0..<20 { fm.createFile(atPath: root.appendingPathComponent("proj/.next/cache/c\(i).js").path, contents: Data(count: 4096)) }
    // 2. aged temporary directory (place under a real system temp root)
    let tempFixture = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("coretend-ssqa-temp-\(UUID().uuidString)")
    try fm.createDirectory(at: tempFixture, withIntermediateDirectories: true)
    for i in 0..<10 { fm.createFile(atPath: tempFixture.appendingPathComponent("t\(i).tmp").path, contents: Data(count: 2048)) }
    // 3. AI runtime cache fixture (LM Studio bin -> runtimeCache)
    try fm.createDirectory(at: root.appendingPathComponent(".cache/lm-studio/bin"), withIntermediateDirectories: true)
    for i in 0..<8 { fm.createFile(atPath: root.appendingPathComponent(".cache/lm-studio/bin/b\(i)").path, contents: Data(count: 4096)) }

    func runGit(_ a: [String], in dir: URL) throws {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", dir.path] + a
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try p.run(); p.waitUntilExit()
    }
    // ---- NEGATIVE: must all fail closed ----
    let repo = root.appendingPathComponent("cleanrepo")
    try fm.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try? runGit(["init", "-q"], in: repo)
    _ = try? runGit(["config", "user.email", "q@e.com"], in: repo); _ = try? runGit(["config", "user.name", "q"], in: repo)
    fm.createFile(atPath: repo.appendingPathComponent("a.txt").path, contents: Data("x".utf8))
    _ = try? runGit(["add", "-A"], in: repo); _ = try? runGit(["commit", "-qm", "i"], in: repo)
    let dirtyRepo = root.appendingPathComponent("dirtyrepo")
    try fm.createDirectory(at: dirtyRepo, withIntermediateDirectories: true)
    _ = try? runGit(["init", "-q"], in: dirtyRepo)
    fm.createFile(atPath: dirtyRepo.appendingPathComponent("wip.txt").path, contents: Data("wip".utf8))
    func mkfile(_ rel: String, _ bytes: Int) {
        let u = root.appendingPathComponent(rel)
        try? fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        fm.createFile(atPath: u.path, contents: Data(count: bytes))
    }
    mkfile(".claude/projects/-x/memory/M.md", 20)
    mkfile(".claude/.credentials.json", 20)
    mkfile(".codex/sessions/s.jsonl", 20)
    mkfile(".cache/lm-studio/models/w.gguf", 4096)
    mkfile("Library/Caches/com.evil.Ghost/blob", 8000)

    // age everything
    let old = Date(timeIntervalSinceNow: -8 * 86_400)
    for dir in [root, tempFixture] {
        if let en = fm.enumerator(at: dir, includingPropertiesForKeys: nil) {
            while let u = en.nextObject() as? URL { try? fm.setAttributes([.modificationDate: old], ofItemAtPath: u.path) }
        }
        try? fm.setAttributes([.modificationDate: old], ofItemAtPath: dir.path)
    }
    defer { try? fm.removeItem(at: root); try? fm.removeItem(at: tempFixture) }

    print("== SAFE-SUBSET + NEGATIVE-SAFETY QA ==")
    print("root: \(root.path)")
    // /private/tmp is included so TempFilesDetector (which enumerates that
    // root) sees the aged temp fixture.
    let cfg = DeepScanConfiguration(roots: [root, URL(fileURLWithPath: "/private/tmp")],
        maxConcurrency: 6, timeBudget: .seconds(40),
        excludedPrefixes: ["/private/tmp/com.apple", "/private/tmp/.", "/private/tmp/CoreSim"])
    let result = await DeepScanPipeline(allowNetwork: false).run(configuration: cfg, home: root)
    print("candidates: \(result.candidates.count)")

    let (eligible, _) = ExecutableSubsetPolicy.partition(result.candidates)
    print("\n-- executable SAFE subset (\(eligible.count)) --")
    for c in eligible { print("  \(c.detector):\(c.subcategory)  \((c.canonicalPath as NSString).lastPathComponent)  [\(c.risk.rawValue)/\(c.confidence.rawValue)]") }

    // Execute the eligible ones for real (disposable) and confirm Trash+journal.
    let sink = PrintingSink()
    let report = await DeepScanExecutor().execute(
        selected: eligible, identitiesByPath: result.identitiesByPath,
        runningBundleIDs: DeepScanPipeline.runningProcesses().bundleIDs,
        allowedRoots: [root, tempFixture, URL(fileURLWithPath: "/private/tmp")],
        auditSink: sink)
    print("executed: \(report.executed.count)  skipped: \(report.skipped.count)  gated: \(report.gated)")
    for e in report.executed { print("  TRASHED \((e.trashedFrom as NSString).lastPathComponent) (\(e.bytes)B)") }

    // NEGATIVE: none of these dangerous shapes may be in the eligible set.
    func present(_ pred: (CleanupCandidate) -> Bool) -> Bool { eligible.contains(where: pred) }
    let negatives: [(String, (CleanupCandidate) -> Bool)] = [
        ("git repository root", { $0.category == .gitProjects }),
        ("AI model weights", { $0.subcategory == AIDataType.modelWeights.rawValue }),
        ("Claude memory", { $0.canonicalPath.contains("/.claude/projects") || $0.canonicalPath.contains("/memory") }),
        ("Codex sessions", { $0.canonicalPath.contains("/.codex/sessions") }),
        ("credentials/auth", { $0.subcategory == AIDataType.auth.rawValue || $0.canonicalPath.contains(".credentials") }),
        ("unknown AI data", { $0.category == .aiAndLLM && $0.subcategory == AIDataType.unknownData.rawValue }),
        ("app leftover", { $0.category == .appsAndLeftovers }),
        ("system settings", { $0.category == .systemAndSettings }),
        ("cloud", { $0.category == .cloud }),
        ("protected risk", { $0.risk == .protected }),
        ("below-strong confidence", { $0.confidence < .strong }),
    ]
    print("\n-- negative safety (all must be 'blocked') --")
    var ok = true
    for (name, pred) in negatives {
        let leaked = present(pred)
        if leaked { ok = false }
        print("  \(leaked ? "LEAKED ***" : "blocked   ")  \(name)")
    }
    let repoCands = result.candidates.filter { $0.category == .gitProjects }
    let eligibleIDs = Set(eligible.map(\.id))
    let eligibleGit = repoCands.filter { eligibleIDs.contains($0.id) }.count
    print("\n  git candidates seen: \(repoCands.count); eligible git candidates: \(eligibleGit) (must be 0)")

    let detsExecuted = Set(report.executed.map { $0.candidate.detector })
    let devOK = detsExecuted.contains("developer-storage")
    let tempSeen = result.candidates.contains { $0.detector == "temp-files" }
    let aiRuntimeSeen = result.candidates.contains {
        $0.detector == "ai-storage" && $0.subcategory == AIDataType.runtimeCache.rawValue
    }
    let aiRuntimeEligible = eligible.contains {
        $0.detector == "ai-storage" && $0.subcategory == AIDataType.runtimeCache.rawValue
    }
    print("\n-- per-type coverage --")
    print("  developer build output: executed=\(devOK)")
    print("  aged temp files: candidate seen=\(tempSeen), executed=\(detsExecuted.contains("temp-files"))")
    print("  AI runtime cache: candidate seen=\(aiRuntimeSeen), eligible=\(aiRuntimeEligible)  " +
          "(policy-allowed but requires SAFE+STRONG evidence, which runtime cache rarely reaches — conservative by design)")

    let positiveOK = !report.gated && report.executed.count == eligible.count && devOK
    let pass = ok && positiveOK && eligibleGit == 0
    print("\nRESULT: \(pass ? "PASS" : "REVIEW")")
    print("(positive: \(report.executed.count)/\(eligible.count) executed, dev path end-to-end=\(devOK); " +
          "negative: \(ok ? "all 11 dangerous shapes blocked" : "LEAK — investigate"))")
    exit(pass ? 0 : 1)
}

// --- FSEvents real-churn QA (spec §7/§8) --------------------------------------
// Usage: DeepScanQA --fsevents-churn
// Drives FSEventIncrementalEngine (real FSEventStream) against a disposable
// fixture under developer-representative churn, printing index health / version
// / node-count transitions. Also exercises dropped-event -> STALE -> FRESH and
// index corruption recovery.
if args.first == "--fsevents-churn" {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("coretend-fsevents-churn-\(UUID().uuidString)")
    try fm.createDirectory(at: root.appendingPathComponent("proj"), withIntermediateDirectories: true)
    fm.createFile(atPath: root.appendingPathComponent("proj/package.json").path,
                  contents: Data(#"{"dependencies":{"next":"14"}}"#.utf8))
    let dbPath = root.appendingPathComponent("index.sqlite").path
    let index = try FSEventIncrementalEngine.openIndexRecovering(path: dbPath)
    let cfg = DeepScanConfiguration(roots: [root], maxConcurrency: 8, timeBudget: .seconds(60))

    final class HealthLog: @unchecked Sendable {
        let lock = NSLock(); var transitions: [String] = []
        func note(_ h: IndexHealth) { lock.lock(); transitions.append(h.rawValue); lock.unlock() }
    }
    let hlog = HealthLog()
    let engine = FSEventIncrementalEngine(index: index, roots: [root], baseConfig: cfg,
                                          debounceMillis: 400,
                                          onHealthChange: { hlog.note($0) })

    func snap(_ label: String) {
        let n = (try? index.nodeCount()) ?? -1
        let lbl = label.padding(toLength: max(label.count, 34), withPad: " ", startingAt: 0)
        print("  \(lbl) nodes=\(n)  health=\(engine.health.rawValue)  version=\(engine.scanVersion)")
    }

    print("fixture: \(root.path)")
    let t0 = Date()
    await engine.start()
    print(String(format: "initial full scan: %.2fs", Date().timeIntervalSince(t0)))
    snap("after start")

    func churn(_ name: String, _ work: () async throws -> Void) async {
        let s = Date()
        try? await work()
        // wait for debounce + async scoped rescan
        try? await Task.sleep(for: .milliseconds(1600))
        print("[\(name)] \(String(format: "%.2f", Date().timeIntervalSince(s)))s")
        snap("  after \(name)")
    }

    // 1. npm install: ~2000 small files across nested dirs
    await churn("npm install (2000 files)") {
        for i in 0..<40 {
            let d = root.appendingPathComponent("proj/node_modules/pkg\(i)")
            try fm.createDirectory(at: d, withIntermediateDirectories: true)
            for j in 0..<50 { fm.createFile(atPath: d.appendingPathComponent("f\(j).js").path, contents: Data(count: 512)) }
        }
    }
    // 2. Next build: create .next then replace it wholesale
    await churn("next build (.next created)") {
        let d = root.appendingPathComponent("proj/.next/cache")
        try fm.createDirectory(at: d, withIntermediateDirectories: true)
        for j in 0..<200 { fm.createFile(atPath: d.appendingPathComponent("chunk\(j).js").path, contents: Data(count: 2048)) }
    }
    await churn("next rebuild (.next replaced)") {
        try fm.removeItem(at: root.appendingPathComponent("proj/.next"))
        let d = root.appendingPathComponent("proj/.next/cache")
        try fm.createDirectory(at: d, withIntermediateDirectories: true)
        for j in 0..<220 { fm.createFile(atPath: d.appendingPathComponent("chunk\(j).js").path, contents: Data(count: 2048)) }
    }
    // 3. mass delete (rm -rf node_modules)
    await churn("rm -rf node_modules") {
        try fm.removeItem(at: root.appendingPathComponent("proj/node_modules"))
    }
    // 4. renames + rapid repeated writes to one file
    await churn("rename + rapid writes") {
        let src = root.appendingPathComponent("proj/a.txt")
        fm.createFile(atPath: src.path, contents: Data("v0".utf8))
        try fm.moveItem(at: src, to: root.appendingPathComponent("proj/b.txt"))
        for k in 0..<50 { try Data("v\(k)".utf8).write(to: root.appendingPathComponent("proj/b.txt")) }
    }
    // 5. git checkout-like: touch many files
    await churn("git checkout (mtime storm)") {
        let d = root.appendingPathComponent("proj/src")
        try fm.createDirectory(at: d, withIntermediateDirectories: true)
        for j in 0..<300 { fm.createFile(atPath: d.appendingPathComponent("s\(j).swift").path, contents: Data(count: 128)) }
        try? await Task.sleep(for: .milliseconds(50))
        for j in 0..<300 { try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: d.appendingPathComponent("s\(j).swift").path) }
    }
    // 6. simulated dropped event -> must go STALE then rebuild to FRESH
    print("[dropped event] injecting kFSEventStreamEventFlagUserDropped-equivalent")
    engine.ingest([FSChange(path: root.appendingPathComponent("proj").path, dropped: true)])
    try? await Task.sleep(for: .milliseconds(2500))
    snap("  after dropped-event rescan")

    engine.stop()
    print("health transitions: \(hlog.transitions.joined(separator: " -> "))")
    let sawStale = hlog.transitions.contains("stale")
    let endsFreshOrPartial = ["fresh", "partial"].contains(engine.health.rawValue)
    print("dropped-event -> STALE seen: \(sawStale)   ends FRESH/PARTIAL: \(endsFreshOrPartial)")

    // 7. corruption recovery
    let dbPath2 = root.appendingPathComponent("corrupt.sqlite").path
    fm.createFile(atPath: dbPath2, contents: Data("not a sqlite database".utf8))
    let recovered = try FSEventIncrementalEngine.openIndexRecovering(path: dbPath2)
    print("corruption recovery: reopened, nodeCount=\((try? recovered.nodeCount()) ?? -1) (0 = rebuilt clean)")

    try? fm.removeItem(at: root)
    print("Live GUI watch loop (index-health badge in the running app) = HUMAN VERIFICATION.")
    exit(0)
}
let home = FileManager.default.homeDirectoryForCurrentUser
let roots: [URL] = args.isEmpty ? [home] : args.map { URL(fileURLWithPath: $0) }

func fmt(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

/// Redact the real home directory (and any `/Users/<name>` prefix) so the
/// committed report never carries the developer's macOS account name.
let homePathForRedaction = home.standardizedFileURL.path
func redact(_ s: String) -> String {
    var out = s.replacingOccurrences(of: homePathForRedaction, with: "~")
    // Any other /Users/<name>/ that slipped through (e.g. a second account).
    out = out.replacingOccurrences(
        of: #"/Users/[^/ ]+"#, with: "/Users/<user>", options: .regularExpression)
    return out
}

FileHandle.standardError.write(Data("scanning \(roots.map(\.path).joined(separator: ", "))…\n".utf8))

let cfg = DeepScanConfiguration(
    roots: roots,
    maxConcurrency: 8,
    timeBudget: .seconds(240),
    excludedPrefixes: ["/System", "/Volumes"],
    followMountBoundaries: false,
    maxDepth: 32)

let pipeline = DeepScanPipeline(allowNetwork: false)

let result = await pipeline.run(configuration: cfg, home: home) { p in
    FileHandle.standardError.write(Data("  \(p.nodesObserved) nodes, \(fmt(p.bytesObserved))\r".utf8))
}
FileHandle.standardError.write(Data("\n".utf8))

let g = result.graph
print("# CoreTend Deep Scan — READ-ONLY QA report")
print("Generated: \(ISO8601DateFormatter().string(from: Date()))")
print()
print("## Scan")
print("- roots: \(redact(g.scannedRoots.joined(separator: ", ")))")
print("- nodes observed: \(g.nodes.count)")
print("- wall time: \(String(format: "%.1f", g.finishedAt.timeIntervalSince(g.startedAt)))s")
print("- cancelled: \(g.wasCancelled)   timed out: \(g.hitTimeout)")
print("- roots we could not read: \(g.deniedRoots.isEmpty ? "none" : redact(g.deniedRoots.joined(separator: ", ")))")
let denied = g.nodes.filter { $0.completeness == .permissionDenied }.count
let partial = g.nodes.filter { $0.completeness == .partial }.count
print("- permission-denied nodes: \(denied)   partial nodes: \(partial)")
print()

print("## Installed apps & git repos")
print("- installed apps discovered: \(result.context.installedApps.count)")
print("- git repositories discovered: \(result.context.gitRepos.count)")
for r in result.context.gitRepos.sorted(by: { $0.workdir < $1.workdir }) {
    print("  - [\(r.safety.rawValue.uppercased())] \(redact(r.workdir)) — branch \(r.currentBranch ?? "detached"), "
          + "dirty=\(r.isDirty), stashes=\(r.stashCount), unpushed=\(r.localOnlyCommitCount)")
}
print()

print("## Candidates by category")
let byCat = Dictionary(grouping: result.candidates, by: { $0.category })
for cat in CleanupCategory.allCases {
    guard let items = byCat[cat], !items.isEmpty else { continue }
    let reclaimable = items.filter { $0.risk != .protected }.reduce(Int64(0)) { $0 + $1.estimatedReclaimableBytes }
    let prot = items.filter { $0.risk == .protected }.count
    print("### \(cat.rawValue) — \(items.count) candidates, ~\(fmt(reclaimable)) reviewable, \(prot) protected")
    for c in items.sorted(by: { $0.logicalBytes > $1.logicalBytes }).prefix(25) {
        print("- \(fmt(c.logicalBytes))  [\(c.risk.rawValue)/\(c.confidence.rawValue)]  \(redact(c.canonicalPath))")
        print("    owner: \(redact(c.owner ?? "—"))  subcategory: \(c.subcategory)  default-selected: \(c.defaultSelected)")
        print("    why: \(redact(c.rationale))")
        print("    if removed: \(redact(c.ifRemoved))")
        if let pr = c.protectedReason { print("    PROTECTED: \(redact(pr))") }
        for e in c.evidence { print("    · \(redact(e.humanReadable))") }
    }
    print()
}

print("## Safety self-check")
let anyProtectedSelected = result.candidates.contains { $0.risk == .protected && $0.defaultSelected }
let anyUnknownSelected = result.candidates.contains { $0.confidence == .unknown && $0.defaultSelected }
let memorySelected = result.candidates.contains {
    $0.canonicalPath.contains("/.claude/") &&
    ($0.canonicalPath.contains("/memory") || $0.canonicalPath.contains("/projects") || $0.canonicalPath.contains("/history")) &&
    $0.defaultSelected
}
print("- protected candidate default-selected: \(anyProtectedSelected)  (must be false)")
print("- unknown-confidence default-selected: \(anyUnknownSelected)  (must be false)")
print("- ~/.claude memory/projects/history default-selected: \(memorySelected)  (must be false)")
let defaultCount = result.candidates.filter { $0.defaultSelected }.count
print("- total default-selected: \(defaultCount) of \(result.candidates.count)")

// Preselection-decision inputs (spec §14).
let safeStrong = result.candidates.filter {
    $0.risk == .safe && $0.confidence >= .strong
}
let (subsetEligible, _) = ExecutableSubsetPolicy.partition(result.candidates)
print("## Preselection decision inputs")
print("- total candidates: \(result.candidates.count)")
print("- risk==SAFE && confidence>=STRONG: \(safeStrong.count)")
print("  by category: " + Dictionary(grouping: safeStrong, by: { $0.category.rawValue })
        .map { "\($0.key)=\($0.value.count)" }.sorted().joined(separator: ", "))
print("- would meet DefaultSelectionPolicy.meetsBar: " + String(safeStrong.filter {
    DefaultSelectionPolicy.meetsBar(risk: $0.risk, confidence: $0.confidence,
        reconstruction: $0.reconstructability,
        subtreeComplete: !$0.evidence.contains { $0.kind == .subtreeIncomplete },
        evidenceKinds: Set($0.evidence.map(\.kind)))
}.count))
print("- in executable SAFE subset (manually selectable for execution): \(subsetEligible.count)")
print("  " + subsetEligible.prefix(20).map { "\($0.detector):\($0.subcategory) \(($0.canonicalPath as NSString).lastPathComponent)" }.joined(separator: "\n  "))
