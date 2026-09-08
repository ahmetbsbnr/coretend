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

let args = Array(CommandLine.arguments.dropFirst())
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
