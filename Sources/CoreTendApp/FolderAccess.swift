// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// A folder the user has granted, and the bookmark that keeps the grant.
///
/// In the sandboxed build, choosing a folder in an open panel grants access to
/// it **for this launch only**. A security-scoped bookmark is what makes the
/// grant survive a relaunch, which is the difference between a product and a
/// demo: without it, a user re-picks their Pictures folder every time they open
/// the app.
struct FolderGrant: Identifiable, Equatable, Sendable {
    let url: URL
    let bookmark: Data
    /// When the bookmark was created or last refreshed, so a stale one can be
    /// distinguished from one that simply has not been used yet.
    let granted: Date

    var id: String { url.path }
    var displayName: String { url.lastPathComponent }
}

enum FolderAccessError: Error, Equatable {
    /// The bookmark no longer resolves: the folder was deleted, renamed, or
    /// moved to a volume that is not mounted.
    case unresolvable(String)
    /// macOS refused to start scoped access. The grant is present but dead,
    /// and re-picking the folder is the only fix.
    case accessRefused(String)
    case couldNotBookmark(String)
}

/// Persistent access to folders the user chose.
///
/// ## The balance problem, and why this API is shaped like this
///
/// `startAccessingSecurityScopedResource()` must be paired with
/// `stopAccessingSecurityScopedResource()`. An unbalanced start leaks a kernel
/// resource for the life of the process, and macOS caps how many a process may
/// hold — so a leak does not fail where it happened, it fails much later when
/// an unrelated scan cannot open a folder. That is close to undebuggable.
///
/// A `start()`/`stop()` pair on this type would put the balance in the hands of
/// every caller, including callers inside `Task`s that can be cancelled between
/// the two. So there is no such pair. `withAccess(to:perform:)` owns both sides
/// and releases in a `defer`, which holds through a thrown error and through
/// cancellation.
///
/// ## Why it is used in both builds
///
/// The unsandboxed build does not need scoped access — it can read the folder
/// anyway — and `startAccessingSecurityScopedResource` returns `false` there
/// for an ordinary URL. That `false` is not an error, and treating it as one
/// would break the Developer ID build. Handling both in one path means the
/// sandboxed build is exercised by the same code every day rather than only at
/// release time.
@MainActor
@Observable
final class FolderAccess {
    static let shared = FolderAccess()

    private(set) var grants: [FolderGrant] = []

    static let defaultsKey = "grantedFolderBookmarks"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        grants = Self.load(from: defaults)
    }

    // MARK: - Granting

    /// Records a folder the user picked, replacing any previous grant for the
    /// same path.
    @discardableResult
    func grant(_ url: URL) throws -> FolderGrant {
        let bookmark: Data
        do {
            bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil)
        } catch {
            throw FolderAccessError.couldNotBookmark(url.path)
        }
        let grant = FolderGrant(url: url, bookmark: bookmark, granted: Date())
        grants.removeAll { $0.id == grant.id }
        grants.append(grant)
        persist()
        return grant
    }

    func revoke(_ url: URL) {
        grants.removeAll { $0.url.path == url.path }
        persist()
    }

    // MARK: - Using

    /// Runs `perform` with scoped access to `url` held for its whole duration.
    ///
    /// The grant is resolved fresh each time rather than cached: a bookmark can
    /// go stale between launches (the folder moved, the volume remounted), and
    /// a stale one silently resolves to the *old* location. Refreshing on
    /// resolve is what stops a scan quietly reading somewhere the user no
    /// longer means.
    func withAccess<T>(to url: URL, perform: () async throws -> T) async throws -> T {
        guard let grant = grants.first(where: { Self.covers($0.url, url) }) else {
            // No grant recorded. In the unsandboxed build that is normal — the
            // folder is simply readable — so this is not an error.
            return try await perform()
        }

        var isStale = false
        let resolved: URL
        do {
            resolved = try URL(
                resolvingBookmarkData: grant.bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale)
        } catch {
            throw FolderAccessError.unresolvable(grant.url.path)
        }

        let started = resolved.startAccessingSecurityScopedResource()
        // `false` means either a refusal or an ordinary unsandboxed URL, and
        // the two are indistinguishable here. Stopping is only correct when
        // starting succeeded — an unbalanced stop is as wrong as an unbalanced
        // start.
        defer { if started { resolved.stopAccessingSecurityScopedResource() } }

        if isStale {
            // Refresh while access is held, which is the only moment the new
            // bookmark can be created.
            try? refresh(grant, resolvedAt: resolved)
        }
        return try await perform()
    }

    private func refresh(_ grant: FolderGrant, resolvedAt url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        grants.removeAll { $0.id == grant.id }
        grants.append(FolderGrant(url: url, bookmark: bookmark, granted: Date()))
        persist()
    }

    /// Whether this build needs a grant before it can read `url`.
    ///
    /// Pure, so the "do I need to ask?" decision is testable without a sandbox.
    nonisolated static func needsGrant(for url: URL,
                           in grants: [FolderGrant],
                           capabilities: AppCapabilities = .forCurrentBuild()) -> Bool {
        guard capabilities.requiresUserSelectedFolders else { return false }
        return !grants.contains { covers($0.url, url) }
    }

    /// Whether a grant on `root` covers `candidate`.
    ///
    /// The separator is not optional. A bare `hasPrefix` says `/Users/xavier`
    /// is inside `/Users/x`, which would hand a scan access to a folder the
    /// user never granted — and this check existed twice with only one of them
    /// getting the boundary right, which is why it exists once now.
    nonisolated static func covers(_ root: URL, _ candidate: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let candidatePath = candidate.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    // MARK: - Persistence

    private func persist() {
        let encoded = grants.map { grant in
            ["path": grant.url.path,
             "bookmark": grant.bookmark,
             "granted": grant.granted.timeIntervalSince1970] as [String: Any]
        }
        defaults.set(encoded, forKey: Self.defaultsKey)
    }

    private static func load(from defaults: UserDefaults) -> [FolderGrant] {
        guard let raw = defaults.array(forKey: defaultsKey) as? [[String: Any]] else { return [] }
        return raw.compactMap { entry in
            guard let path = entry["path"] as? String,
                  let bookmark = entry["bookmark"] as? Data,
                  let stamp = entry["granted"] as? TimeInterval
            else { return nil }
            return FolderGrant(url: URL(fileURLWithPath: path),
                               bookmark: bookmark,
                               granted: Date(timeIntervalSince1970: stamp))
        }
    }
}
