// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// DeepScanPipeline — wires the read-only stages together:
//
//   DeepScanEngine (observe)  ->  DiskGraph
//   context gather (apps, running procs, git)  ->  DetectorContext
//   detectors (evidence)  ->  [CleanupCandidate]
//   DefaultSelectionPolicy already applied per-candidate
//
// Execution is deliberately NOT part of this type. To act, a caller takes the
// user-selected candidates, runs ExecutionRevalidator, then hands the survivors
// to the existing SafetyCore.SafetyCenter (Trash + Journal). This module never
// deletes anything.

import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct DeepScanResult: Sendable {
    public let graph: DiskGraph
    public let context: DetectorContext
    public let candidates: [CleanupCandidate]
    /// (dev,ino) for every candidate path at scan time, for the revalidator.
    public let identitiesByPath: [String: FileIdentity]

    public var totalByCategory: [CleanupCategory: Int64] {
        var m: [CleanupCategory: Int64] = [:]
        for c in candidates where c.risk != .protected {
            m[c.category, default: 0] += c.estimatedReclaimableBytes
        }
        return m
    }
    public var protectedCandidates: [CleanupCandidate] { candidates.filter { $0.risk == .protected } }
}

public struct DeepScanPipeline: Sendable {
    public let detectors: [any Detector]
    public let allowNetwork: Bool

    public init(detectors: [any Detector] = DeepScanPipeline.defaultDetectors,
                allowNetwork: Bool = false) {
        self.detectors = detectors
        self.allowNetwork = allowNetwork
    }

    public static var defaultDetectors: [any Detector] {
        [
            AIStorageDetector(),
            OrphanedAppDetector(),
            DeveloperStorageDetector(),
            GitProjectDetector(),
            DuplicateProjectsDetector(),
            SystemSettingsDetector(),
            TempFilesDetector(),
            InstallerDetector(),
            CloudStorageDetector(),
            LargeOldFileDetector(),
        ]
    }

    public func run(configuration: DeepScanConfiguration,
                    home: URL = FileManager.default.homeDirectoryForCurrentUser,
                    cancellation: DeepScanCancellation = DeepScanCancellation(),
                    onProgress: (@Sendable (DeepScanProgress) -> Void)? = nil) async -> DeepScanResult {
        let engine = DeepScanEngine()
        let graph = await engine.scan(configuration, cancellation: cancellation, onProgress: onProgress)

        let apps = AppInventoryScanner().scan(roots: AppInventoryScanner.defaultSearchRoots(home: home))
        let (runningBundleIDs, runningPaths) = Self.runningProcesses()
        let gitAnalyzer = GitProjectAnalyzer(allowNetwork: allowNetwork)
        let repoRoots = gitAnalyzer.discoverRepoRoots(in: graph)
        let gitRepos = repoRoots.compactMap { gitAnalyzer.analyze(repoRoot: $0) }

        let context = DetectorContext(
            home: home, installedApps: apps,
            runningBundleIDs: runningBundleIDs, runningExecutablePaths: runningPaths,
            scanStartedAt: graph.startedAt, scanFinishedAt: graph.finishedAt,
            gitRepos: gitRepos)

        var candidates: [CleanupCandidate] = []
        for detector in detectors {
            candidates.append(contentsOf: detector.detect(in: graph, context: context))
        }
        // De-dup by canonical path, keeping the highest-risk verdict.
        var best: [String: CleanupCandidate] = [:]
        for c in candidates {
            if let existing = best[c.canonicalPath], existing.risk >= c.risk { continue }
            best[c.canonicalPath] = c
        }
        let merged = Array(best.values).sorted { $0.estimatedReclaimableBytes > $1.estimatedReclaimableBytes }

        var identities: [String: FileIdentity] = [:]
        for c in merged {
            if let n = graph.node(at: c.canonicalPath), let id = n.identity {
                identities[c.canonicalPath] = id
            }
        }

        return DeepScanResult(graph: graph, context: context,
                              candidates: merged, identitiesByPath: identities)
    }

    /// Best-effort snapshot of running processes. Executable paths come from
    /// `ps`; bundle IDs are derived from any `.app` component in the path.
    static func runningProcesses() -> (bundleIDs: Set<String>, paths: Set<String>) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-axo", "comm="]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        do { try p.run() } catch { return ([], []) }
        p.waitUntilExit()
        let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var paths = Set<String>(); var bundles = Set<String>()
        for line in text.split(separator: "\n") {
            let path = String(line)
            paths.insert(path)
            if let r = path.range(of: ".app/Contents/MacOS/") {
                let appName = path[..<r.lowerBound].split(separator: "/").last.map(String.init) ?? ""
                if !appName.isEmpty { bundles.insert(appName) }
            }
        }
        return (bundles, paths)
    }
}
