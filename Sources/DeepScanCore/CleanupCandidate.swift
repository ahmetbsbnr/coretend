// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// The candidate + evidence + risk/confidence model.
//
// Contract: a Detector NEVER deletes. It turns DiskGraph nodes into
// CleanupCandidates carrying *evidence*. SafetyCenter (existing) is the only
// thing that acts, and only after ExecutionRevalidator re-checks.

import Foundation
import SafetyCore

// MARK: - Categories

public enum CleanupCategory: String, Sendable, Codable, CaseIterable {
    case storage            // large / old loose files
    case appsAndLeftovers   // orphaned app data, uninstall residue
    case aiAndLLM           // model weights, agent caches, agent state
    case developer          // rebuildable build output / package caches
    case gitProjects        // repos, stale worktrees, stale build metadata
    case systemAndSettings  // orphaned launch agents, stale prefs
    case temporaryFiles     // /private/tmp, user temp, var/folders
    case installers         // dmg/pkg/xip/iso
    case cloud              // iCloud / CloudStorage cached objects
}

// MARK: - Risk

/// Four-way risk class for the Deep Scan UI. Maps onto SafetyCore.RiskLevel
/// for the executor (which only understands low/medium/high) — PROTECTED items
/// are never handed to the executor at all.
public enum RiskClass: String, Sendable, Codable, Comparable {
    case safe          // rebuildable / regenerable, no data loss
    case review        // probably fine but the user should look
    case highRisk      // shared data, system helper, network re-download, long rebuild
    case protected     // must never be selectable for deletion

    private var rank: Int {
        switch self { case .safe: 0; case .review: 1; case .highRisk: 2; case .protected: 3 }
    }
    public static func < (l: RiskClass, r: RiskClass) -> Bool { l.rank < r.rank }

    /// Executor-facing level. `protected` intentionally has no mapping — callers
    /// must filter protected candidates out before building operations.
    public var executorLevel: RiskLevel? {
        switch self {
        case .safe: .low
        case .review: .medium
        case .highRisk: .high
        case .protected: nil
        }
    }
}

// MARK: - Confidence

/// How sure we are of the *attribution* (what this is / who owns it).
/// A candidate whose subtree was not fully observed can never be `.confirmed`.
public enum Confidence: String, Sendable, Codable, Comparable {
    case confirmed     // exact, complete evidence
    case strong
    case probable
    case weak
    case unknown       // fail closed — treat as protected

    private var rank: Int {
        switch self { case .unknown: 0; case .weak: 1; case .probable: 2; case .strong: 3; case .confirmed: 4 }
    }
    public static func < (l: Confidence, r: Confidence) -> Bool { l.rank < r.rank }
}

// MARK: - Recoverability / reconstructability

public enum Recoverability: String, Sendable, Codable {
    case trashRestore      // moved to Trash, one click back
    case notRecoverable    // gone once removed (we still Trash, but warn)
}

/// What it costs to get the data back if the user regrets the removal.
public enum Reconstructability: String, Sendable, Codable {
    case regeneratesLocally     // a local rebuild / re-open recreates it
    case reinstallRequired      // package manager reinstall (no big download)
    case networkRedownload      // significant download
    case longCompile            // minutes+ of compilation
    case largeModelDownload     // GB-scale model re-fetch
    case irreplaceable          // cannot be reconstructed
    case unknown
}

// MARK: - Active state

public enum ActiveState: String, Sendable, Codable {
    case idle
    case inUseByRunningApp     // owning app is running
    case activelyWritten       // file mtime moved during the scan
    case unknown
}

// MARK: - Evidence

/// One machine-checkable reason. Evidence is additive; detectors attach as
/// many as apply. The UI renders `humanReadable`.
public struct Evidence: Sendable, Codable, Hashable {
    public enum Kind: String, Sendable, Codable {
        case pathPattern            // matched a known cache/tooling path
        case bundleIDExactMatch     // container name == an installed bundle id
        case bundleIDNoInstall      // container bundle id has no installed app
        case noSiblingOwner         // no other installed app could own this
        case lastActivityDays       // idle N days
        case reconstructionKnown    // known rebuild recipe exists
        case regenerableMarker      // .gitignore / lockfile / manifest proves rebuild
        case subtreeIncomplete      // scan did not finish this subtree -> fail closed
        case gitState               // repo dirty / stash / local-only commit / unverified remote
        case gitClean               // repo clean + HEAD on a verified remote
        case runningProcess         // a process holds / owns this
        case cloudBacked            // iCloud / provider file
        case sizeThreshold          // large enough to matter
        case ageThreshold          // old enough to matter
        case userStateMarker        // memory / history / auth / config -> PROTECTED
        case sharedVendorDir        // generic vendor dir, multiple possible owners
        case mountBoundary          // node crosses into another volume
        case duplicateRemote        // another clone points at the same git remote
    }
    public let kind: Kind
    public let humanReadable: String
    public let detail: String?
    public init(_ kind: Kind, _ humanReadable: String, detail: String? = nil) {
        self.kind = kind
        self.humanReadable = humanReadable
        self.detail = detail
    }
}

// MARK: - Candidate

public struct CleanupCandidate: Sendable, Codable, Identifiable {
    public let id: UUID
    public let path: String
    public let canonicalPath: String
    public let category: CleanupCategory
    public let subcategory: String          // detector-defined, e.g. "modelWeights", "gitWorktreeStale"
    public let detector: String             // which detector produced this

    public let logicalBytes: Int64
    public let allocatedBytes: Int64
    /// Truthful label: we never claim exact bytes back on APFS.
    public let estimatedReclaimableBytes: Int64

    public let owner: String?               // "LM Studio", "com.acme.App", nil
    public let confidence: Confidence
    public let risk: RiskClass
    public let recoverability: Recoverability
    public let reconstructability: Reconstructability
    public let lastActivity: Date?
    public let activeState: ActiveState

    public let evidence: [Evidence]
    public let protectedReason: String?     // set iff risk == .protected
    /// What the user should do. Never `.remove` for protected candidates.
    public enum RecommendedAction: String, Sendable, Codable {
        case remove, review, keep, evictCloudCopy
    }
    public let recommendedAction: RecommendedAction
    /// May this be selected by default? Extremely conservative — see policy in
    /// DefaultSelectionPolicy.
    public let defaultSelected: Bool

    /// A short, non-fear-based line for the UI's "WHY" field.
    public let rationale: String
    /// A short line for the UI's "WHAT HAPPENS IF REMOVED?" field.
    public let ifRemoved: String

    public init(id: UUID = UUID(), path: String, canonicalPath: String,
                category: CleanupCategory, subcategory: String, detector: String,
                logicalBytes: Int64, allocatedBytes: Int64, estimatedReclaimableBytes: Int64,
                owner: String?, confidence: Confidence, risk: RiskClass,
                recoverability: Recoverability, reconstructability: Reconstructability,
                lastActivity: Date?, activeState: ActiveState, evidence: [Evidence],
                protectedReason: String?, recommendedAction: RecommendedAction,
                defaultSelected: Bool, rationale: String, ifRemoved: String) {
        self.id = id
        self.path = path
        self.canonicalPath = canonicalPath
        self.category = category
        self.subcategory = subcategory
        self.detector = detector
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
        self.estimatedReclaimableBytes = estimatedReclaimableBytes
        self.owner = owner
        self.confidence = confidence
        self.risk = risk
        self.recoverability = recoverability
        self.reconstructability = reconstructability
        self.lastActivity = lastActivity
        self.activeState = activeState
        self.evidence = evidence
        self.protectedReason = protectedReason
        self.recommendedAction = recommendedAction
        self.defaultSelected = defaultSelected
        self.rationale = rationale
        self.ifRemoved = ifRemoved
    }
}

// MARK: - Detector contract

/// Detectors are pure functions over a DiskGraph. They never touch the disk
/// beyond the cheap re-stat calls the graph already did. They must be
/// deterministic: the same graph in yields the same candidates out.
public protocol Detector: Sendable {
    /// Stable identifier, used in evidence + journal.
    var id: String { get }
    var category: CleanupCategory { get }
    func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate]
}

/// Facts the engine gathers once and hands to every detector, so detectors do
/// not each re-enumerate `/Applications` or re-run `git`.
public struct DetectorContext: Sendable {
    public let home: URL
    public let installedApps: [InstalledApp]
    public let runningBundleIDs: Set<String>
    public let runningExecutablePaths: Set<String>
    public let scanStartedAt: Date
    public let scanFinishedAt: Date
    /// Repos discovered by GitProjectAnalyzer, shared with duplicate detection.
    public let gitRepos: [GitRepoFacts]

    public init(home: URL, installedApps: [InstalledApp], runningBundleIDs: Set<String>,
                runningExecutablePaths: Set<String>, scanStartedAt: Date, scanFinishedAt: Date,
                gitRepos: [GitRepoFacts]) {
        self.home = home
        self.installedApps = installedApps
        self.runningBundleIDs = runningBundleIDs
        self.runningExecutablePaths = runningExecutablePaths
        self.scanStartedAt = scanStartedAt
        self.scanFinishedAt = scanFinishedAt
        self.gitRepos = gitRepos
    }
}
