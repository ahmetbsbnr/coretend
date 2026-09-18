// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import CryptoKit
import Testing
@testable import CoreTendApp

@Suite("Download verification")
struct DownloadVerificationTests {
    /// Writes `bytes` to a temporary file and returns it, cleaned up by the caller.
    private func temporaryFile(_ bytes: Data, name: String = "CoreTend-test.dmg") throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appendingPathComponent(name)
        try bytes.write(to: file)
        return file
    }

    private func artifact(name: String, sha: String, size: Int64) -> ReleaseArtifact {
        ReleaseArtifact(name: name, url: URL(string: "https://example.invalid/\(name)")!,
                        sha256: sha, size: size)
    }

    /// Known-answer test: SHA-256 of the empty input. If the streaming loop is
    /// wrong — a missed final block, a chunk read as a whole file — this is the
    /// cheapest way to find out.
    @Test func hashesTheEmptyFileToTheKnownDigest() throws {
        let file = try temporaryFile(Data())
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(try DownloadVerification.sha256(of: file)
                == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test func hashesAKnownStringToTheKnownDigest() throws {
        let file = try temporaryFile(Data("abc".utf8))
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(try DownloadVerification.sha256(of: file)
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    /// The chunk loop must produce the same digest as a single-shot hash for a
    /// file several chunks long. An off-by-one here corrupts every large
    /// download's verdict while passing on every small test file.
    @Test func streamingMatchesForAFileLargerThanOneChunk() throws {
        var bytes = Data(count: 0)
        for i in 0..<(DownloadVerification.chunkSize * 2 + 12345) {
            bytes.append(UInt8(i % 251))
        }
        let file = try temporaryFile(bytes)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let streamed = try DownloadVerification.sha256(of: file)
        let oneShot = try Data(contentsOf: file).sha256HexForTesting()
        #expect(streamed == oneShot)
    }

    @Test func matchingFileVerifies() throws {
        let payload = Data("coretend".utf8)
        let file = try temporaryFile(payload)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let digest = try DownloadVerification.sha256(of: file)
        let outcome = DownloadVerification.verify(
            fileAt: file,
            against: artifact(name: "CoreTend-test.dmg", sha: digest, size: Int64(payload.count)))
        #expect(outcome == .verified(artifact: "CoreTend-test.dmg"))
        #expect(outcome.isVerified)
    }

    /// A truncated download is the common real failure, and it has its own
    /// verdict because "checksum mismatch" makes a user think they were
    /// attacked when they were merely disconnected.
    @Test func wrongSizeIsReportedAsSuchAndDoesNotClaimTampering() throws {
        let file = try temporaryFile(Data("short".utf8))
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let outcome = DownloadVerification.verify(
            fileAt: file,
            against: artifact(name: "CoreTend-test.dmg", sha: String(repeating: "a", count: 64), size: 999_999))
        #expect(outcome == .wrongSize(expected: 999_999, actual: 5))
        #expect(outcome.isVerified == false)
    }

    /// Right size, wrong bytes. This is the case that must never be softened.
    @Test func sameSizeDifferentContentIsAMismatch() throws {
        let file = try temporaryFile(Data("aaaa".utf8))
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let outcome = DownloadVerification.verify(
            fileAt: file,
            against: artifact(name: "CoreTend-test.dmg", sha: String(repeating: "b", count: 64), size: 4))
        guard case .mismatch = outcome else {
            Issue.record("expected a mismatch, got \(outcome)")
            return
        }
        #expect(outcome.isVerified == false)
    }

    @Test func aMissingFileIsUnreadableRatherThanAMismatch() {
        let outcome = DownloadVerification.verify(
            fileAt: URL(fileURLWithPath: "/nonexistent/CoreTend.dmg"),
            against: artifact(name: "CoreTend.dmg", sha: String(repeating: "c", count: 64), size: 1))
        #expect(outcome == .unreadable("CoreTend.dmg"))
    }

    // MARK: - Choosing what to compare against

    private func release(dmg: ReleaseArtifact?, zip: ReleaseArtifact?) -> ReleaseInfo {
        ReleaseInfo(version: "1.0.2", channel: "stable", prerelease: false,
                    releaseURL: nil, notes: nil, signed: true, notarized: true,
                    minimumMacOS: nil, architecture: nil, dmg: dmg, zip: zip)
    }

    /// Picking the ZIP while the DMG is also published must compare against the
    /// ZIP. Comparing against the wrong artifact reports a mismatch the user
    /// cannot explain and cannot fix.
    @Test func theArtifactIsChosenByNameThenExtension() {
        let dmg = artifact(name: "CoreTend-1.0.2-arm64.dmg", sha: String(repeating: "a", count: 64), size: 10)
        let zip = artifact(name: "CoreTend-1.0.2-arm64.zip", sha: String(repeating: "b", count: 64), size: 20)
        let info = release(dmg: dmg, zip: zip)

        #expect(DownloadVerification.artifact(
            for: URL(fileURLWithPath: "/d/CoreTend-1.0.2-arm64.zip"), in: info) == zip)
        // Renamed by the browser ("CoreTend-1.0.2-arm64 (1).dmg"): fall back to
        // the extension rather than giving up.
        #expect(DownloadVerification.artifact(
            for: URL(fileURLWithPath: "/d/CoreTend-1.0.2-arm64 (1).dmg"), in: info) == dmg)
    }

    @Test func anUnrelatedFileMatchesNothingRatherThanTheFirstArtifact() {
        let dmg = artifact(name: "CoreTend-1.0.2-arm64.dmg", sha: String(repeating: "a", count: 64), size: 10)
        let zip = artifact(name: "CoreTend-1.0.2-arm64.zip", sha: String(repeating: "b", count: 64), size: 20)
        #expect(DownloadVerification.artifact(
            for: URL(fileURLWithPath: "/d/holiday.jpg"), in: release(dmg: dmg, zip: zip)) == nil)
    }

    /// With a single artifact published, any picked file is compared against
    /// it: there is nothing else it could have been.
    @Test func aSingleArtifactIsUsedEvenWhenTheNameDiffers() {
        let dmg = artifact(name: "CoreTend-1.0.2-arm64.dmg", sha: String(repeating: "a", count: 64), size: 10)
        #expect(DownloadVerification.artifact(
            for: URL(fileURLWithPath: "/d/renamed"), in: release(dmg: dmg, zip: nil)) == dmg)
    }

    @Test func noPublishedArtifactMeansNothingToVerifyAgainst() {
        #expect(DownloadVerification.artifact(
            for: URL(fileURLWithPath: "/d/CoreTend.dmg"), in: release(dmg: nil, zip: nil)) == nil)
    }
}

@Suite("Automatic update checking")
struct AutomaticUpdateCheckTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Off by default and never checked unasked: the app advertises working
    /// fully offline, so reaching a server without being told to is not a
    /// default it gets to take.
    @Test func neverDueWhenTheUserHasNotOptedIn() {
        #expect(UpdatesViewModel.isDue(automatic: false, lastCheck: nil, now: now) == false)
        #expect(UpdatesViewModel.isDue(
            automatic: false,
            lastCheck: now.addingTimeInterval(-10 * 24 * 3600),
            now: now) == false)
    }

    @Test func dueOnTheFirstLaunchAfterOptingIn() {
        #expect(UpdatesViewModel.isDue(automatic: true, lastCheck: nil, now: now))
    }

    @Test func throttledWithinTheInterval() {
        let recent = now.addingTimeInterval(-UpdatesViewModel.automaticInterval + 60)
        #expect(UpdatesViewModel.isDue(automatic: true, lastCheck: recent, now: now) == false)
    }

    @Test func dueOnceTheIntervalHasElapsed() {
        let old = now.addingTimeInterval(-UpdatesViewModel.automaticInterval)
        #expect(UpdatesViewModel.isDue(automatic: true, lastCheck: old, now: now))
    }

    /// A clock that moved backwards — a timezone edit, an NTP correction, a
    /// restored backup — must not suppress checks until real time catches up,
    /// which could be days or years.
    @Test func aLastCheckInTheFutureDoesNotSuppressChecksForever() {
        let future = now.addingTimeInterval(365 * 24 * 3600)
        #expect(UpdatesViewModel.isDue(automatic: true, lastCheck: future, now: now))
    }
}

private extension Data {
    func sha256HexForTesting() -> String {
        var hasher = SHA256()
        hasher.update(data: self)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
