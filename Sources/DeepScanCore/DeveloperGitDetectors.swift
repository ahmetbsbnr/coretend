// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Developer + Git detectors. All read-only; they emit evidence-carrying
// candidates. A git repository is NEVER default-selected; repo deletion always
// routes through explicit review + confirm. Safe sub-candidates (stale build
// output, stale worktree registrations) are separated out.

import Foundation

// MARK: - Developer build/output artifacts

public struct DeveloperStorageDetector: Detector {
    public let id = "developer-storage"
    public let category: CleanupCategory = .developer
    public init() {}

    /// (directory name, reconstruction, human note). Presence of a sibling
    /// manifest/lockfile is required before we call it regenerable.
    struct Rule { let name: String; let reconstruction: Reconstructability; let note: String
        let siblingMarkers: [String] }
    static let rules: [Rule] = [
        Rule(name: ".next", reconstruction: .regeneratesLocally, note: "Next.js build output",
             siblingMarkers: ["next.config.js", "next.config.mjs", "next.config.ts", "package.json"]),
        Rule(name: "dist", reconstruction: .regeneratesLocally, note: "bundler output",
             siblingMarkers: ["package.json", "vite.config.ts", "rollup.config.js"]),
        Rule(name: "build", reconstruction: .regeneratesLocally, note: "build output",
             siblingMarkers: ["package.json", "CMakeLists.txt", "Makefile"]),
        Rule(name: ".build", reconstruction: .longCompile, note: "SwiftPM build",
             siblingMarkers: ["Package.swift"]),
        Rule(name: "target", reconstruction: .longCompile, note: "Cargo build",
             siblingMarkers: ["Cargo.toml"]),
        Rule(name: "DerivedData", reconstruction: .longCompile, note: "Xcode DerivedData",
             siblingMarkers: []),
        Rule(name: "node_modules", reconstruction: .networkRedownload, note: "npm dependencies",
             siblingMarkers: ["package.json"]),
        Rule(name: ".venv", reconstruction: .networkRedownload, note: "Python virtualenv",
             siblingMarkers: ["pyproject.toml", "requirements.txt", "setup.py"]),
        Rule(name: "coverage", reconstruction: .regeneratesLocally, note: "coverage report",
             siblingMarkers: ["package.json", "pyproject.toml"]),
    ]

    public func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate] {
        let model = RiskConfidenceModel()
        var out: [CleanupCandidate] = []
        for node in graph.nodes where node.type == .directory {
            let name = (node.canonicalPath as NSString).lastPathComponent
            guard let rule = Self.rules.first(where: { $0.name == name }) else { continue }
            // Skip if this lives inside a .git dir or an .app bundle.
            if node.canonicalPath.contains("/.git/") || node.bundleContext != nil { continue }
            // A build/output dir *inside* a dependency store (node_modules,
            // .venv/site-packages, vendored Pods/Carthage) is part of an
            // installed package — deleting it breaks the package and it is NOT
            // locally regenerable (needs a reinstall). Only the top-level
            // dependency dir itself (its own rule) is a candidate.
            if name != "node_modules",
               node.canonicalPath.range(of: "/node_modules/") != nil
                || node.canonicalPath.range(of: "/site-packages/") != nil
                || node.canonicalPath.range(of: "/Pods/") != nil
                || node.canonicalPath.range(of: "/Carthage/") != nil {
                continue
            }

            let parent = node.parentCanonicalPath
            let siblings = parent.map { graph.children(of: $0).map { ($0.canonicalPath as NSString).lastPathComponent } } ?? []
            let hasMarker = rule.siblingMarkers.isEmpty
                || !Set(rule.siblingMarkers).isDisjoint(with: Set(siblings))

            let subtreeComplete = graph.subtreeFullyObserved(node.canonicalPath)
            var evidence: [Evidence] = [
                Evidence(.pathPattern, LocalizedText("deepscan.evidence.dev.build_output",
                    args: [name], fallback: "\(rule.note) directory named \(name)"),
                    detail: node.canonicalPath),
            ]
            if hasMarker {
                evidence.append(Evidence(.regenerableMarker, LocalizedText(
                    "deepscan.evidence.dev.manifest_present",
                    fallback: "A project manifest sits next to it, so it can be rebuilt"),
                    detail: rule.siblingMarkers.joined(separator: ", ")))
            }
            if !subtreeComplete {
                evidence.append(Evidence(.subtreeIncomplete, LocalizedText(
                    "deepscan.evidence.subtree_incomplete", fallback: "Not fully scanned")))
            }
            let verdict = model.evaluate(evidence: evidence, subtreeComplete: subtreeComplete,
                reconstruction: hasMarker ? rule.reconstruction : .unknown,
                activeState: .idle, gitSafety: nil)

            out.append(CleanupCandidate(
                path: node.path, canonicalPath: node.canonicalPath,
                category: .developer, subcategory: name, detector: id,
                logicalBytes: node.logicalBytes, allocatedBytes: node.allocatedBytes,
                estimatedReclaimableBytes: node.allocatedBytes,
                owner: nil, confidence: verdict.confidence, risk: verdict.risk,
                recoverability: .trashRestore,
                reconstructability: hasMarker ? rule.reconstruction : .unknown,
                lastActivity: node.modifiedAt, activeState: .idle, evidence: evidence,
                protectedReason: verdict.protectedReason,
                recommendedAction: verdict.risk == .safe ? .remove : .review,
                defaultSelected: verdict.defaultSelected,
                rationale: "\(rule.note); rebuildable from the project.",
                ifRemoved: reconstructionText(hasMarker ? rule.reconstruction : .unknown),
                rationaleText: LocalizedText("deepscan.reason.dev.build",
                    fallback: "\(rule.note); rebuildable from the project."),
                ifRemovedText: reconstructionLocalized(hasMarker ? rule.reconstruction : .unknown),
                protectedReasonText: verdict.protectedReasonText))
        }
        return out
    }

    func reconstructionLocalized(_ r: Reconstructability) -> LocalizedText {
        let key: String
        switch r {
        case .regeneratesLocally: key = "deepscan.ifremoved.dev.local"
        case .longCompile: key = "deepscan.ifremoved.dev.longcompile"
        case .networkRedownload: key = "deepscan.ifremoved.dev.redownload"
        case .reinstallRequired: key = "deepscan.ifremoved.dev.reinstall"
        case .largeModelDownload: key = "deepscan.ifremoved.dev.large"
        case .irreplaceable: key = "deepscan.ifremoved.dev.irreplaceable"
        case .unknown: key = "deepscan.ifremoved.dev.unknown"
        }
        return LocalizedText(key, fallback: reconstructionText(r))
    }

    func reconstructionText(_ r: Reconstructability) -> String {
        switch r {
        case .regeneratesLocally: "Recreated by the next build."
        case .longCompile: "Recreated by the next build (can take minutes)."
        case .networkRedownload: "Reinstalling dependencies re-downloads this."
        case .reinstallRequired: "Requires a reinstall."
        case .largeModelDownload: "Requires a large re-download."
        case .irreplaceable: "Cannot be recreated."
        case .unknown: "Recovery cost is unknown — review before removing."
        }
    }
}

// MARK: - Git repositories + stale git metadata

public struct GitProjectDetector: Detector {
    public let id = "git-project"
    public let category: CleanupCategory = .gitProjects
    public init() {}

    public func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        for facts in context.gitRepos {
            guard let node = graph.node(at: facts.workdir) else { continue }
            var evidence: [Evidence] = []
            if facts.safety == .green {
                evidence.append(Evidence(.gitClean, LocalizedText("deepscan.evidence.git.clean",
                    fallback: "Clean tree, no stashes, HEAD present on a verified remote")))
            } else {
                evidence.append(contentsOf: gitStateEvidence(facts))
            }
            let model = RiskConfidenceModel()
            // Repos are never regenerable locally; treat as irreplaceable unless GREEN.
            let verdict = model.evaluate(evidence: evidence,
                subtreeComplete: graph.subtreeFullyObserved(facts.workdir),
                reconstruction: facts.safety == .green ? .networkRedownload : .irreplaceable,
                activeState: .idle, gitSafety: facts.safety)

            out.append(CleanupCandidate(
                path: node.path, canonicalPath: node.canonicalPath,
                category: .gitProjects, subcategory: "repository", detector: id,
                logicalBytes: node.logicalBytes, allocatedBytes: node.allocatedBytes,
                estimatedReclaimableBytes: node.allocatedBytes,
                owner: facts.remotes.first?.value, confidence: verdict.confidence,
                risk: verdict.risk, recoverability: .trashRestore,
                reconstructability: facts.safety == .green ? .networkRedownload : .irreplaceable,
                lastActivity: facts.lastCommitDate, activeState: .idle, evidence: evidence,
                protectedReason: verdict.protectedReason,
                recommendedAction: .review,   // repos ALWAYS require explicit review
                defaultSelected: false,        // spec: a repo is never default-selected
                rationale: facts.safety == .green
                    ? "Clean clone; every commit is on a verified remote."
                    : "Repository has local-only work — keep it.",
                ifRemoved: facts.safety == .green
                    ? "You could re-clone it from \(facts.remotes.first?.value ?? "its remote")."
                    : "Local commits, stashes or edits would be lost.",
                rationaleText: facts.safety == .green
                    ? LocalizedText("deepscan.reason.git.green", fallback: "Clean clone; every commit is on a verified remote.")
                    : LocalizedText("deepscan.reason.git.red", fallback: "Repository has local-only work — keep it."),
                ifRemovedText: facts.safety == .green
                    ? LocalizedText("deepscan.ifremoved.git.green", args: [facts.remotes.first?.value ?? "its remote"],
                        fallback: "You could re-clone it from \(facts.remotes.first?.value ?? "its remote").")
                    : LocalizedText("deepscan.ifremoved.git.red", fallback: "Local commits, stashes or edits would be lost."),
                protectedReasonText: verdict.protectedReasonText))

            // Stale linked worktree registrations pointing nowhere.
            for wt in facts.worktreePaths where wt != facts.workdir {
                if !FileManager.default.fileExists(atPath: wt) {
                    out.append(staleWorktreeCandidate(repo: facts, missingPath: wt))
                }
            }
        }
        return out
    }

    func gitStateSummary(_ f: GitRepoFacts) -> String {
        var parts: [String] = []
        if f.hasStagedChanges || f.hasUnstagedChanges { parts.append("uncommitted changes") }
        if !f.untrackedNonIgnored.isEmpty { parts.append("\(f.untrackedNonIgnored.count) untracked files") }
        if f.stashCount > 0 { parts.append("\(f.stashCount) stash(es)") }
        if f.localOnlyCommitCount > 0 { parts.append("\(f.localOnlyCommitCount) unpushed commit(s)") }
        if f.remotes.isEmpty { parts.append("no remote") }
        else if !f.remoteVerified { parts.append("remote not verified") }
        return parts.isEmpty ? "state not fully verified" : parts.joined(separator: ", ")
    }

    /// One structured evidence entry per condition, so the UI localizes each.
    func gitStateEvidence(_ f: GitRepoFacts) -> [Evidence] {
        var ev: [Evidence] = []
        if f.hasStagedChanges || f.hasUnstagedChanges {
            ev.append(Evidence(.gitState, LocalizedText("deepscan.evidence.git.uncommitted", fallback: "Uncommitted changes")))
        }
        if !f.untrackedNonIgnored.isEmpty {
            ev.append(Evidence(.gitState, LocalizedText("deepscan.evidence.git.untracked",
                args: ["\(f.untrackedNonIgnored.count)"], fallback: "\(f.untrackedNonIgnored.count) untracked files")))
        }
        if f.stashCount > 0 {
            ev.append(Evidence(.gitState, LocalizedText("deepscan.evidence.git.stashes",
                args: ["\(f.stashCount)"], fallback: "\(f.stashCount) stash(es)")))
        }
        if f.localOnlyCommitCount > 0 {
            ev.append(Evidence(.gitState, LocalizedText("deepscan.evidence.git.unpushed",
                args: ["\(f.localOnlyCommitCount)"], fallback: "\(f.localOnlyCommitCount) unpushed commit(s)")))
        }
        if f.remotes.isEmpty {
            ev.append(Evidence(.gitState, LocalizedText("deepscan.evidence.git.no_remote", fallback: "No remote configured")))
        } else if !f.remoteVerified {
            ev.append(Evidence(.gitState, LocalizedText("deepscan.evidence.git.remote_unverified", fallback: "Remote not verified")))
        }
        if ev.isEmpty {
            ev.append(Evidence(.gitState, LocalizedText("deepscan.evidence.git.state_unverified", fallback: "Repository state not fully verified")))
        }
        return ev
    }

    func staleWorktreeCandidate(repo: GitRepoFacts, missingPath: String) -> CleanupCandidate {
        let ev = [Evidence(.gitState, LocalizedText("deepscan.evidence.git.stale_worktree",
            fallback: "Registered worktree path does not exist on disk"), detail: missingPath)]
        return CleanupCandidate(
            path: repo.gitDir + "/worktrees", canonicalPath: repo.gitDir + "/worktrees",
            category: .gitProjects, subcategory: "staleWorktreeRegistration", detector: id,
            logicalBytes: 0, allocatedBytes: 0, estimatedReclaimableBytes: 0,
            owner: nil, confidence: .strong, risk: .review, recoverability: .notRecoverable,
            reconstructability: .regeneratesLocally, lastActivity: repo.lastCommitDate,
            activeState: .idle, evidence: ev, protectedReason: nil,
            recommendedAction: .review, defaultSelected: false,
            rationale: "A worktree registration points at a folder that is gone.",
            ifRemoved: "Run `git worktree prune` — this only clears bookkeeping.",
            rationaleText: LocalizedText("deepscan.reason.git.stale_worktree",
                fallback: "A worktree registration points at a folder that is gone."),
            ifRemovedText: LocalizedText("deepscan.ifremoved.git.stale_worktree",
                fallback: "Run `git worktree prune` — this only clears bookkeeping."))
    }
}

// MARK: - Duplicate / abandoned clones of the same remote

public struct DuplicateProjectsDetector: Detector {
    public let id = "duplicate-projects"
    public let category: CleanupCategory = .gitProjects
    public init() {}

    public func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate] {
        // Group repos by normalized remote URL.
        var byRemote: [String: [GitRepoFacts]] = [:]
        for f in context.gitRepos {
            guard let url = f.remotes["origin"] ?? f.remotes.first?.value else { continue }
            byRemote[Self.normalize(url), default: []].append(f)
        }
        var out: [CleanupCandidate] = []
        for (remote, group) in byRemote where group.count > 1 {
            // Canonical = the one with local-only work / most recent commit; the
            // others are *reported*, never auto-selected, never "newest wins".
            let canonical = group.max { lhs, rhs in
                (lhs.isDirty ? 1 : 0, lhs.localOnlyCommitCount, lhs.lastCommitDate ?? .distantPast)
                    < (rhs.isDirty ? 1 : 0, rhs.localOnlyCommitCount, rhs.lastCommitDate ?? .distantPast)
            }
            for f in group where f.workdir != canonical?.workdir {
                guard let node = graph.node(at: f.workdir) else { continue }
                let ev = [
                    Evidence(.duplicateRemote, LocalizedText("deepscan.evidence.dup.remote",
                        args: [remote, canonical?.workdir ?? "another path"],
                        fallback: "Another clone of \(remote) exists at \(canonical?.workdir ?? "another path")"),
                        detail: f.workdir),
                    Evidence(.gitState, f.isDirty || f.localOnlyCommitCount > 0
                        ? LocalizedText("deepscan.evidence.dup.has_local_work", fallback: "This clone also has local-only work")
                        : LocalizedText("deepscan.evidence.dup.no_local_work", fallback: "This clone has no local-only work")),
                ]
                let risk: RiskClass = (f.isDirty || f.localOnlyCommitCount > 0 || f.stashCount > 0)
                    ? .protected : .review
                out.append(CleanupCandidate(
                    path: node.path, canonicalPath: node.canonicalPath,
                    category: .gitProjects, subcategory: "duplicateClone", detector: id,
                    logicalBytes: node.logicalBytes, allocatedBytes: node.allocatedBytes,
                    estimatedReclaimableBytes: node.allocatedBytes,
                    owner: remote, confidence: .strong, risk: risk,
                    recoverability: .trashRestore,
                    reconstructability: risk == .protected ? .irreplaceable : .networkRedownload,
                    lastActivity: f.lastCommitDate, activeState: .idle, evidence: ev,
                    protectedReason: risk == .protected ? "This duplicate has its own local-only work" : nil,
                    recommendedAction: .review, defaultSelected: false,
                    rationale: "Duplicate clone of \(remote).",
                    ifRemoved: risk == .protected
                        ? "Local-only work here would be lost — keep it."
                        : "You would still have the other clone; re-clone if needed.",
                    rationaleText: LocalizedText("deepscan.reason.dup", args: [remote],
                        fallback: "Duplicate clone of \(remote)."),
                    ifRemovedText: risk == .protected
                        ? LocalizedText("deepscan.ifremoved.dup.protected", fallback: "Local-only work here would be lost — keep it.")
                        : LocalizedText("deepscan.ifremoved.dup.review", fallback: "You would still have the other clone; re-clone if needed."),
                    protectedReasonText: risk == .protected
                        ? LocalizedText("deepscan.protected.dup_local_work", fallback: "This duplicate has its own local-only work")
                        : nil))
            }
        }
        return out
    }

    static func normalize(_ url: String) -> String {
        var s = url.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: "git@github.com:", with: "github.com/")
        s = s.replacingOccurrences(of: "https://", with: "")
        s = s.replacingOccurrences(of: "ssh://", with: "")
        if s.hasSuffix(".git") { s.removeLast(4) }
        if s.hasSuffix("/") { s.removeLast() }
        return s.lowercased()
    }
}
