// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// DeepScanPresentation — pure, UI-framework-free view models for the Deep Scan
// screens (spec §3/§4/§5/§6/§10/§11/§21/§22/§28/§29/§30).
//
// The SwiftUI layer in CoreTendApp binds to these. Nothing here imports
// SwiftUI, so all of it is unit-testable. It also never mutates the disk.

import Foundation

// MARK: - Humanized labels (no raw enum names in the UI)

public extension RiskClass {
    var displayName: String {
        switch self {
        case .safe: "Low"
        case .review: "Review"
        case .highRisk: "High"
        case .protected: "Protected"
        }
    }
}

public extension Confidence {
    var displayName: String {
        switch self {
        case .confirmed: "Confirmed"
        case .strong: "Strong"
        case .probable: "Probable"
        case .weak: "Weak"
        case .unknown: "Unknown"
        }
    }
}

public extension Reconstructability {
    var displayName: String {
        switch self {
        case .regeneratesLocally: "Rebuilds locally"
        case .reinstallRequired: "Needs reinstall"
        case .networkRedownload: "Re-downloads"
        case .longCompile: "Long rebuild"
        case .largeModelDownload: "Large re-download"
        case .irreplaceable: "Cannot rebuild"
        case .unknown: "Unknown rebuild cost"
        }
    }
}

public extension CleanupCategory {
    var displayName: String {
        switch self {
        case .storage: "Large / Old"
        case .appsAndLeftovers: "Apps & Leftovers"
        case .aiAndLLM: "AI & LLM"
        case .developer: "Developer"
        case .gitProjects: "Git Projects"
        case .systemAndSettings: "System & Settings"
        case .temporaryFiles: "Temporary Files"
        case .installers: "Installers"
        case .cloud: "Cloud"
        }
    }
}

public extension AIDataType {
    var displayName: String {
        switch self {
        case .modelWeights: "Models"
        case .downloadCache: "Download cache"
        case .compiledModelCache: "Compiled model cache"
        case .updatePayload: "Update payload"
        case .tempFiles: "Temporary files"
        case .pluginCache: "Plugin cache"
        case .runtimeCache: "Runtime cache"
        case .userMemory: "Memory"
        case .conversationHistory: "Conversation history"
        case .projectState: "Project state"
        case .auth: "Sign-in"
        case .config: "Configuration"
        case .extensionsPlugins: "Extensions / plugins"
        case .unknownData: "Unknown"
        }
    }
}

public extension ActiveState {
    var displayName: String {
        switch self {
        case .idle: "Idle"
        case .inUseByRunningApp: "App is open"
        case .activelyWritten: "Being written"
        case .unknown: "Unknown"
        }
    }
}

// MARK: - Byte formatting

public enum DeepScanFormat {
    public static func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
    public static func relativeAge(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "Unknown" }
        let days = Int(now.timeIntervalSince(date) / 86_400)
        if days <= 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 30 { return "\(days) days ago" }
        if days < 365 { return "\(days / 30) months ago" }
        return "\(days / 365) years ago"
    }
}

// MARK: - Display row

public struct DeepScanDisplayRow: Sendable, Identifiable {
    public var id: UUID { candidate.id }
    public let candidate: CleanupCandidate

    public var what: String { candidate.rationale.isEmpty ? candidate.subcategory : candidate.rationale }
    public var whereText: String { candidate.canonicalPath }
    public var size: String { DeepScanFormat.bytes(candidate.logicalBytes) }
    public var allocatedSize: String { DeepScanFormat.bytes(candidate.allocatedBytes) }
    public var estimatedReclaimable: String {
        candidate.risk == .protected ? "—" : "≈ " + DeepScanFormat.bytes(candidate.estimatedReclaimableBytes)
    }
    public var whyBullets: [String] { candidate.evidence.map { $0.humanReadable } }
    public var confidence: String { candidate.confidence.displayName }
    public var risk: String { candidate.risk.displayName }
    public var reconstructability: String { candidate.reconstructability.displayName }
    public var lastActivity: String { DeepScanFormat.relativeAge(candidate.lastActivity) }
    public var owner: String { candidate.owner ?? "—" }
    public var ifRemoved: String { candidate.ifRemoved }
    public var protectedReason: String? { candidate.protectedReason }

    public enum DefaultAction: String, Sendable { case selectable, review, keep, evictCloudCopy }
    public var defaultAction: DefaultAction {
        switch candidate.recommendedAction {
        case .remove: candidate.defaultSelected ? .selectable : .review
        case .review: .review
        case .keep: .keep
        case .evictCloudCopy: .evictCloudCopy
        }
    }
    public var isProtected: Bool { candidate.risk == .protected }
    public var isSelectableByDefault: Bool { candidate.defaultSelected }

    public init(_ candidate: CleanupCandidate) { self.candidate = candidate }
}

// MARK: - Filtering / sorting / paging

public struct DeepScanFilter: Sendable, Equatable {
    public var searchText: String = ""
    public var category: CleanupCategory? = nil
    public var maxRisk: RiskClass? = nil        // show items at or below this risk
    public var minConfidence: Confidence? = nil
    public var minBytes: Int64 = 0
    public var protectedOnly = false
    public var reviewableOnly = false           // excludes protected
    public init() {}
}

public enum DeepScanSort: String, Sendable, CaseIterable {
    case size, risk, lastActivity, confidence

    func areInIncreasingOrder(_ a: CleanupCandidate, _ b: CleanupCandidate) -> Bool {
        switch self {
        case .size: return a.logicalBytes > b.logicalBytes
        case .risk: return a.risk > b.risk
        case .confidence: return a.confidence > b.confidence
        case .lastActivity:
            return (a.lastActivity ?? .distantPast) > (b.lastActivity ?? .distantPast)
        }
    }
}

/// Bounded, virtualization-friendly results model. The UI asks for a page; it
/// never binds a list to the full candidate array (see PERFORMANCE.md §28).
public struct DeepScanResultsModel: Sendable {
    public let all: [CleanupCandidate]
    public var filter = DeepScanFilter()
    public var sort: DeepScanSort = .size

    public init(_ candidates: [CleanupCandidate]) { self.all = candidates }

    public func matches(_ c: CleanupCandidate) -> Bool {
        if filter.protectedOnly && c.risk != .protected { return false }
        if filter.reviewableOnly && c.risk == .protected { return false }
        if let cat = filter.category, c.category != cat { return false }
        if let maxRisk = filter.maxRisk, c.risk > maxRisk { return false }
        if let minConf = filter.minConfidence, c.confidence < minConf { return false }
        if c.logicalBytes < filter.minBytes { return false }
        if !filter.searchText.isEmpty {
            let q = filter.searchText.lowercased()
            let hay = (c.canonicalPath + " " + (c.owner ?? "") + " " + c.subcategory + " "
                       + c.rationale).lowercased()
            if !hay.contains(q) { return false }
        }
        return true
    }

    public var filteredCount: Int { all.lazy.filter(matches).count }

    /// A single page of rows, already filtered + sorted.
    public func page(offset: Int, limit: Int) -> [DeepScanDisplayRow] {
        let filtered = all.filter(matches).sorted(by: sort.areInIncreasingOrder)
        guard offset < filtered.count else { return [] }
        return filtered[offset..<min(offset + limit, filtered.count)].map(DeepScanDisplayRow.init)
    }

    /// Reviewable reclaimable total for the current filter (protected excluded).
    public func reclaimableBytes() -> Int64 {
        all.lazy.filter(matches).filter { $0.risk != .protected }
            .reduce(0) { $0 + $1.estimatedReclaimableBytes }
    }
}

// MARK: - Category / AI-tool / Git grouping

public struct DeepScanCategoryGroup: Sendable, Identifiable {
    public var id: String { category.rawValue }
    public let category: CleanupCategory
    public let count: Int
    public let reviewableBytes: Int64
    public let protectedCount: Int
}

public struct DeepScanAIToolGroup: Sendable, Identifiable {
    public var id: String { tool }
    public let tool: String
    public struct DataTypeBucket: Sendable, Identifiable {
        public var id: String { dataType }
        public let dataType: String                 // AIDataType.displayName
        public let rows: [DeepScanDisplayRow]
        public let bytes: Int64
        public let allProtected: Bool
    }
    public let buckets: [DataTypeBucket]
    public var totalBytes: Int64 { buckets.reduce(0) { $0 + $1.bytes } }
}

public struct DeepScanGitRepoRow: Sendable, Identifiable {
    public var id: String { facts.workdir }
    public let facts: GitRepoFacts
    public var classification: String { facts.safety.rawValue.uppercased() }
    public var explanation: String {
        switch facts.safety {
        case .green: "Everything important is preserved on a verified remote."
        case .yellow: "Remote verification is incomplete — review before removing."
        case .red: "Deleting this repository could lose local work."
        }
    }
    public var subordinateCandidates: [DeepScanDisplayRow]   // build output, stale worktrees
}

public enum DeepScanGrouping {
    public static func categories(_ candidates: [CleanupCandidate]) -> [DeepScanCategoryGroup] {
        Dictionary(grouping: candidates, by: { $0.category }).map { cat, items in
            DeepScanCategoryGroup(
                category: cat, count: items.count,
                reviewableBytes: items.filter { $0.risk != .protected }
                    .reduce(0) { $0 + $1.estimatedReclaimableBytes },
                protectedCount: items.filter { $0.risk == .protected }.count)
        }.sorted { $0.reviewableBytes > $1.reviewableBytes }
    }

    public static func aiTools(_ candidates: [CleanupCandidate]) -> [DeepScanAIToolGroup] {
        let ai = candidates.filter { $0.category == .aiAndLLM }
        return Dictionary(grouping: ai, by: { $0.owner ?? "Other" }).map { tool, items in
            let byType = Dictionary(grouping: items, by: { $0.subcategory })
            let buckets = byType.map { type, rows -> DeepScanAIToolGroup.DataTypeBucket in
                let display = AIDataType(rawValue: type)?.displayName ?? type
                return .init(
                    dataType: display,
                    rows: rows.sorted { $0.logicalBytes > $1.logicalBytes }.map(DeepScanDisplayRow.init),
                    bytes: rows.reduce(0) { $0 + $1.logicalBytes },
                    allProtected: rows.allSatisfy { $0.risk == .protected })
            }.sorted { $0.bytes > $1.bytes }
            return DeepScanAIToolGroup(tool: tool, buckets: buckets)
        }.sorted { $0.totalBytes > $1.totalBytes }
    }

    public static func gitRepos(_ candidates: [CleanupCandidate],
                                facts: [GitRepoFacts]) -> [DeepScanGitRepoRow] {
        facts.map { f in
            let subs = candidates.filter {
                $0.category == .gitProjects && $0.subcategory != "repository"
                && $0.canonicalPath.hasPrefix(f.workdir)
            }
            return DeepScanGitRepoRow(facts: f,
                subordinateCandidates: subs.map(DeepScanDisplayRow.init))
        }.sorted { ($0.facts.workdirLogicalBytes) > ($1.facts.workdirLogicalBytes) }
    }
}

// MARK: - Scan phases + progress (spec §3)

public enum DeepScanPhase: String, Sendable, CaseIterable {
    case preparing = "Preparing"
    case enumerating = "Enumerating filesystem"
    case indexing = "Indexing metadata"
    case analyzingApps = "Analyzing applications"
    case analyzingAI = "Analyzing AI / LLM storage"
    case analyzingDeveloper = "Analyzing developer projects"
    case analyzingGit = "Analyzing Git repositories"
    case analyzingLeftovers = "Analyzing leftovers"
    case finalizing = "Finalizing evidence"
    case done = "Done"
    case cancelledPartial = "Partial scan"
}

public struct DeepScanProgressModel: Sendable {
    public var phase: DeepScanPhase = .preparing
    public var nodesScanned: Int = 0
    public var bytesObserved: Int64 = 0
    public var permissionDeniedCount: Int = 0
    public var startedAt: Date = Date()
    public var isPaused: Bool = false

    public init() {}
    public var elapsed: TimeInterval { Date().timeIntervalSince(startedAt) }
    public var isPartial: Bool { phase == .cancelledPartial }
    /// Ordinal progress across phases — real, not a fabricated percentage.
    public var phaseIndex: Int { DeepScanPhase.allCases.firstIndex(of: phase) ?? 0 }
    public var phaseCount: Int { DeepScanPhase.allCases.count - 2 }   // minus done + partial
}

// MARK: - Permission state (spec §2/§22)

public enum DeepScanPermissionState: String, Sendable {
    case fullDiskAccess = "Full Disk Access"
    case partialAccess = "Partial Access"
    case protectedByOS = "Protected by macOS"
    case scanError = "Scan error"
}

public struct DeepScanPermissionProbe: Sendable {
    public init() {}
    /// Heuristic, read-only: try to list a couple of TCC-gated locations. Full
    /// access ⇒ readable; otherwise Partial. Never writes.
    public func probe(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> DeepScanPermissionState {
        let gated = [
            home.appendingPathComponent("Library/Application Support/com.apple.TCC"),
            home.appendingPathComponent("Library/Mail"),
            home.appendingPathComponent("Library/Safari"),
        ]
        let fm = FileManager.default
        var readable = 0, present = 0
        for g in gated where fm.fileExists(atPath: g.path) {
            present += 1
            if (try? fm.contentsOfDirectory(atPath: g.path)) != nil { readable += 1 }
        }
        if present == 0 { return .partialAccess }        // can't tell — assume limited
        return readable == present ? .fullDiskAccess : .partialAccess
    }
}

// MARK: - Cleanup plan (spec §21/§22)

public struct DeepScanCleanupPlan: Sendable {
    public struct Line: Sendable, Identifiable {
        public var id: UUID { row.id }
        public let row: DeepScanDisplayRow
    }
    public let selected: [Line]
    public let totalLogicalBytes: Int64
    public let estimatedReclaimableBytes: Int64
    public let riskSummary: [String: Int]              // risk.displayName -> count
    public let rebuildCostSummary: [String: Int]       // reconstructability.displayName -> count
    public let movedToTrash: [String]                  // canonical paths
    public let protectedHeldBack: [DeepScanDisplayRow] // selected-but-protected, refused
    public let changedSinceScan: [ChangedItem]

    public struct ChangedItem: Sendable, Identifiable {
        public var id: String { path }
        public let path: String
        public let reason: String                      // "App is now running", …
    }

    /// Build a plan from the user's selection. `revalidation`, if supplied,
    /// annotates items that changed since the scan.
    public static func build(selectedIDs: Set<UUID>,
                             from candidates: [CleanupCandidate],
                             revalidation: RevalidationOutcome? = nil) -> DeepScanCleanupPlan {
        let chosen = candidates.filter { selectedIDs.contains($0.id) }
        let actionable = chosen.filter { $0.risk != .protected }
        let protectedRows = chosen.filter { $0.risk == .protected }.map(DeepScanDisplayRow.init)

        var risk: [String: Int] = [:], rebuild: [String: Int] = [:]
        for c in actionable {
            risk[c.risk.displayName, default: 0] += 1
            rebuild[c.reconstructability.displayName, default: 0] += 1
        }
        let changed: [ChangedItem] = (revalidation?.rejected ?? []).map {
            ChangedItem(path: $0.candidate.canonicalPath, reason: $0.reason)
        }
        let willTrash = (revalidation?.approvedForExecution ?? actionable).map { $0.canonicalPath }

        return DeepScanCleanupPlan(
            selected: actionable.map { .init(row: DeepScanDisplayRow($0)) },
            totalLogicalBytes: actionable.reduce(0) { $0 + $1.logicalBytes },
            estimatedReclaimableBytes: actionable.reduce(0) { $0 + $1.estimatedReclaimableBytes },
            riskSummary: risk,
            rebuildCostSummary: rebuild,
            movedToTrash: willTrash,
            protectedHeldBack: protectedRows,
            changedSinceScan: changed)
    }
}
