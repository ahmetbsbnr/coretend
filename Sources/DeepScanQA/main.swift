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
print("- roots: \(g.scannedRoots.joined(separator: ", "))")
print("- nodes observed: \(g.nodes.count)")
print("- wall time: \(String(format: "%.1f", g.finishedAt.timeIntervalSince(g.startedAt)))s")
print("- cancelled: \(g.wasCancelled)   timed out: \(g.hitTimeout)")
print("- roots we could not read: \(g.deniedRoots.isEmpty ? "none" : g.deniedRoots.joined(separator: ", "))")
let denied = g.nodes.filter { $0.completeness == .permissionDenied }.count
let partial = g.nodes.filter { $0.completeness == .partial }.count
print("- permission-denied nodes: \(denied)   partial nodes: \(partial)")
print()

print("## Installed apps & git repos")
print("- installed apps discovered: \(result.context.installedApps.count)")
print("- git repositories discovered: \(result.context.gitRepos.count)")
for r in result.context.gitRepos.sorted(by: { $0.workdir < $1.workdir }) {
    print("  - [\(r.safety.rawValue.uppercased())] \(r.workdir) — branch \(r.currentBranch ?? "detached"), "
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
        print("- \(fmt(c.logicalBytes))  [\(c.risk.rawValue)/\(c.confidence.rawValue)]  \(c.canonicalPath)")
        print("    owner: \(c.owner ?? "—")  subcategory: \(c.subcategory)  default-selected: \(c.defaultSelected)")
        print("    why: \(c.rationale)")
        print("    if removed: \(c.ifRemoved)")
        if let pr = c.protectedReason { print("    PROTECTED: \(pr)") }
        for e in c.evidence { print("    · \(e.humanReadable)") }
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
