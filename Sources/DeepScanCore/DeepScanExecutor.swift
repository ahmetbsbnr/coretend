// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// DeepScanExecutor — the ONLY bridge from a CleanupCandidate to a real
// filesystem change, and it does nothing itself: it filters, revalidates, then
// hands survivors to the pre-existing SafetyCore.SafetyCenter (Trash + audit
// journal). There is no `rm` here and no detector-owned deletion.
//
//   selected candidates
//     -> ExecutableSubsetPolicy   (spec §18: a very narrow SAFE subset)
//     -> ExecutionRevalidator     (spec §17/§18: re-check the live world)
//     -> SafetyCenter.approve     (PathValidator: protected roots / allowlist)
//     -> SafetyCenter.execute     (trashItem, audit events == the journal)
//
// A development-only feature gate (`DeepScanExecutionGate`) is OFF by default;
// with it off, `execute` refuses and returns everything as "gated".

import Foundation
import SafetyCore

// MARK: - Feature gate

/// Deep Scan execution is not enabled for normal production users yet.
/// Flip only in controlled QA. There is deliberately no persisted setting and
/// no UI switch that turns this on for end users.
public enum DeepScanExecutionGate {
    /// Process-wide opt-in. Default: disabled.
    nonisolated(unsafe) public static var isEnabled = false

    /// Env-var escape hatch for automated QA (`CORETEND_DEEPSCAN_EXEC=1`).
    public static var isEnabledResolved: Bool {
        isEnabled || ProcessInfo.processInfo.environment["CORETEND_DEEPSCAN_EXEC"] == "1"
    }
}

// MARK: - Executable-subset policy (§18)

public enum ExecutableSubsetPolicy {
    /// The only detectors whose output may ever be executed in this phase.
    public static let allowedDetectors: Set<String> = [
        "developer-storage",   // proven generated build output
        "temp-files",          // system temp, aged
        "ai-storage",          // ONLY the SAFE runtimeCache/tempFiles subcategories, checked below
    ]

    /// AI subcategories that are allowed through (everything else in aiAndLLM
    /// stays review/protected).
    public static let allowedAISubcategories: Set<String> = [
        AIDataType.runtimeCache.rawValue,
        AIDataType.tempFiles.rawValue,
        AIDataType.updatePayload.rawValue,
    ]

    public struct Rejection: Sendable { public let candidate: CleanupCandidate; public let reason: String }

    /// Returns the candidates that clear every §18 condition, plus a reason for
    /// each one held back.
    public static func partition(_ candidates: [CleanupCandidate])
        -> (eligible: [CleanupCandidate], rejected: [Rejection]) {
        var eligible: [CleanupCandidate] = []
        var rejected: [Rejection] = []
        for c in candidates {
            if let why = ineligibilityReason(c) {
                rejected.append(.init(candidate: c, reason: why))
            } else {
                eligible.append(c)
            }
        }
        return (eligible, rejected)
    }

    static func ineligibilityReason(_ c: CleanupCandidate) -> String? {
        guard allowedDetectors.contains(c.detector) else { return "detector not in the executable subset" }
        if c.detector == "ai-storage" && !allowedAISubcategories.contains(c.subcategory) {
            return "AI data type “\(c.subcategory)” is review-only"
        }
        if c.risk != .safe { return "risk is \(c.risk.rawValue), not safe" }
        if c.confidence < .strong { return "confidence is \(c.confidence.rawValue), below strong" }
        if c.activeState != .idle { return "not idle (\(c.activeState.rawValue))" }
        switch c.reconstructability {
        case .regeneratesLocally: break
        default: return "reconstruction is \(c.reconstructability.rawValue), not locally regenerable"
        }
        switch c.category {
        case .developer, .temporaryFiles, .aiAndLLM: break
        case .gitProjects: return "git repositories are never executed"
        case .cloud: return "cloud-backed data is never executed"
        case .appsAndLeftovers, .systemAndSettings: return "app/system leftovers stay review-only in this phase"
        case .storage, .installers: return "storage/installer items stay review-only"
        }
        // Evidence vetoes.
        let veto: Set<Evidence.Kind> = [
            .userStateMarker, .cloudBacked, .sharedVendorDir, .gitState, .gitClean,
            .mountBoundary, .subtreeIncomplete, .runningProcess, .duplicateRemote,
        ]
        if !Set(c.evidence.map(\.kind)).isDisjoint(with: veto) {
            return "evidence includes a protected/shared/incomplete marker"
        }
        return nil
    }
}

// MARK: - Report

public struct DeepScanExecutionReport: Sendable {
    public struct Item: Sendable {
        public let candidate: CleanupCandidate
        public let trashedFrom: String
        public let bytes: Int64
    }
    public struct Skip: Sendable {
        public let candidate: CleanupCandidate
        public let stage: String        // "gate" | "subset" | "revalidate" | "safetycenter"
        public let reason: String
    }
    public let executed: [Item]
    public let skipped: [Skip]
    public var bytesTrashed: Int64 { executed.reduce(0) { $0 + $1.bytes } }
    public var gated: Bool
}

// MARK: - Executor

public struct DeepScanExecutor: Sendable {
    public let revalidator: ExecutionRevalidator
    public init(revalidator: ExecutionRevalidator = ExecutionRevalidator()) {
        self.revalidator = revalidator
    }

    /// `identitiesByPath` comes from `DeepScanResult`. `runningBundleIDs` must
    /// be re-sampled by the caller immediately before calling this.
    public func execute(selected: [CleanupCandidate],
                        identitiesByPath: [String: FileIdentity],
                        runningBundleIDs: Set<String>,
                        allowedRoots: [URL],
                        auditSink: SafetyAuditSink?) async -> DeepScanExecutionReport {
        var skipped: [DeepScanExecutionReport.Skip] = []

        guard DeepScanExecutionGate.isEnabledResolved else {
            return DeepScanExecutionReport(
                executed: [],
                skipped: selected.map { .init(candidate: $0, stage: "gate",
                    reason: "Deep Scan execution is disabled (feature gate off)") },
                gated: true)
        }

        // 1. Narrow executable subset (§18).
        let (eligible, subsetRejected) = ExecutableSubsetPolicy.partition(selected)
        skipped += subsetRejected.map { .init(candidate: $0.candidate, stage: "subset", reason: $0.reason) }

        // 2. Live-world revalidation (§17/§18).
        let outcome = revalidator.revalidate(eligible,
            originalIdentities: identitiesByPath, runningBundleIDs: runningBundleIDs)
        skipped += outcome.rejected.map { .init(candidate: $0.candidate, stage: "revalidate", reason: $0.reason) }

        guard !outcome.approvedForExecution.isEmpty else {
            return DeepScanExecutionReport(executed: [], skipped: skipped, gated: false)
        }

        // 3. Hand to the ONE executor. No alternate path.
        let center = SafetyCenter(validator: PathValidator(allowedRoots: allowedRoots), sink: auditSink)
        var approved: [ApprovedFileOperation] = []
        var byOpID: [UUID: CleanupCandidate] = [:]
        for c in outcome.approvedForExecution {
            guard let level = c.risk.executorLevel else {
                skipped.append(.init(candidate: c, stage: "safetycenter", reason: "no executor risk level"))
                continue
            }
            do {
                let op = try await center.approve(
                    url: URL(fileURLWithPath: c.canonicalPath),
                    logicalSize: c.logicalBytes,
                    ruleID: "deepscan:\(c.detector):\(c.subcategory)",
                    risk: level)
                approved.append(op)
                byOpID[op.id] = c
            } catch {
                skipped.append(.init(candidate: c, stage: "safetycenter", reason: "\(error)"))
            }
        }

        let result = await center.execute(approved)
        var executed: [DeepScanExecutionReport.Item] = []
        for op in result.executed {
            guard let c = byOpID[op.id] else { continue }
            executed.append(.init(candidate: c, trashedFrom: op.url.path, bytes: op.logicalSize))
        }
        for (op, err) in result.skipped {
            guard let c = byOpID[op.id] else { continue }
            skipped.append(.init(candidate: c, stage: "safetycenter", reason: "\(err)"))
        }

        return DeepScanExecutionReport(executed: executed, skipped: skipped, gated: false)
    }
}
