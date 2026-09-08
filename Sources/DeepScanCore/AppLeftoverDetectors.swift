// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// AppOwnershipResolver + OrphanedAppDetector.
//
// Ownership is decided by *exact bundle-ID match* against the installed-app
// census (app itself or an embedded helper), never by substring name guessing.
// A leftover is only proposed when: the container's bundle ID has no installed
// owner, AND no sibling installed app plausibly owns it, AND it has been idle.
// Even then, weak (name-only) matches are REVIEW/PROTECTED and system-level
// helpers are HIGH_RISK at minimum.

import Foundation

/// Resolves "who owns this directory?" for the per-user Library subtrees that
/// hold app data.
public struct AppOwnershipResolver: Sendable {
    public let installedApps: [InstalledApp]
    private let ownedBundleIDs: Set<String>

    public init(installedApps: [InstalledApp]) {
        self.installedApps = installedApps
        self.ownedBundleIDs = installedApps.reduce(into: Set<String>()) { $0.formUnion($1.ownedBundleIDs) }
    }

    public enum Ownership: Sendable, Equatable {
        case ownedByInstalledApp(bundleID: String)
        case noInstalledOwner(bundleID: String)
        case notBundleShaped        // folder name is not a bundle id
    }

    /// `folderName` is the last path component of a container / group-container
    /// / app-support / preferences entry.
    public func resolve(folderName: String) -> Ownership {
        let trimmed = folderName.hasSuffix(".plist")
            ? String(folderName.dropLast(6)) : folderName
        // Bundle-ID shape: at least one dot, reverse-DNS-ish, no spaces.
        guard trimmed.contains("."), !trimmed.contains(" "),
              trimmed.split(separator: ".").count >= 2 else {
            return .notBundleShaped
        }
        if ownedBundleIDs.contains(trimmed) {
            return .ownedByInstalledApp(bundleID: trimmed)
        }
        // A group container "group.com.acme.App" — strip the "group." prefix.
        if trimmed.hasPrefix("group."),
           ownedBundleIDs.contains(String(trimmed.dropFirst(6))) {
            return .ownedByInstalledApp(bundleID: String(trimmed.dropFirst(6)))
        }
        // Prefix ownership: "com.acme.App.Helper" owned if "com.acme.App" is.
        let parts = trimmed.split(separator: ".")
        for cut in stride(from: parts.count - 1, through: 2, by: -1) {
            let prefix = parts.prefix(cut).joined(separator: ".")
            if ownedBundleIDs.contains(prefix) {
                return .ownedByInstalledApp(bundleID: prefix)
            }
        }
        return .noInstalledOwner(bundleID: trimmed)
    }
}

public struct OrphanedAppDetector: Detector {
    public let id = "orphaned-app-data"
    public let category: CleanupCategory = .appsAndLeftovers
    public let idleThresholdDays: Int
    public init(idleThresholdDays: Int = 90) { self.idleThresholdDays = idleThresholdDays }

    /// Home-relative parents whose direct children are per-app containers.
    static let containerParents = [
        "Library/Containers",
        "Library/Group Containers",
        "Library/Application Support",
        "Library/Caches",
        "Library/Preferences",
        "Library/Saved Application State",
        "Library/HTTPStorages",
        "Library/WebKit",
        "Library/Logs",
    ]

    public func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate] {
        let resolver = AppOwnershipResolver(installedApps: context.installedApps)
        let home = context.home.standardizedFileURL.path
        let model = RiskConfidenceModel()
        var out: [CleanupCandidate] = []

        for parentRel in Self.containerParents {
            let parentPath = home + "/" + parentRel
            guard graph.node(at: parentPath) != nil else { continue }
            let isSystemLevel = parentRel.hasPrefix("Library/Logs")   // conservative example
            for child in graph.children(of: parentPath) {
                let name = (child.canonicalPath as NSString).lastPathComponent
                let ownership = resolver.resolve(folderName: name)
                guard case let .noInstalledOwner(bundleID) = ownership else { continue }

                let idleDays = child.modifiedAt.map {
                    Int(Date().timeIntervalSince($0) / 86_400)
                } ?? Int.max
                let subtreeComplete = graph.subtreeFullyObserved(child.canonicalPath)

                var evidence: [Evidence] = [
                    Evidence(.bundleIDNoInstall,
                        "No installed app declares the bundle ID “\(bundleID)”", detail: name),
                    Evidence(.noSiblingOwner,
                        "No installed app or helper claims this identifier"),
                ]
                if idleDays != .max {
                    evidence.append(Evidence(.lastActivityDays,
                        "Last changed about \(idleDays) days ago"))
                }
                if !subtreeComplete {
                    evidence.append(Evidence(.subtreeIncomplete, "Not fully scanned"))
                }
                // Weak/idle gating.
                let idleEnough = idleDays >= idleThresholdDays
                let confidenceFloor: Confidence = idleEnough ? .probable : .weak

                var verdict = model.evaluate(evidence: evidence, subtreeComplete: subtreeComplete,
                    reconstruction: .reinstallRequired, activeState: .idle, gitSafety: nil)
                // Never below REVIEW here; system-level at least HIGH_RISK.
                var risk = max(verdict.risk, .review)
                if isSystemLevel { risk = max(risk, .highRisk) }
                if !idleEnough { risk = max(risk, .highRisk) }
                verdict = RiskConfidenceModel.Verdict(
                    confidence: min(verdict.confidence, confidenceFloor),
                    risk: risk, defaultSelected: false, protectedReason: verdict.protectedReason)

                out.append(CleanupCandidate(
                    path: child.path, canonicalPath: child.canonicalPath,
                    category: .appsAndLeftovers, subcategory: "orphanedContainer", detector: id,
                    logicalBytes: child.logicalBytes, allocatedBytes: child.allocatedBytes,
                    estimatedReclaimableBytes: child.allocatedBytes,
                    owner: bundleID, confidence: verdict.confidence, risk: verdict.risk,
                    recoverability: .trashRestore, reconstructability: .reinstallRequired,
                    lastActivity: child.modifiedAt, activeState: .idle, evidence: evidence,
                    protectedReason: verdict.protectedReason,
                    recommendedAction: .review, defaultSelected: false,
                    rationale: "Appears to belong to “\(bundleID)”, which is not installed.",
                    ifRemoved: "If you reinstall that app it will recreate this folder."))
            }
        }
        return out
    }
}
