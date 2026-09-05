// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import SystemMetrics
import Persistence

/// The logical-vs-physical figures for the most recently completed Cleanup
/// scan, as already recorded in Storage Timeline — never a fresh scan run
/// just to populate this screen (see `Documentation/APFS_INTELLIGENCE.md`
/// "Why this doesn't re-scan").
struct APFSFilesAnalyzed: Sendable, Equatable {
    let scanDate: Date
    let logicalBytes: Int64
    /// nil when any category in that scan lacked an allocated-size
    /// measurement — never a partial figure presented as complete.
    let physicalBytes: Int64?
}

/// Combines the real, local measurements APFS Intelligence presents:
/// volume capacity (`APFSVolumeInspector`, a pure Foundation/Darwin read)
/// and the logical/physical totals already captured by the last Cleanup
/// scan (read from Storage Timeline, never re-scanned here). No filesystem
/// mutation, no subprocess, no privileged call anywhere in this type.
enum APFSIntelligenceService {
    static func volumeInfo(path: URL = FileManager.default.homeDirectoryForCurrentUser) -> APFSVolumeInfo {
        APFSVolumeInspector.inspect(path: path)
    }

    /// `store` is injectable so tests read from a throwaway database instead
    /// of the real `~/Library/Application Support/CoreTend` singleton.
    static func filesAnalyzed(store: Store?) async -> APFSFilesAnalyzed? {
        guard let store,
              let snapshot = try? await store.latestTimelineSnapshot(scope: "cleanup") else { return nil }
        let categories = (try? await store.timelineCategories(snapshotID: snapshot.id)) ?? []
        // An empty scan is a real "nothing found" measurement (0), not a
        // missing one — only a category that *was* found but lacks its own
        // physicalBytes turns the whole total unavailable.
        let physical: Int64? = categories.reduce(Int64?.some(0)) { partial, category in
            guard let partial, let bytes = category.physicalBytes else { return nil }
            return partial + bytes
        }
        return APFSFilesAnalyzed(scanDate: snapshot.date, logicalBytes: snapshot.totalBytes, physicalBytes: physical)
    }
}
