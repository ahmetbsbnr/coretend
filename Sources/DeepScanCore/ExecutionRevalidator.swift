// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// ExecutionRevalidator — the last gate before SafetyCenter acts.
//
// Detectors ran against a *snapshot*. Between the scan and the click, the world
// can move: a file is rewritten, a repo goes dirty, an app launches, a path is
// swapped for a symlink, a volume is unmounted. This re-checks every selected
// candidate against the live filesystem and drops anything that changed or that
// should never have been actionable. It performs only stat()/lstat() reads and
// cheap `git status` — it never deletes. SafetyCenter (existing) does that,
// and re-validates the path a second time itself.

import Foundation
import SafetyCore
#if canImport(Darwin)
import Darwin
#endif

public struct RevalidationOutcome: Sendable {
    public struct Rejected: Sendable {
        public let candidate: CleanupCandidate
        public let reason: String
    }
    /// Candidates that still pass every check, ready to hand to SafetyCenter.
    public let approvedForExecution: [CleanupCandidate]
    /// Candidates removed from the batch, each with a human-readable reason
    /// that must be journalled.
    public let rejected: [Rejected]
}

public struct ExecutionRevalidator: Sendable {
    public let allowNetwork: Bool
    public init(allowNetwork: Bool = false) { self.allowNetwork = allowNetwork }

    /// `originalIdentities` maps canonicalPath -> the (dev,ino) the scan saw,
    /// so we can detect a path that now points at a different object.
    public func revalidate(_ selected: [CleanupCandidate],
                           originalIdentities: [String: FileIdentity],
                           runningBundleIDs: Set<String>,
                           gitAnalyzer: GitProjectAnalyzer = GitProjectAnalyzer()) -> RevalidationOutcome {
        var approved: [CleanupCandidate] = []
        var rejected: [RevalidationOutcome.Rejected] = []

        for c in selected {
            // 0. Protected candidates must never reach here.
            if c.risk == .protected || c.risk.executorLevel == nil {
                rejected.append(.init(candidate: c, reason: "Protected — not eligible for removal"))
                continue
            }
            if c.confidence == .unknown {
                rejected.append(.init(candidate: c, reason: "Attribution is UNKNOWN — failing closed"))
                continue
            }

            let path = c.canonicalPath
            guard let live = Self.lstat(path) else {
                rejected.append(.init(candidate: c, reason: "Path no longer exists"))
                continue
            }

            // 1. Path must not have become a symlink we would follow out.
            if (live.st_mode & S_IFMT) == S_IFLNK {
                rejected.append(.init(candidate: c, reason: "Path was replaced by a symlink"))
                continue
            }
            // 2. Not a device / socket / fifo now.
            let fmt = live.st_mode & S_IFMT
            if fmt != S_IFREG && fmt != S_IFDIR {
                rejected.append(.init(candidate: c, reason: "Path is now a special file"))
                continue
            }
            // 3. File identity unchanged (defends against path swap).
            if let want = originalIdentities[path] {
                let now = FileIdentity(device: UInt64(bitPattern: Int64(live.st_dev)), inode: live.st_ino)
                if now != want {
                    rejected.append(.init(candidate: c, reason: "Path now points to a different file"))
                    continue
                }
            }
            // 4. Active-write detection: mtime moved into the recent past.
            let mtime = TimeInterval(live.st_mtimespec.tv_sec)
            if Date().timeIntervalSince1970 - mtime < 5 {
                rejected.append(.init(candidate: c, reason: "File was just modified — may be in use"))
                continue
            }
            // 5. Owning app must not be running now.
            if let owner = c.owner,
               runningBundleIDs.contains(where: { $0.localizedCaseInsensitiveContains(owner) }) {
                rejected.append(.init(candidate: c, reason: "\(owner) is now running"))
                continue
            }
            // 6. Git safety re-check for anything under a repo.
            if c.category == .gitProjects || c.category == .developer {
                if let repoRoot = Self.enclosingRepoRoot(of: path),
                   let facts = gitAnalyzer.analyze(repoRoot: repoRoot),
                   facts.safety == .red {
                    rejected.append(.init(candidate: c, reason: "Git repository is now dirty or has unpushed work"))
                    continue
                }
            }

            approved.append(c)
        }
        return RevalidationOutcome(approvedForExecution: approved, rejected: rejected)
    }

    static func lstat(_ p: String) -> stat? {
        var st = stat()
        return p.withCString { Darwin.lstat($0, &st) == 0 ? st : nil }
    }

    static func enclosingRepoRoot(of path: String) -> String? {
        var dir = (path as NSString).deletingLastPathComponent
        while dir.count > 1 {
            if FileManager.default.fileExists(atPath: dir + "/.git") { return dir }
            dir = (dir as NSString).deletingLastPathComponent
        }
        return nil
    }
}
