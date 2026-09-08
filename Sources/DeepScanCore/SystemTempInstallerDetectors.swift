// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// System-hygiene, temp, installer, cloud and large/old detectors. All
// read-only and conservative. No undocumented performance claims are attached
// to any candidate — the `rationale` states only what the item is.

import Foundation

// MARK: - Orphaned launch agents / login-item remnants (detection only)

public struct SystemSettingsDetector: Detector {
    public let id = "system-settings"
    public let category: CleanupCategory = .systemAndSettings
    public init() {}

    static let agentDirsRelative = [
        "Library/LaunchAgents",
    ]

    public func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate] {
        let home = context.home.standardizedFileURL.path
        let resolver = AppOwnershipResolver(installedApps: context.installedApps)
        var out: [CleanupCandidate] = []
        for rel in Self.agentDirsRelative {
            let dir = home + "/" + rel
            guard graph.node(at: dir) != nil else { continue }
            for plist in graph.children(of: dir) where plist.canonicalPath.hasSuffix(".plist") {
                let label = (plist.canonicalPath as NSString).lastPathComponent
                    .replacingOccurrences(of: ".plist", with: "")
                guard case let .noInstalledOwner(bundleID) = resolver.resolve(folderName: label) else { continue }
                if bundleID.hasPrefix("com.apple.") { continue }   // Apple-managed agent
                let ev = [
                    Evidence(.bundleIDNoInstall, LocalizedText("deepscan.evidence.sysagent.no_app",
                        args: [label], fallback: "Launch agent “\(label)” has no matching installed app"),
                        detail: plist.canonicalPath),
                    Evidence(.pathPattern, LocalizedText("deepscan.evidence.path.launch_agents",
                        fallback: "Lives in ~/Library/LaunchAgents")),
                ]
                out.append(CleanupCandidate(
                    path: plist.path, canonicalPath: plist.canonicalPath,
                    category: .systemAndSettings, subcategory: "orphanedLaunchAgent", detector: id,
                    logicalBytes: plist.logicalBytes, allocatedBytes: plist.allocatedBytes,
                    estimatedReclaimableBytes: plist.allocatedBytes,
                    owner: bundleID, confidence: .probable, risk: .review,
                    recoverability: .trashRestore, reconstructability: .reinstallRequired,
                    lastActivity: plist.modifiedAt, activeState: .idle, evidence: ev,
                    protectedReason: nil, recommendedAction: .review, defaultSelected: false,
                    rationale: "A login/background job for an app that is not installed.",
                    ifRemoved: "The background job stops being scheduled at next login.",
                    rationaleText: LocalizedText("deepscan.reason.sysagent",
                        fallback: "A login/background job for an app that is not installed."),
                    ifRemovedText: LocalizedText("deepscan.ifremoved.sysagent",
                        fallback: "The background job stops being scheduled at next login.")))
            }
        }
        return out
    }
}

// MARK: - Temp files

public struct TempFilesDetector: Detector {
    public let id = "temp-files"
    public let category: CleanupCategory = .temporaryFiles
    public let minIdleHours: Int
    public init(minIdleHours: Int = 48) { self.minIdleHours = minIdleHours }

    public func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        let roots = ["/private/tmp",
                     context.home.appendingPathComponent("Library/Caches/TemporaryItems").path]
        for root in roots {
            guard graph.node(at: root) != nil else { continue }
            for child in graph.children(of: root) {
                let idleHours = child.modifiedAt.map { Int(Date().timeIntervalSince($0) / 3600) } ?? 0
                guard idleHours >= minIdleHours else { continue }        // known-active -> skip
                let ev = [
                    Evidence(.pathPattern, LocalizedText("deepscan.evidence.path.system_temp",
                        fallback: "Located in a system temporary directory"), detail: root),
                    Evidence(.ageThreshold, LocalizedText("deepscan.evidence.age.untouched_days",
                        args: ["\(idleHours / 24)"], fallback: "Untouched for about \(idleHours / 24) days")),
                ]
                let complete = graph.subtreeFullyObserved(child.canonicalPath)
                out.append(CleanupCandidate(
                    path: child.path, canonicalPath: child.canonicalPath,
                    category: .temporaryFiles, subcategory: "systemTemp", detector: id,
                    logicalBytes: child.logicalBytes, allocatedBytes: child.allocatedBytes,
                    estimatedReclaimableBytes: child.allocatedBytes,
                    owner: nil, confidence: complete ? .strong : .probable,
                    risk: complete ? .safe : .review, recoverability: .trashRestore,
                    reconstructability: .regeneratesLocally,
                    lastActivity: child.modifiedAt, activeState: .idle, evidence: ev,
                    protectedReason: nil,
                    recommendedAction: complete ? .remove : .review,
                    defaultSelected: false,   // even temp is opt-in by default here
                    rationale: "Old file in a temporary directory.",
                    ifRemoved: "Nothing — temporary directories are cleared on reboot anyway.",
                    rationaleText: LocalizedText("deepscan.reason.temp",
                        fallback: "Old file in a temporary directory."),
                    ifRemovedText: LocalizedText("deepscan.ifremoved.temp",
                        fallback: "Nothing — temporary directories are cleared on reboot anyway.")))
            }
        }
        return out
    }
}

// MARK: - Installers / disk images

public struct InstallerDetector: Detector {
    public let id = "installers"
    public let category: CleanupCategory = .installers
    public init() {}
    static let exts: Set<String> = ["dmg", "pkg", "mpkg", "xip", "iso"]

    public func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        for node in graph.nodes where node.type == .file {
            let ext = (node.canonicalPath as NSString).pathExtension.lowercased()
            guard Self.exts.contains(ext) else { continue }
            let ageDays = node.modifiedAt.map { Int(Date().timeIntervalSince($0) / 86_400) } ?? 0
            let ev = [
                Evidence(.pathPattern, LocalizedText("deepscan.evidence.installer.kind",
                    args: [".\(ext)"], fallback: "Installer / disk image (.\(ext))"), detail: node.canonicalPath),
                Evidence(.ageThreshold, LocalizedText("deepscan.evidence.age.days",
                    args: ["\(ageDays)"], fallback: "About \(ageDays) days old")),
                Evidence(.sizeThreshold, LocalizedText("deepscan.evidence.size",
                    args: [ByteCountFormatter.string(fromByteCount: node.logicalBytes, countStyle: .file)],
                    fallback: ByteCountFormatter.string(fromByteCount: node.logicalBytes, countStyle: .file))),
            ]
            out.append(CleanupCandidate(
                path: node.path, canonicalPath: node.canonicalPath,
                category: .installers, subcategory: ext, detector: id,
                logicalBytes: node.logicalBytes, allocatedBytes: node.allocatedBytes,
                estimatedReclaimableBytes: node.allocatedBytes,
                owner: nil, confidence: .probable,
                risk: .review, recoverability: .trashRestore,
                reconstructability: .networkRedownload,
                lastActivity: node.modifiedAt, activeState: .idle, evidence: ev,
                protectedReason: nil, recommendedAction: .review, defaultSelected: false,
                rationale: "A downloaded installer you have probably already used.",
                ifRemoved: "You would re-download the installer if you need it again.",
                rationaleText: LocalizedText("deepscan.reason.installer",
                    fallback: "A downloaded installer you have probably already used."),
                ifRemovedText: LocalizedText("deepscan.ifremoved.installer",
                    fallback: "You would re-download the installer if you need it again.")))
        }
        return out
    }
}

// MARK: - Cloud-backed objects (evict, never delete)

public struct CloudStorageDetector: Detector {
    public let id = "cloud-storage"
    public let category: CleanupCategory = .cloud
    public init() {}

    public func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        for node in graph.nodes where node.cloudRemoteOnly || node.canonicalPath.contains("/Library/CloudStorage/") {
            guard node.logicalBytes > 0 || node.allocatedBytes > 0 else { continue }
            let ev = [Evidence(.cloudBacked, LocalizedText("deepscan.evidence.cloud.backed",
                fallback: "Backed by a cloud provider (iCloud / CloudStorage)"), detail: node.canonicalPath)]
            out.append(CleanupCandidate(
                path: node.path, canonicalPath: node.canonicalPath,
                category: .cloud, subcategory: "cloudObject", detector: id,
                logicalBytes: node.logicalBytes, allocatedBytes: node.allocatedBytes,
                estimatedReclaimableBytes: node.allocatedBytes,
                owner: nil, confidence: .strong, risk: .protected,
                recoverability: .notRecoverable, reconstructability: .networkRedownload,
                lastActivity: node.modifiedAt, activeState: .idle, evidence: ev,
                protectedReason: "Cloud-backed — CoreTend will not delete this. Use “Free Up Space” in the provider instead.",
                recommendedAction: .evictCloudCopy, defaultSelected: false,
                rationale: "This file lives in the cloud; only a local copy is on disk.",
                ifRemoved: "Deleting it removes it from the cloud too. Evict the local copy instead.",
                rationaleText: LocalizedText("deepscan.reason.cloud",
                    fallback: "This file lives in the cloud; only a local copy is on disk."),
                ifRemovedText: LocalizedText("deepscan.ifremoved.cloud",
                    fallback: "Deleting it removes it from the cloud too. Evict the local copy instead."),
                protectedReasonText: LocalizedText("deepscan.protected.cloud",
                    fallback: "Cloud-backed — CoreTend will not delete this. Use “Free Up Space” in the provider instead.")))
        }
        return out
    }
}

// MARK: - Large / old loose files (storage overview, never selected)

public struct LargeOldFileDetector: Detector {
    public let id = "large-old-files"
    public let category: CleanupCategory = .storage
    public let minBytes: Int64
    public let minAgeDays: Int
    public init(minBytes: Int64 = 512 * 1024 * 1024, minAgeDays: Int = 180) {
        self.minBytes = minBytes; self.minAgeDays = minAgeDays
    }

    public func detect(in graph: DiskGraph, context: DetectorContext) -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        for node in graph.nodes where node.type == .file {
            guard node.logicalBytes >= minBytes, node.bundleContext == nil else { continue }
            let ageDays = node.modifiedAt.map { Int(Date().timeIntervalSince($0) / 86_400) } ?? 0
            guard ageDays >= minAgeDays else { continue }
            let ev = [
                Evidence(.sizeThreshold, LocalizedText("deepscan.evidence.size",
                    args: [ByteCountFormatter.string(fromByteCount: node.logicalBytes, countStyle: .file)],
                    fallback: ByteCountFormatter.string(fromByteCount: node.logicalBytes, countStyle: .file))),
                Evidence(.ageThreshold, LocalizedText("deepscan.evidence.age.not_modified_days",
                    args: ["\(ageDays)"], fallback: "Not modified in about \(ageDays) days")),
            ]
            out.append(CleanupCandidate(
                path: node.path, canonicalPath: node.canonicalPath,
                category: .storage, subcategory: "largeOldFile", detector: id,
                logicalBytes: node.logicalBytes, allocatedBytes: node.allocatedBytes,
                estimatedReclaimableBytes: node.allocatedBytes,
                owner: nil, confidence: .weak, risk: .review,
                recoverability: .trashRestore, reconstructability: .unknown,
                lastActivity: node.modifiedAt, activeState: .idle, evidence: ev,
                protectedReason: nil, recommendedAction: .review, defaultSelected: false,
                rationale: "A large file you have not opened in a long time.",
                ifRemoved: "Only you know if you still need this — review it.",
                rationaleText: LocalizedText("deepscan.reason.large",
                    fallback: "A large file you have not opened in a long time."),
                ifRemovedText: LocalizedText("deepscan.ifremoved.large",
                    fallback: "Only you know if you still need this — review it.")))
        }
        return out
    }
}
