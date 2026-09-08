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
