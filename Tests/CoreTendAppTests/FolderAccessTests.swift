// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import CoreTendApp

/// Persistent folder grants for the sandboxed build.
///
/// The failure these guard against is not a crash. An unbalanced
/// `startAccessingSecurityScopedResource` leaks a kernel resource for the life
/// of the process, and macOS caps how many a process may hold — so the leak
/// does not fail where it happened. It fails much later, when an unrelated scan
/// cannot open a folder for no visible reason.
@Suite("Folder access")
@MainActor
struct FolderAccessTests {
    /// An isolated defaults suite per test, so grants never touch the real app's
    /// stored ones and tests cannot see each other's.
    private func makeAccess() -> (FolderAccess, UserDefaults, String) {
        let name = "coretend.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (FolderAccess(defaults: defaults), defaults, name)
    }

    private func temporaryFolder() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Granting

    @Test func aGrantSurvivesARelaunch() throws {
        let (access, defaults, suite) = makeAccess()
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try access.grant(folder)
        #expect(access.grants.count == 1)

        // A second instance reading the same defaults is what a relaunch is.
        let reopened = FolderAccess(defaults: defaults)
        #expect(reopened.grants.count == 1)
        #expect(reopened.grants.first?.url.path == folder.path)
        #expect(reopened.grants.first?.bookmark.isEmpty == false)
    }

    /// Granting the same folder twice must replace, not accumulate. A user who
    /// re-picks a folder has not created a second grant, and a list that grows
    /// on every pick is a list nobody can manage.
    @Test func grantingTheSameFolderTwiceReplaces() throws {
        let (access, defaults, suite) = makeAccess()
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try access.grant(folder)
        try access.grant(folder)
        #expect(access.grants.count == 1)
    }

    @Test func revokingRemovesTheGrantAndPersistsTheRemoval() throws {
        let (access, defaults, suite) = makeAccess()
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try access.grant(folder)
        access.revoke(folder)
        #expect(access.grants.isEmpty)
        #expect(FolderAccess(defaults: defaults).grants.isEmpty)
    }

    @Test func bookmarkingSomethingThatDoesNotExistFails() {
        let (access, defaults, suite) = makeAccess()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(throws: FolderAccessError.self) {
            try access.grant(URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))
        }
    }

    // MARK: - Using

    @Test func workRunsWithAccessHeld() async throws {
        let (access, defaults, suite) = makeAccess()
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try access.grant(folder)

        let result = try await access.withAccess(to: folder) { "scanned" }
        #expect(result == "scanned")
    }

    /// A folder with no grant is not an error. In the unsandboxed build that is
    /// the normal case — the folder is simply readable — and treating a missing
    /// grant as a failure would break the Developer ID product entirely.
    @Test func anUngrantedFolderStillRuns() async throws {
        let (access, defaults, suite) = makeAccess()
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let result = try await access.withAccess(to: folder) { 42 }
        #expect(result == 42)
    }

    /// A grant on a folder covers what is inside it, or every scan of a
    /// subdirectory would prompt again.
    @Test func aGrantCoversDescendants() async throws {
        let (access, defaults, suite) = makeAccess()
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let child = folder.appendingPathComponent("inner", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try access.grant(folder)

        let result = try await access.withAccess(to: child) { "inner scanned" }
        #expect(result == "inner scanned")
    }

    /// Access must be released even when the work throws. A `defer` is the only
    /// thing that holds through a thrown error and through cancellation, which
    /// is why there is no public start/stop pair to get wrong.
    @Test func accessIsReleasedWhenTheWorkThrows() async throws {
        struct Boom: Error {}
        let (access, defaults, suite) = makeAccess()
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try access.grant(folder)

        await #expect(throws: Boom.self) {
            try await access.withAccess(to: folder) { throw Boom() }
        }
        // Still usable afterwards: a leaked scope would eventually refuse.
        let second = try await access.withAccess(to: folder) { true }
        #expect(second)
    }

    /// Repeated use must not accumulate held scopes. macOS caps how many a
    /// process may hold, and the cap is reached long after the leak.
    @Test func repeatedUseDoesNotAccumulateHeldScopes() async throws {
        let (access, defaults, suite) = makeAccess()
        defer { defaults.removePersistentDomain(forName: suite) }
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try access.grant(folder)

        for index in 0..<200 {
            let value = try await access.withAccess(to: folder) { index }
            #expect(value == index)
        }
    }

    // MARK: - Deciding whether to ask

    /// The unsandboxed build never needs a grant, so it must never prompt.
    @Test func theUnsandboxedBuildNeverNeedsAGrant() {
        #expect(FolderAccess.needsGrant(
            for: URL(fileURLWithPath: "/Users/x/Pictures"),
            in: [],
            capabilities: .of(.developerID)) == false)
    }

    @Test func theSandboxedBuildNeedsAGrantForAnUncoveredFolder() {
        #expect(FolderAccess.needsGrant(
            for: URL(fileURLWithPath: "/Users/x/Pictures"),
            in: [],
            capabilities: .of(.appStore)))
    }

    @Test func aGrantedAncestorCoversTheFolder() {
        let grant = FolderGrant(url: URL(fileURLWithPath: "/Users/x"),
                                bookmark: Data([1]), granted: Date())
        #expect(FolderAccess.needsGrant(
            for: URL(fileURLWithPath: "/Users/x/Pictures"),
            in: [grant], capabilities: .of(.appStore)) == false)
    }

    /// Prefix matching must respect path boundaries. `/Users/xavier` is not
    /// inside `/Users/x`, and a plain `hasPrefix` says it is — which would hand
    /// a scan access to a folder the user never granted.
    @Test func prefixMatchingRespectsPathBoundaries() {
        let grant = FolderGrant(url: URL(fileURLWithPath: "/Users/x"),
                                bookmark: Data([1]), granted: Date())
        #expect(FolderAccess.needsGrant(
            for: URL(fileURLWithPath: "/Users/xavier/Pictures"),
            in: [grant], capabilities: .of(.appStore)),
            "/Users/xavier was treated as inside /Users/x")
    }
}

@Suite("Folder grant boundaries")
struct FolderGrantBoundaryTests {
    /// The boundary check existed in two places and only one of them got it
    /// right. `withAccess` used a bare `hasPrefix`, so a grant on `/Users/x`
    /// would have been accepted as covering `/Users/xavier` — access to a
    /// folder the user never granted. It is one function now.
    @Test func theSeparatorIsNotOptional() {
        let root = URL(fileURLWithPath: "/Users/x")
        #expect(FolderAccess.covers(root, URL(fileURLWithPath: "/Users/x")))
        #expect(FolderAccess.covers(root, URL(fileURLWithPath: "/Users/x/Pictures")))
        #expect(FolderAccess.covers(root, URL(fileURLWithPath: "/Users/x/a/b/c")))
        #expect(FolderAccess.covers(root, URL(fileURLWithPath: "/Users/xavier")) == false)
        #expect(FolderAccess.covers(root, URL(fileURLWithPath: "/Users/xavier/Pictures")) == false)
        #expect(FolderAccess.covers(root, URL(fileURLWithPath: "/Users")) == false)
        #expect(FolderAccess.covers(root, URL(fileURLWithPath: "/")) == false)
    }

    /// Paths are standardized first, so `..` cannot walk out of a granted root
    /// and still look like it is inside one.
    @Test func traversalCannotEscapeAGrant() {
        let root = URL(fileURLWithPath: "/Users/x/Pictures")
        #expect(FolderAccess.covers(root, URL(fileURLWithPath: "/Users/x/Pictures/../Documents")) == false)
        #expect(FolderAccess.covers(root, URL(fileURLWithPath: "/Users/x/Pictures/./Holidays")))
    }

    /// A trailing slash is the same folder. URLs built from an open panel carry
    /// one; URLs built from a stored path do not.
    @Test func aTrailingSlashIsTheSameFolder() {
        #expect(FolderAccess.covers(URL(fileURLWithPath: "/Users/x/Pictures", isDirectory: true),
                                    URL(fileURLWithPath: "/Users/x/Pictures")))
    }
}
