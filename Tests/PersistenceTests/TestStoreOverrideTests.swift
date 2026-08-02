// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import Testing
@testable import Persistence

/// The whole point of this type is that it refuses more often than it accepts,
/// so most of these tests assert refusal. An override that accepted a plausible
/// but wrong path would relocate a real user's database.
@Suite("Test store override")
struct TestStoreOverrideTests {

    private let tmp = "/private/tmp/coretend-override-tests"

    private func accepted(_ marker: String?, _ path: String?,
                          env: [String: String] = [:]) -> URL? {
        try? TestStoreOverride.validate(marker: marker, rawPath: path, environment: env).get()
    }

    private func rejection(_ marker: String?, _ path: String?,
                           env: [String: String] = [:]) -> TestStoreOverride.Rejection? {
        switch TestStoreOverride.validate(marker: marker, rawPath: path, environment: env) {
        case .success: return nil
        case .failure(let r): return r
        }
    }

    // MARK: - The one accepting case

    @Test func markerAndTemporaryPathTogetherAreAccepted() {
        let url = accepted("1", "\(tmp)/store")
        #expect(url?.path == "\(tmp)/store")
    }

    @Test func everyDocumentedTemporaryRootIsAccepted() {
        for root in ["/tmp", "/private/tmp", "/var/folders/ab/cd",
                     "/private/var/folders/ab/cd", "/var/tmp", "/private/var/tmp"] {
            #expect(accepted("1", "\(root)/coretend-x") != nil,
                    "expected \(root) to be an accepted temporary root")
        }
    }

    @Test func tmpdirFromTheEnvironmentIsAccepted() {
        let env = ["TMPDIR": "/private/var/folders/zz/T/"]
        #expect(accepted("1", "/private/var/folders/zz/T/coretend", env: env) != nil)
    }

    // MARK: - Marker rules

    @Test func withoutTheMarkerNothingIsOverridden() {
        #expect(rejection(nil, "\(tmp)/store") == .markerAbsent)
    }

    @Test func onlyTheExactMarkerValueCounts() {
        for bogus in ["true", "yes", "on", "0", "", "1 ", "TRUE"] {
            #expect(rejection(bogus, "\(tmp)/store") == .markerNotExactlyOne(bogus),
                    "marker \"\(bogus)\" must not activate an override")
        }
    }

    @Test func markerAloneWithoutAPathIsNotAnOverride() {
        #expect(rejection("1", nil) == .pathAbsent)
    }

    // MARK: - Path rules

    @Test func emptyOrWhitespacePathIsRejected() {
        #expect(rejection("1", "") == .pathEmpty)
        #expect(rejection("1", "   ") == .pathEmpty)
        #expect(rejection("1", "\n") == .pathEmpty)
    }

    @Test func relativePathIsRejected() {
        #expect(rejection("1", "tmp/store") == .pathNotAbsolute("tmp/store"))
        #expect(rejection("1", "./store") == .pathNotAbsolute("./store"))
    }

    @Test func nonTemporaryAbsolutePathIsRejected() {
        for path in ["/Users/someone/Library/Application Support/CoreTend",
                     "/opt/coretend", "/Applications/CoreTend.app", "/data/store"] {
            #expect(rejection("1", path) == .pathNotUnderTemporaryRoot(
                URL(fileURLWithPath: path).standardizedFileURL.path),
                "expected \(path) to be refused as non-temporary")
        }
    }

    @Test func protectedRootsAreRejectedEvenWithTheMarker() {
        // Checked before the temporary-root rule, so the reason must name the
        // protected root rather than the weaker "not temporary".
        #expect(rejection("1", "/System/Library/CoreTend") == .pathProtected("/System"))
        #expect(rejection("1", "/usr/lib/coretend") == .pathProtected("/usr/lib"))
    }

    @Test func filesystemRootIsRejected() {
        #expect(rejection("1", "/") == .pathIsHomeOrAbove("/"))
    }

    @Test func homeDirectoryIsRejected() {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        #expect(rejection("1", home) == .pathIsHomeOrAbove(home))
    }

    @Test func aBareTemporaryRootIsRejected() {
        // Otherwise an override could scribble store.sqlite into /tmp itself.
        // Compared against the *standardized* spelling because macOS collapses
        // "/private/tmp" to "/tmp" (and "/private/var" to "/var"), so the
        // rejection names the collapsed form rather than what was passed in.
        for root in ["/tmp", "/private/tmp", "/var/tmp", "/private/var/tmp"] {
            let expected = URL(fileURLWithPath: root).standardizedFileURL.path
            #expect(rejection("1", root) == .pathNotUnderTemporaryRoot(expected),
                    "expected the bare root \(root) to be refused")
        }
    }

    @Test func trailingSlashesAndDotsAreNormalisedNotTrusted() {
        #expect(accepted("1", "\(tmp)/store/")?.path == "\(tmp)/store")
        #expect(accepted("1", "\(tmp)/./store")?.path == "\(tmp)/store")
    }

    @Test func traversalCannotEscapeIntoANonTemporaryPath() {
        // "/private/tmp/../Users/x" standardizes to "/private/Users/x", which is
        // not temporary — the rule must run on the standardized path.
        let r = rejection("1", "/private/tmp/../Users/someone/Library")
        #expect(r == .pathNotUnderTemporaryRoot("/private/Users/someone/Library"))
    }

    @Test func traversalCannotReachAProtectedRoot() {
        #expect(rejection("1", "/tmp/../System/Library") == .pathProtected("/System"))
    }

    // MARK: - resolve() behaviour

    @Test func resolveReportsNothingWhenTheMarkerIsSimplyAbsent() {
        // A normal user launch must not look like an error.
        let (dir, reason) = TestStoreOverride.resolve(environment: [:])
        #expect(dir == nil)
        #expect(reason == nil)
    }

    @Test func resolveReportsAPathThatWasRefused() {
        // A harness that set both variables but aimed them badly has to hear about it.
        let (dir, reason) = TestStoreOverride.resolve(environment: [
            TestStoreOverride.markerKey: "1",
            TestStoreOverride.pathKey: "/Users/someone/real",
        ])
        #expect(dir == nil)
        #expect(reason != nil)
    }

    @Test func resolveAcceptsAWellFormedPair() {
        let (dir, reason) = TestStoreOverride.resolve(environment: [
            TestStoreOverride.markerKey: "1",
            TestStoreOverride.pathKey: "\(tmp)/resolved",
        ])
        #expect(dir?.path == "\(tmp)/resolved")
        #expect(reason == nil)
    }

    @Test func markerDetectionIsIndependentOfPathValidity() {
        // Migration suppression keys on this, so it must be true even when the
        // path was refused — otherwise a mis-aimed harness would migrate real data.
        #expect(TestStoreOverride.isTestMarkerSet(environment: [
            TestStoreOverride.markerKey: "1",
            TestStoreOverride.pathKey: "/Users/someone/real",
        ]))
        #expect(!TestStoreOverride.isTestMarkerSet(environment: [:]))
        #expect(!TestStoreOverride.isTestMarkerSet(environment: [
            TestStoreOverride.markerKey: "true",
        ]))
    }

    // MARK: - Integration with the real Store

    @Test func storeOpensInsideAnOverriddenDirectoryAndNowhereElse() async throws {
        let dir = URL(fileURLWithPath: "\(tmp)/integration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let path = dir.appendingPathComponent("store.sqlite").path
        let store = try Store(path: path)
        try await store.setSetting("testMarker", value: "isolated")

        #expect(FileManager.default.fileExists(atPath: path))
        // The real user location must be untouched by this test.
        let userDir = try Store.userDirectory().path
        #expect(!path.hasPrefix(userDir))
    }

    @Test func userPathIsNeverOverridable() throws {
        // defaultPath() may be redirected; userPath() is the fixed thing the
        // distribution gate measures against, so it must ignore the override.
        let user = try Store.userPath()
        #expect(user.contains("/CoreTend/store.sqlite"))
        #expect(!user.hasPrefix("/tmp"))
        #expect(!user.hasPrefix("/private/tmp"))
    }
}
