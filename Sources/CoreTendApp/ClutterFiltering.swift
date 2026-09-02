// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Persistence

/// Path normalization for the My Clutter "exclude" actions. Deliberately
/// thin: `Store.addExclusion`/`.removeExclusion` already dedupe and persist
/// (`Tests/PersistenceTests/StoreTests.swift`), and `ScanEngine`'s own
/// prefix-match exclusion check already makes an excluded folder cover
/// everything under it, including symlinks, and works whether or not the
/// path's volume is currently mounted (`ScanExclusionTests`). This only
/// rejects strings that could never be a valid absolute path — it does not
/// require the path to exist right now.
enum ClutterExclusions {
    static func normalize(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        guard trimmed.count > 1 else { return trimmed } // "/" itself, edge case, left as-is
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    /// The exact path that would be recorded as an exclusion for `url` —
    /// the file itself, or its containing folder when `asFolder` is true.
    static func targetPath(for url: URL, asFolder: Bool) -> String? {
        normalize((asFolder ? url.deletingLastPathComponent() : url).path)
    }

    /// Mirrors `ScanEngine`'s own exclusion check (exact match or
    /// path-under-an-excluded-folder), so "is this row already excluded?"
    /// in the UI agrees with what a re-scan would actually skip.
    static func isExcluded(_ path: String, exclusions: [String]) -> Bool {
        exclusions.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}

/// Pure, injectable-dependency logic shared by My Clutter's three sub-modules
/// (Large & Old, Duplicates, Similar Images): name search and volume
/// awareness. No SwiftUI, no disk access at the type level — testable with
/// fixture URLs and a fake volume resolver.
enum ClutterSearch {
    /// Case-insensitive, diacritic-insensitive substring match against the
    /// file name and (optionally) the containing path, using the same
    /// locale-aware comparison Finder itself uses for search.
    static func matches(fileName: String, path: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return fileName.localizedStandardContains(trimmed) || path.localizedStandardContains(trimmed)
    }
}

/// A volume's stable identity, kept separate from its (mutable, possibly
/// duplicated) display name — two different external drives can share the
/// name "Untitled", so the identifier, not the name, is what filtering keys
/// on.
public struct VolumeInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }

    /// Sentinel used when a file's volume can no longer be resolved (e.g. an
    /// external/cloud volume unmounted after the scan that produced this
    /// finding). Never silently dropped or mislabeled as a real volume.
    public static let unavailable = VolumeInfo(id: "__unavailable__", name: "unavailable")
}

/// Resolves the volume a URL lives on. A protocol so tests can supply fixed,
/// deterministic volumes (including "unmounted since scan") without a real
/// disk or real external drives.
public protocol VolumeResolving: Sendable {
    func volumeInfo(for url: URL) -> VolumeInfo?
}

/// Real resolver: `.volumeIdentifierKey` is the stable per-volume identifier
/// (persists across mount/unmount, distinct even for two volumes sharing a
/// display name); `.volumeNameKey` is display-only.
public struct SystemVolumeResolver: VolumeResolving {
    public init() {}
    public func volumeInfo(for url: URL) -> VolumeInfo? {
        guard let values = try? url.resourceValues(forKeys: [.volumeNameKey, .volumeIdentifierKey]) else {
            return nil
        }
        let name = values.volumeName ?? url.deletingLastPathComponent().lastPathComponent
        if let identifier = values.volumeIdentifier {
            return VolumeInfo(id: "\(identifier)", name: name)
        }
        // Identifier unavailable but the volume itself resolved (rare, some
        // network mounts) — fall back to the name as a best-effort key rather
        // than dropping the file from every volume-scoped view.
        return VolumeInfo(id: name, name: name)
    }
}

enum ClutterVolumeGrouping {
    /// Distinct volumes present across `urls`, sorted by name, with
    /// unresolvable volumes collapsed into `.unavailable` (never silently
    /// excluded from the list).
    static func availableVolumes(for urls: [URL], resolver: VolumeResolving) -> [VolumeInfo] {
        var seen: [String: VolumeInfo] = [:]
        for url in urls {
            let info = resolver.volumeInfo(for: url) ?? .unavailable
            seen[info.id] = info
        }
        return seen.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// True if `url`'s volume matches `volumeID`, or `volumeID` is nil (no
    /// filter applied).
    static func matches(_ url: URL, volumeID: String?, resolver: VolumeResolving) -> Bool {
        guard let volumeID else { return true }
        let info = resolver.volumeInfo(for: url) ?? .unavailable
        return info.id == volumeID
    }
}

/// Shared "exclude from scans" surface for My Clutter's three sub-views.
/// Deliberately routes through the same `Store` exclusions table
/// `Settings` already uses — not a second exclusion system — so an
/// exclusion added from a My Clutter results row is the same one visible
/// and removable in Settings, and vice versa.
@MainActor
@Observable
final class ClutterExclusionsController {
    private(set) var exclusions: [String] = []

    func load() async {
        guard let store = AppEnvironment.shared.store else { return }
        exclusions = (try? await store.exclusions()) ?? []
    }

    /// Adds `path` (or its containing folder if `asFolder`) as an exclusion.
    /// Invalid paths (empty/relative) are silently ignored — the UI never
    /// offers a text field for this, only real URLs from scan results.
    func exclude(_ url: URL, asFolder: Bool) {
        guard let normalized = ClutterExclusions.targetPath(for: url, asFolder: asFolder),
              let store = AppEnvironment.shared.store else { return }
        Task {
            try? await store.addExclusion(path: normalized)
            exclusions = (try? await store.exclusions()) ?? exclusions
        }
    }

    func remove(_ path: String) {
        guard let store = AppEnvironment.shared.store else { return }
        Task {
            try? await store.removeExclusion(path: path)
            exclusions = (try? await store.exclusions()) ?? exclusions
        }
    }

    func isExcluded(_ url: URL) -> Bool {
        ClutterExclusions.isExcluded(url.path, exclusions: exclusions)
    }
}
