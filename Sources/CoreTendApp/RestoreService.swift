// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence
import SafetyCore

/// Maps a restore item's *live* availability to the reversibility vocabulary
/// the Advisor already uses. This is the one place `.restorableByCoreTend` is
/// ever produced, and only when a manifest exists **and** the Trash item is
/// currently present, identity-checked, and its destination is clear — never
/// merely because CoreTend normally uses the Trash. When the Trash has been
/// emptied there is nothing left for CoreTend *or* Finder to put back, so the
/// item is honestly `.irreversible`; while the Trash item still exists but
/// something blocks an automatic restore, Finder "Put Back" may still work,
/// so it stays `.trash`.
enum RestoreReversibility {
    static func of(_ availability: RestoreAvailability) -> AdvisorReversibility {
        switch availability {
        case .available:
            return .restorableByCoreTend
        case .missingFromTrash:
            return .irreversible
        case .destinationOccupied, .parentMissing, .parentNotWritable,
             .invalidIdentity, .volumeUnavailable, .alreadyRestored:
            return .trash
        }
    }
}

/// Live availability of one restore-manifest item. Computed cheaply on load
/// and refresh — a few `stat` / `URLResourceValues` reads per item, never a
/// content hash and never a directory walk, so a list of thousands of
/// historical items stays responsive.
enum RestoreAvailability: String, Sendable, Equatable {
    /// Trash item present, identity matches, original location is clear.
    case available
    /// Something already occupies the original location — a restore would
    /// overwrite it, so it is refused, never resolved.
    case destinationOccupied
    /// The original parent directory no longer exists.
    case parentMissing
    /// The original parent directory exists but is not writable.
    case parentNotWritable
    /// The recorded Trash URL no longer exists (Trash emptied, or the item
    /// was moved/deleted through Finder).
    case missingFromTrash
    /// The recorded Trash URL exists but is not the item CoreTend moved
    /// there (inode / volume / directory-ness mismatch).
    case invalidIdentity
    /// The recorded source volume is not currently mounted.
    case volumeUnavailable
    /// Already moved back to its original location.
    case alreadyRestored

    var isRestorable: Bool { self == .available }

    /// The `missing`/`identity` facts are about the source and are worth
    /// persisting back to the manifest so the item stops being offered.
    /// `volumeUnavailable` is transient (plug the drive back in); the
    /// destination-side states can change at any moment and are recomputed
    /// every load, never stored.
    var persistedState: RestoreManifestState? {
        switch self {
        case .missingFromTrash: return .missingFromTrash
        case .invalidIdentity: return .invalidIdentity
        case .alreadyRestored: return .restored
        default: return nil
        }
    }
}

/// One manifest item plus its freshly computed availability and a
/// non-sensitive short location for the main list.
struct RestoreItemView: Identifiable, Sendable, Equatable {
    let item: RestoreManifestItem
    let availability: RestoreAvailability
    var id: String { item.id }

    /// `<home>/…/Downloads` — enough to recognize the item without putting a
    /// full private path in the always-visible list. The exact path lives
    /// behind a disclosure in the detail row.
    var shortLocation: String {
        RestoreDisplay.shortLocation(item.originalPath)
    }

    var name: String { (item.originalPath as NSString).lastPathComponent }
}

/// Restore-manifest items grouped by the CoreTend operation that produced
/// them — one cleanup / uninstall / recovery-plan run.
struct RestoreOperationGroup: Identifiable, Sendable, Equatable {
    let operationID: String
    let date: Date
    let ruleID: String
    let items: [RestoreItemView]

    var id: String { operationID }
    var itemCount: Int { items.count }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.item.sizeBytes } }
    var restorableCount: Int { items.filter { $0.availability.isRestorable }.count }
    var allMissing: Bool { !items.isEmpty && items.allSatisfy { $0.availability == .missingFromTrash } }
    var allRestored: Bool { !items.isEmpty && items.allSatisfy { $0.availability == .alreadyRestored } }
}

enum RestoreDisplay {
    static func shortLocation(_ path: String) -> String {
        let dir = (path as NSString).deletingLastPathComponent
        let home = NSHomeDirectory()
        var p = dir
        if p == home || p.hasPrefix(home + "/") { p = "<home>" + p.dropFirst(home.count) }
        let comps = p.split(separator: "/").map(String.init)
        guard comps.count > 4 else { return p.isEmpty ? "/" : p }
        return (comps.prefix(2) + ["…"] + comps.suffix(2)).joined(separator: "/")
    }
}

/// Per-item and summary outcome of a restore run. Never atomic across items:
/// each is validated and moved independently, and a failure in one never
/// rolls back another.
struct RestoreOutcome: Identifiable, Sendable, Equatable {
    enum Result: Sendable, Equatable {
        case restored
        case skipped(RestoreAvailability)
        case failed(String)
    }
    let itemID: String
    let name: String
    let bytes: Int64
    let result: Result
    var id: String { itemID }
}

struct RestoreExecutionSummary: Sendable, Equatable {
    let outcomes: [RestoreOutcome]

    var requested: Int { outcomes.count }
    var restored: [RestoreOutcome] { outcomes.filter { $0.result == .restored } }
    var restoredCount: Int { restored.count }
    var restoredBytes: Int64 { restored.reduce(0) { $0 + $1.bytes } }
    var conflictCount: Int { outcomes.filter { $0.result == .skipped(.destinationOccupied) }.count }
    var unavailableCount: Int {
        outcomes.filter {
            switch $0.result {
            case .skipped(let a): return a != .destinationOccupied
            default: return false
            }
        }.count
    }
    var failedCount: Int {
        outcomes.filter { if case .failed = $0.result { return true } else { return false } }.count
    }
}

/// Owns every filesystem move a restore performs. The UI never moves a file
/// itself — it calls `load`/`refresh`/`restore`/`forgetHistory` here.
///
/// Flow per item: fresh manifest read → source validation (exists + identity)
/// → destination validation (`RestoreValidator`: pinned to the recorded
/// original, never an arbitrary path, never an overwrite) → `moveItem` →
/// manifest state update → redacted safety-audit event. A coarse
/// `.restore` Activity record is written once per run.
actor RestoreService {
    private let store: Store?
    private let fileManager = FileManager.default

    init(store: Store?) {
        self.store = store
    }

    // MARK: - Load

    func load() async -> [RestoreOperationGroup] {
        guard let store else { return [] }
        try? await store.pruneRestoreManifests()
        let items = (try? await store.restoreManifestItems()) ?? []
        var views: [RestoreItemView] = []
        for item in items {
            let availability = Self.availability(of: item, fileManager: fileManager)
            // Persist sticky source-side transitions so a gone item is not
            // offered again on the next load.
            if let newState = availability.persistedState, newState != item.state {
                try? await store.setRestoreManifestState(id: item.id, state: newState)
            }
            views.append(RestoreItemView(item: item, availability: availability))
        }
        return Self.group(views)
    }

    // MARK: - Restore

    func restore(itemIDs: [String]) async -> RestoreExecutionSummary {
        guard let store else { return RestoreExecutionSummary(outcomes: []) }
        var outcomes: [RestoreOutcome] = []
        for id in itemIDs {
            // Re-read every item immediately before acting: the review list
            // is a snapshot, the filesystem is not.
            guard let item = try? await store.restoreManifestItem(id: id) else {
                outcomes.append(RestoreOutcome(itemID: id, name: id, bytes: 0,
                                               result: .skipped(.missingFromTrash)))
                continue
            }
            let name = (item.originalPath as NSString).lastPathComponent
            let availability = Self.availability(of: item, fileManager: fileManager)
            guard availability == .available else {
                if let newState = availability.persistedState, newState != item.state {
                    try? await store.setRestoreManifestState(id: id, state: newState)
                }
                outcomes.append(RestoreOutcome(itemID: id, name: name, bytes: item.sizeBytes,
                                               result: .skipped(availability)))
                continue
            }

            let source = URL(fileURLWithPath: item.trashPath)
            let destination = URL(fileURLWithPath: item.originalPath)
            do {
                try RestoreValidator.validate(source: source, destination: destination,
                                              recordedOriginal: destination)
            } catch {
                outcomes.append(RestoreOutcome(itemID: id, name: name, bytes: item.sizeBytes,
                                               result: .skipped(Self.map(error))))
                continue
            }

            do {
                try fileManager.moveItem(at: source, to: destination)
            } catch {
                await store.recordSafetyEvent(SafetyAuditEvent(
                    operationID: UUID(uuidString: item.operationID) ?? UUID(), stage: .error,
                    path: destination.path, ruleID: "restore.\(item.ruleID)",
                    risk: RiskLevel(rawValue: item.risk) ?? .low, size: item.sizeBytes,
                    result: "restore move failed"))
                outcomes.append(RestoreOutcome(itemID: id, name: name, bytes: item.sizeBytes,
                                               result: .failed("move failed")))
                continue
            }

            try? await store.setRestoreManifestState(id: id, state: .restored, restoredAt: Date())
            await store.recordSafetyEvent(SafetyAuditEvent(
                operationID: UUID(uuidString: item.operationID) ?? UUID(), stage: .executed,
                path: destination.path, ruleID: "restore.\(item.ruleID)",
                risk: RiskLevel(rawValue: item.risk) ?? .low, size: item.sizeBytes,
                result: "restored from trash"))
            outcomes.append(RestoreOutcome(itemID: id, name: name, bytes: item.sizeBytes, result: .restored))
        }

        let summary = RestoreExecutionSummary(outcomes: outcomes)
        _ = try? await store.recordActivity(ActivityRecord(
            kind: .restore,
            summary: "Restore Center: restored \(summary.restoredCount) of \(summary.requested) item(s)",
            itemCount: summary.restoredCount, bytes: summary.restoredBytes))
        return summary
    }

    // MARK: - Forget

    /// Removes CoreTend's restore records only. Never touches the Trash.
    func forgetHistory() async {
        try? await store?.clearRestoreManifests()
    }

    func hasHistory() async -> Bool {
        ((try? await store?.restoreManifestCount()) ?? 0) > 0
    }

    // MARK: - Pure helpers

    static func map(_ error: RestoreValidationError) -> RestoreAvailability {
        switch error {
        case .sourceMissing, .sourceNotInTrash: return .missingFromTrash
        case .destinationOccupied: return .destinationOccupied
        case .destinationParentMissing: return .parentMissing
        case .destinationParentNotWritable: return .parentNotWritable
        case .destinationEscapesRecordedOriginal, .destinationIsProtectedRoot: return .invalidIdentity
        }
    }

    static func availability(of item: RestoreManifestItem, fileManager: FileManager) -> RestoreAvailability {
        if item.state == .restored { return .alreadyRestored }
        if item.state == .missingFromTrash { return .missingFromTrash }
        if item.state == .invalidIdentity { return .invalidIdentity }

        let trashURL = URL(fileURLWithPath: item.trashPath)
        guard fileManager.fileExists(atPath: item.trashPath) else {
            if let uuid = item.volumeUUID, !volumeIsMounted(uuid: uuid, fileManager: fileManager) {
                return .volumeUnavailable
            }
            return .missingFromTrash
        }

        if let recordedInode = item.inode,
           let currentInode = FilesystemIdentity.inode(atPath: item.trashPath),
           recordedInode != currentInode {
            return .invalidIdentity
        }
        if FilesystemIdentity.isDirectory(trashURL) != item.isDirectory {
            return .invalidIdentity
        }
        if let recordedUUID = item.volumeUUID,
           let currentUUID = FilesystemIdentity.volumeUUID(of: trashURL),
           recordedUUID != currentUUID {
            return .invalidIdentity
        }

        let destination = URL(fileURLWithPath: item.originalPath)
        let parent = destination.deletingLastPathComponent()
        var parentIsDir: ObjCBool = false
        guard fileManager.fileExists(atPath: parent.path, isDirectory: &parentIsDir), parentIsDir.boolValue else {
            return .parentMissing
        }
        if fileManager.fileExists(atPath: item.originalPath) { return .destinationOccupied }
        if !fileManager.isWritableFile(atPath: parent.path) { return .parentNotWritable }
        return .available
    }

    static func volumeIsMounted(uuid: String, fileManager: FileManager) -> Bool {
        let volumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeUUIDStringKey],
                                                    options: [.skipHiddenVolumes]) ?? []
        return volumes.contains { FilesystemIdentity.volumeUUID(of: $0) == uuid }
    }

    static func group(_ views: [RestoreItemView]) -> [RestoreOperationGroup] {
        var order: [String] = []
        var buckets: [String: [RestoreItemView]] = [:]
        for view in views {
            if buckets[view.item.operationID] == nil { order.append(view.item.operationID) }
            buckets[view.item.operationID, default: []].append(view)
        }
        return order.map { opID in
            let items = buckets[opID] ?? []
            let date = items.map(\.item.createdAt).min() ?? .distantPast
            return RestoreOperationGroup(operationID: opID, date: date,
                                         ruleID: items.first?.item.ruleID ?? "", items: items)
        }
    }
}
