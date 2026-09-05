// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Darwin

/// What CoreTend records so it can later move a Trashed item back to where it
/// came from. Emitted by `SafetyCenter` at the moment a real
/// `FileManager.trashItem` move succeeds — never for the permanent
/// `removeItem` fallback, which cannot be undone.
///
/// This is a plain value type on purpose: `SafetyCore` stays storage-agnostic
/// exactly as it does for `SafetyAuditEvent`. The persistence boundary is
/// `RestoreManifestSink`; `Persistence.Store` is the shipped implementation
/// and is the *only* place these (unredacted) paths are written to disk. See
/// `Documentation/RESTORE.md` and `Documentation/PRIVACY.md`.
public struct RestoreManifestRecord: Sendable, Equatable {
    /// The `ApprovedFileOperation.id` this move belongs to — the same value
    /// carried by the redacted `SafetyAuditEvent` rows, so a restore record
    /// and its audit trail can be correlated without the audit log ever
    /// holding a real path.
    public let operationID: UUID
    /// The real absolute location the item was moved *from* (validated,
    /// standardized). Sensitive — never redacted here, never logged.
    public let originalURL: URL
    /// The actual URL `FileManager.trashItem(at:resultingItemURL:)` reported
    /// after the move. macOS renames collisions in the Trash, so this is
    /// captured at execution time and never reconstructed from a filename.
    public let trashURL: URL
    public let isDirectory: Bool
    /// Logical size at execution (from the approved operation) — kept as
    /// supporting evidence for identity, not as a strong check.
    public let sizeBytes: Int64
    /// Original item's modification date at execution, when readable.
    public let modificationDate: Date?
    /// Volume UUID string of the Trash item — stable across mounts/reboots,
    /// unlike a device number. `nil` when the volume does not expose one.
    public let volumeUUID: String?
    /// POSIX inode of the Trash item, captured just after the move. Stable
    /// while the item exists on that volume; combined with `volumeUUID` this
    /// is the primary identity check on restore.
    public let inode: String?
    public let ruleID: String
    public let risk: RiskLevel
    public let date: Date

    public init(operationID: UUID, originalURL: URL, trashURL: URL, isDirectory: Bool,
                sizeBytes: Int64, modificationDate: Date?, volumeUUID: String?, inode: String?,
                ruleID: String, risk: RiskLevel, date: Date = Date()) {
        self.operationID = operationID
        self.originalURL = originalURL
        self.trashURL = trashURL
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.modificationDate = modificationDate
        self.volumeUUID = volumeUUID
        self.inode = inode
        self.ruleID = ruleID
        self.risk = risk
        self.date = date
    }
}

/// Durable sink for `RestoreManifestRecord`s. Analogous to `SafetyAuditSink`:
/// `SafetyCore` never touches SQLite. Unlike the audit sink, an implementation
/// stores **unredacted** filesystem locations, so it carries stricter privacy
/// obligations (local only, excluded from diagnostics/telemetry/exports,
/// user-clearable) — see `Persistence.Store`'s conformance.
public protocol RestoreManifestSink: Sendable {
    func recordRestoreManifest(_ record: RestoreManifestRecord) async
}

/// Why a restore was refused. Restore validation asks materially different
/// questions from delete validation (`PathValidator`): the destination is not
/// an allow-listed root but *exactly one recorded original location*, and the
/// source must be a real Trash item.
public enum RestoreValidationError: Error, Equatable, Sendable {
    case sourceMissing
    case sourceNotInTrash
    case destinationEscapesRecordedOriginal
    case destinationIsProtectedRoot
    case destinationParentMissing
    case destinationParentNotWritable
    case destinationOccupied
}

/// Validates a single restore move. Deliberately narrow: it never performs an
/// arbitrary-destination move — the destination is pinned to the recorded
/// original path, and the source must sit inside a Trash directory. This
/// complements, and does not replace, `PathValidator` (which governs the
/// delete direction).
public enum RestoreValidator {
    public static func validate(source: URL, destination: URL,
                                recordedOriginal: URL) throws(RestoreValidationError) {
        let src = source.standardizedFileURL
        let dst = destination.standardizedFileURL

        guard dst.path == recordedOriginal.standardizedFileURL.path else {
            throw .destinationEscapesRecordedOriginal
        }
        for root in PathValidator.protectedRoots where PathValidator.isPath(dst.path, under: root) {
            throw .destinationIsProtectedRoot
        }
        guard FileManager.default.fileExists(atPath: src.path) else { throw .sourceMissing }
        guard isInsideTrash(src) else { throw .sourceNotInTrash }

        let parent = dst.deletingLastPathComponent()
        var parentIsDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &parentIsDir),
              parentIsDir.boolValue else { throw .destinationParentMissing }
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw .destinationParentNotWritable
        }
        // Never overwrite. A collision is refused, never resolved by
        // renaming or replacing — see Documentation/RESTORE.md.
        guard !FileManager.default.fileExists(atPath: dst.path) else { throw .destinationOccupied }
    }

    /// The user Trash (`~/.Trash`) or a per-volume Trash (`/.Trashes/<uid>`).
    public static func isInsideTrash(_ url: URL) -> Bool {
        let standardized = url.standardizedFileURL
        return standardized.pathComponents.contains(".Trash")
            || standardized.path.contains("/.Trashes/")
    }
}

/// Small, dependency-free filesystem-identity reads used when capturing a
/// restore manifest and when re-checking a Trash item before restoring it.
/// Every call is a pure `stat`/`URLResourceValues` read — no enumeration, no
/// hashing, nothing that scales with a directory's size.
public enum FilesystemIdentity {
    public static func volumeUUID(of url: URL) -> String? {
        (try? url.resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString
    }

    /// POSIX inode via `lstat` (does not follow a final symlink), as a
    /// string for storage. `nil` when the path cannot be stat'd.
    public static func inode(atPath path: String) -> String? {
        var info = stat()
        guard lstat(path, &info) == 0 else { return nil }
        return String(info.st_ino)
    }

    public static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    public static func modificationDate(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
