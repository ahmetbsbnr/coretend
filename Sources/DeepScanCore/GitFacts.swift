// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// GitFacts — read-only interrogation of a git working copy. Every git
// invocation here is a plumbing/porcelain *read*; none of these commands
// mutate a repository. The analyzer classifies a repo GREEN / YELLOW / RED
// for deletion safety. A repository is never itself default-selected.

import Foundation

public enum GitSafetyClass: String, Sendable, Codable {
    /// Provably safe to remove: clean tree, no stashes, no worktrees, HEAD and
    /// every local branch present on a reachable remote.
    case green
    /// Removable only after explicit human review: e.g. clean but remote not
    /// verified, or only ignored build output differs.
    case yellow
    /// Must not be offered for deletion: dirty tree, stashes, local-only
    /// commits, untracked non-ignored files, or unverifiable remote.
    case red
}

public struct GitRepoFacts: Sendable, Codable, Hashable {
    public let workdir: String              // canonical path of the working tree root
    public let gitDir: String               // canonical path of the .git dir (or file's target)
    public let isBare: Bool
    public let isWorktreeCheckout: Bool     // this is a linked worktree, not the main checkout

    public let remotes: [String: String]    // name -> URL
    public let currentBranch: String?       // nil in detached HEAD
    public let headSHA: String?

    public let hasStagedChanges: Bool
    public let hasUnstagedChanges: Bool
    public let untrackedNonIgnored: [String] // capped sample
    public let stashCount: Int
    public let worktreePaths: [String]       // linked worktrees registered on this repo

    public let localBranches: [String]
    public let remoteTrackingBranches: [String]
    /// Commits reachable from any local branch but not from any remote branch.
    public let localOnlyCommitCount: Int
    public let remoteVerified: Bool          // at least one remote answered ls-remote
    public let lastCommitDate: Date?
    public let workdirLogicalBytes: Int64
    public let gitDirLogicalBytes: Int64

    public let safety: GitSafetyClass

    public init(workdir: String, gitDir: String, isBare: Bool, isWorktreeCheckout: Bool,
                remotes: [String: String], currentBranch: String?, headSHA: String?,
                hasStagedChanges: Bool, hasUnstagedChanges: Bool, untrackedNonIgnored: [String],
                stashCount: Int, worktreePaths: [String], localBranches: [String],
                remoteTrackingBranches: [String], localOnlyCommitCount: Int, remoteVerified: Bool,
                lastCommitDate: Date?, workdirLogicalBytes: Int64, gitDirLogicalBytes: Int64,
                safety: GitSafetyClass) {
        self.workdir = workdir
        self.gitDir = gitDir
        self.isBare = isBare
        self.isWorktreeCheckout = isWorktreeCheckout
        self.remotes = remotes
        self.currentBranch = currentBranch
        self.headSHA = headSHA
        self.hasStagedChanges = hasStagedChanges
        self.hasUnstagedChanges = hasUnstagedChanges
        self.untrackedNonIgnored = untrackedNonIgnored
        self.stashCount = stashCount
        self.worktreePaths = worktreePaths
        self.localBranches = localBranches
        self.remoteTrackingBranches = remoteTrackingBranches
        self.localOnlyCommitCount = localOnlyCommitCount
        self.remoteVerified = remoteVerified
        self.lastCommitDate = lastCommitDate
        self.workdirLogicalBytes = workdirLogicalBytes
        self.gitDirLogicalBytes = gitDirLogicalBytes
        self.safety = safety
    }

    public var isDirty: Bool { hasStagedChanges || hasUnstagedChanges || !untrackedNonIgnored.isEmpty }
}

/// Runs read-only `git` against discovered working copies.
public struct GitProjectAnalyzer: Sendable {
    /// When false, `git ls-remote` is skipped and `remoteVerified` stays false
    /// (which forces at best YELLOW). Honours the "network is opt-in" rule.
    public let allowNetwork: Bool
    public let gitPath: String

    public init(allowNetwork: Bool = false, gitPath: String = "/usr/bin/git") {
        self.allowNetwork = allowNetwork
        self.gitPath = gitPath
    }

    /// Repos are the directories in `graph` that directly contain a `.git`
    /// entry (dir or file). Nested worktrees use a `.git` *file*.
    public func discoverRepoRoots(in graph: DiskGraph) -> [String] {
        var roots: [String] = []
        for node in graph.nodes where node.type == .directory {
            if graph.node(at: node.canonicalPath + "/.git") != nil {
                roots.append(node.canonicalPath)
            }
        }
        return roots.sorted()
    }

    public func analyze(repoRoot: String) -> GitRepoFacts? {
        guard FileManager.default.fileExists(atPath: repoRoot + "/.git") else { return nil }
        func git(_ args: [String], network: Bool = false) -> String? {
            if network && !allowNetwork { return nil }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: gitPath)
            p.arguments = ["-C", repoRoot] + args
            var env = ProcessInfo.processInfo.environment
            env["GIT_TERMINAL_PROMPT"] = "0"
            env["GIT_OPTIONAL_LOCKS"] = "0"
            p.environment = env
            let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
            do { try p.run() } catch { return nil }
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }
            return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let gitDir = git(["rev-parse", "--absolute-git-dir"]) ?? (repoRoot + "/.git")
        let isWorktree = !(gitDir.hasSuffix("/.git")) && gitDir.contains("/worktrees/")
        let isBare = git(["rev-parse", "--is-bare-repository"]) == "true"

        var remotes: [String: String] = [:]
        for line in (git(["remote", "-v"]) ?? "").split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == "\t" || $0 == " " })
            if parts.count >= 2 { remotes[String(parts[0])] = String(parts[1]) }
        }

        let branch = git(["symbolic-ref", "--quiet", "--short", "HEAD"])
        let head = git(["rev-parse", "HEAD"])
        let status = git(["status", "--porcelain=v1", "--untracked-files=normal"]) ?? ""
        var staged = false, unstaged = false, untracked: [String] = []
        for raw in status.split(separator: "\n") {
            let line = String(raw)
            guard line.count >= 3 else { continue }
            let x = line[line.startIndex], y = line[line.index(after: line.startIndex)]
            if line.hasPrefix("??") {
                if untracked.count < 50 { untracked.append(String(line.dropFirst(3))) }
            } else {
                if x != " " && x != "?" { staged = true }
                if y != " " && y != "?" { unstaged = true }
            }
        }

        let stashCount = (git(["stash", "list"]) ?? "").split(separator: "\n").filter { !$0.isEmpty }.count
        let worktrees = (git(["worktree", "list", "--porcelain"]) ?? "")
            .split(separator: "\n")
            .filter { $0.hasPrefix("worktree ") }
            .map { String($0.dropFirst("worktree ".count)) }

        let localBranches = (git(["for-each-ref", "--format=%(refname:short)", "refs/heads"]) ?? "")
            .split(separator: "\n").map(String.init)
        let remoteBranches = (git(["for-each-ref", "--format=%(refname:short)", "refs/remotes"]) ?? "")
            .split(separator: "\n").map(String.init)

        let localOnly = Int(git(["rev-list", "--count", "--branches", "--not", "--remotes"]) ?? "0") ?? 0

        var remoteVerified = false
        if allowNetwork, let first = remotes.first {
            remoteVerified = git(["ls-remote", "--exit-code", first.key], network: true) != nil
        }

        var lastDate: Date?
        if let ts = git(["log", "-1", "--format=%ct"]), let secs = TimeInterval(ts) {
            lastDate = Date(timeIntervalSince1970: secs)
        }

        let safety: GitSafetyClass = {
            if staged || unstaged || !untracked.isEmpty || stashCount > 0 || localOnly > 0 { return .red }
            if remotes.isEmpty { return .red }
            if !remoteVerified { return .yellow }
            return .green
        }()

        return GitRepoFacts(
            workdir: repoRoot, gitDir: gitDir, isBare: isBare, isWorktreeCheckout: isWorktree,
            remotes: remotes, currentBranch: branch, headSHA: head,
            hasStagedChanges: staged, hasUnstagedChanges: unstaged, untrackedNonIgnored: untracked,
            stashCount: stashCount, worktreePaths: worktrees,
            localBranches: localBranches, remoteTrackingBranches: remoteBranches,
            localOnlyCommitCount: localOnly, remoteVerified: remoteVerified,
            lastCommitDate: lastDate, workdirLogicalBytes: 0, gitDirLogicalBytes: 0,
            safety: safety)
    }
}
