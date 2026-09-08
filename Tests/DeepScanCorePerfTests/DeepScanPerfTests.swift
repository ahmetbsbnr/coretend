// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Deterministic large-scale performance fixtures for Deep Scan (spec §12/§13/§23).
//
// These use SYNTHETIC in-memory graphs and a real on-disk SQLite index. They do
// NOT create 100k–1M real files (that would wear the SSD for no added signal).
// A smaller real-filesystem subset exercises the actual walker + cancellation.
//
// Run:  bash Scripts/test.sh --filter DeepScanCorePerfTests
// Numbers are printed as `[perf] …` lines and transcribed into
// Documentation/DeepScan/PERFORMANCE.md.

import Foundation
import Testing
@testable import DeepScanCore

#if canImport(Darwin)
import Darwin
#endif

// MARK: - measurement helpers

private func residentBytes() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return kr == KERN_SUCCESS ? Int64(info.resident_size) : 0
}

private func mib(_ b: Int64) -> String { String(format: "%.1f MiB", Double(b) / 1_048_576) }

@discardableResult
private func timed<T>(_ label: String, _ body: () throws -> T) rethrows -> T {
    let t0 = DispatchTime.now().uptimeNanoseconds
    let r = try body()
    let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
    let padded = label.padding(toLength: max(label.count, 44), withPad: " ", startingAt: 0)
    print("[perf] \(padded) \(String(format: "%8.1f", ms)) ms")
    return r
}

// MARK: - synthetic graph builder (deterministic)

/// Builds a balanced tree of ~`target` nodes: `dirs` directories each holding
/// `target/dirs` files. Fixed seed-free layout ⇒ identical every run.
private func syntheticGraph(target: Int, root: String = "/synthetic") -> DiskGraph {
    var nodes: [ScanNode] = []
    nodes.reserveCapacity(target + 1)
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func mk(_ path: String, parent: String?, type: NodeType, ino: UInt64, bytes: Int64) -> ScanNode {
        ScanNode(path: path, canonicalPath: path, parentCanonicalPath: parent, type: type,
                 identity: FileIdentity(device: 1, inode: ino), volumeClass: .dataVolume, volumeUUID: nil,
                 logicalBytes: bytes, allocatedBytes: bytes, childCount: 0,
                 createdAt: now, modifiedAt: now, accessedAt: now,
                 posixPermissions: 0o644, ownerUID: 501, ownerName: nil,
                 isSymlink: false, symlinkTarget: nil, symlinkResolvesInsideRoot: nil,
                 bundleContext: nil, cloudRemoteOnly: false, completeness: .complete, observedAt: now)
    }
    nodes.append(mk(root, parent: nil, type: .directory, ino: 1, bytes: 0))
    let dirCount = max(1, Int(Double(target).squareRoot()))
    let perDir = max(1, target / dirCount)
    var ino: UInt64 = 2
    for d in 0..<dirCount {
        let dPath = "\(root)/dir\(d)"
        nodes.append(mk(dPath, parent: root, type: .directory, ino: ino, bytes: 0)); ino += 1
        for f in 0..<perDir {
            nodes.append(mk("\(dPath)/file\(f).bin", parent: dPath, type: .file, ino: ino,
                           bytes: Int64((f % 97) + 1) * 1024)); ino += 1
            if nodes.count >= target { break }
        }
        if nodes.count >= target { break }
    }
    return DiskGraph(nodes: nodes, scannedRoots: [root], startedAt: now, finishedAt: now,
                     wasCancelled: false, hitTimeout: false, deniedRoots: [])
}

// MARK: - synthetic scale tests

@Test(arguments: [100_000, 500_000, 1_000_000])
func syntheticGraphAndIndexScale(target: Int) throws {
    let rss0 = residentBytes()
    let graph = timed("build DiskGraph (\(target) nodes)") { syntheticGraph(target: target) }
    #expect(graph.nodes.count >= target - 2_000)   // rounding from sqrt bucketing

    // Whole-graph traversal cost (the "hold it all in RAM" path).
    let descendants = timed("descendants(root) \(target)") { graph.descendants(of: graph.scannedRoots[0]) }
    #expect(descendants.count == graph.nodes.count - 1)
    timed("subtreeFullyObserved(root) \(target)") { _ = graph.subtreeFullyObserved(graph.scannedRoots[0]) }
    let rssGraph = residentBytes()
    print("[perf] RSS after \(target)-node graph: \(mib(rssGraph)) (Δ \(mib(rssGraph - rss0)))")

    // SQLite index: initial bulk apply, incremental re-apply, query latency.
    let dbPath = NSTemporaryDirectory() + "perf-\(target)-\(UUID().uuidString).sqlite"
    defer { try? FileManager.default.removeItem(atPath: dbPath) }
    let idx = try DeepScanIndex(path: dbPath)
    timed("index.apply initial (\(target))") { try? idx.apply(graph) }
    #expect((try? idx.nodeCount()) ?? 0 >= target - 2_000)

    let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: dbPath)[.size] as? Int64) ?? 0
    print("[perf] SQLite file size (\(target) nodes): \(mib(sizeBytes ?? 0))")

    timed("index.apply re-apply / incremental (\(target))") { try? idx.apply(graph) }
    let q = timed("index.largestNodes(limit:200) (\(target))") { (try? idx.largestNodes(limit: 200)) ?? [] }
    #expect(q.count == 200)
}

// MARK: - real-filesystem subset (actual walker + cancellation)

@Test func realFilesystemSubsetThroughputAndCancelLatency() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("deepscan-perf-\(UUID().uuidString)")
    let fm = FileManager.default
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let dirs = 40, perDir = 150   // 6,000 real files
    for d in 0..<dirs {
        let dd = root.appendingPathComponent("d\(d)")
        try fm.createDirectory(at: dd, withIntermediateDirectories: true)
        for f in 0..<perDir {
            fm.createFile(atPath: dd.appendingPathComponent("f\(f).bin").path,
                          contents: Data(count: 256))
        }
    }

    let cfg = DeepScanConfiguration(roots: [root], maxConcurrency: 8, timeBudget: .seconds(60))
    let t0 = DispatchTime.now().uptimeNanoseconds
    let g = await DeepScanEngine().scan(cfg)
    let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
    let count = g.nodes.count
    print(String(format: "[perf] real walk: %d nodes in %.1f ms (%.0f nodes/s)",
                 count, ms, Double(count) / (ms / 1000)))
    #expect(count >= dirs * perDir)
    #expect(!g.hitTimeout)

    // Cancellation latency: cancel mid-flight, measure time to return.
    let cancel = DeepScanCancellation()
    let c0 = DispatchTime.now().uptimeNanoseconds
    async let scanning = DeepScanEngine().scan(cfg, cancellation: cancel)
    cancel.cancel()
    let cg = await scanning
    let cms = Double(DispatchTime.now().uptimeNanoseconds - c0) / 1_000_000
    print(String(format: "[perf] cancel latency: %.1f ms", cms))
    #expect(cg.wasCancelled)
    #expect(cms < 2_000)   // must unwind promptly
}
