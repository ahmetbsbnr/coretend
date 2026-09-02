import Testing
import Foundation
@testable import CoreTendApp

@Suite("Semantic version precedence")
struct SemanticVersionTests {
    @Test func parsesAndRejects() {
        #expect(SemanticVersion("1.2.3") != nil)
        #expect(SemanticVersion("v1.2.3") != nil)
        #expect(SemanticVersion("0.9.1-rc.1") != nil)
        #expect(SemanticVersion("1.2") == nil)
        #expect(SemanticVersion("banana") == nil)
        #expect(SemanticVersion("1.2.-3") == nil)
    }

    /// The comparison a naive string compare gets wrong.
    @Test func numericSegmentsCompareNumerically() {
        #expect(SemanticVersion("1.9.0")! < SemanticVersion("1.10.0")!)
        #expect(SemanticVersion("1.0.9")! < SemanticVersion("1.0.10")!)
    }

    /// A prerelease sorts before its own final release.
    @Test func prereleaseIsLowerThanRelease() {
        #expect(SemanticVersion("1.0.0-rc.1")! < SemanticVersion("1.0.0")!)
        #expect(SemanticVersion("0.9.1-rc.1")! < SemanticVersion("0.9.1")!)
        #expect(SemanticVersion("1.0.0-rc.1")! < SemanticVersion("1.0.0-rc.2")!)
        #expect(SemanticVersion("1.0.0-beta.2")! < SemanticVersion("1.0.0-rc.1")!)
    }

    @Test func buildMetadataIsIgnored() {
        #expect(SemanticVersion("1.0.0+abc")! == SemanticVersion("1.0.0")!)
    }
}

@Suite("Update checker decisions")
struct UpdateCheckerTests {
    private func manifest(_ version: String, prerelease: Bool = false, channel: String = "stable") -> Data {
        let json: [String: Any] = [
            "version": version, "channel": channel, "prerelease": prerelease,
            "releaseURL": "https://github.com/ahmetbsbnr/coretend/releases/tag/v\(version)",
            "signed": false, "notarized": false,
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func checker(current: String, channel: UpdateChannel, body: @escaping @Sendable () throws -> Data)
        -> UpdateChecker
    {
        UpdateChecker(
            manifestURL: URL(string: "https://coretend.ahmetbsbnr.com/latest.json")!,
            currentVersion: current, channel: channel,
            fetch: { url in
                (try body(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            })!
    }

    /// Refusing http:// at construction means there is no code path that can
    /// fetch the manifest over a downgradable connection.
    @Test func rejectsNonHTTPSManifest() {
        let insecure = UpdateChecker(
            manifestURL: URL(string: "http://example.com/latest.json")!,
            currentVersion: "1.0.0", channel: .stable)
        #expect(insecure == nil)
    }

    @Test func offersNewerStable() async {
        let c = checker(current: "0.9.0", channel: .stable) { self.manifest("1.0.0") }
        guard case .updateAvailable(let info) = await c.check() else {
            Issue.record("expected an update"); return
        }
        #expect(info.version == "1.0.0")
        #expect(info.signed == false)
    }

    @Test func equalVersionIsUpToDate() async {
        let c = checker(current: "1.0.0", channel: .stable) { self.manifest("1.0.0") }
        #expect(await c.check() == .upToDate(current: "1.0.0"))
    }

    /// A downgrade must never be presented as an update.
    @Test func olderRemoteVersionNeverPrompts() async {
        let c = checker(current: "2.0.0", channel: .stable) { self.manifest("1.0.0") }
        #expect(await c.check() == .upToDate(current: "2.0.0"))
    }

    /// The channel separation that matters: a stable user is not offered an RC.
    @Test func stableChannelIgnoresPrereleases() async {
        let c = checker(current: "0.9.0", channel: .stable) {
            self.manifest("1.0.0-rc.1", prerelease: true, channel: "release-candidate")
        }
        #expect(await c.check() == .upToDate(current: "0.9.0"))
    }

    @Test func prereleaseChannelAcceptsPrereleases() async {
        let c = checker(current: "0.9.0", channel: .prerelease) {
            self.manifest("1.0.0-rc.1", prerelease: true, channel: "release-candidate")
        }
        guard case .updateAvailable(let info) = await c.check() else {
            Issue.record("expected an update"); return
        }
        #expect(info.version == "1.0.0-rc.1")
    }

    /// Offline is a normal state, reported rather than thrown.
    @Test func offlineIsReportedNotThrown() async {
        let c = UpdateChecker(
            manifestURL: URL(string: "https://coretend.ahmetbsbnr.com/latest.json")!,
            currentVersion: "1.0.0", channel: .stable,
            fetch: { _ in
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
            })!
        #expect(await c.check() == .failed(.offline))
    }

    /// A request that reaches its 15s timeout is treated exactly like offline —
    /// a normal, rendered state, never a thrown error the UI has to catch.
    @Test func requestTimeoutIsReportedAsOffline() async {
        let c = UpdateChecker(
            manifestURL: URL(string: "https://coretend.ahmetbsbnr.com/latest.json")!,
            currentVersion: "1.0.0", channel: .stable,
            fetch: { _ in
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
            })!
        #expect(await c.check() == .failed(.offline))
    }

    /// The default fetch carries a bounded timeout, so a hung endpoint cannot
    /// leave the check pending forever.
    @Test func defaultFetchHasABoundedTimeout() {
        #expect(UpdateChecker.defaultRequestTimeout == 15)
        #expect(UpdateChecker.defaultRequestTimeout > 0)
    }

    @Test func garbageManifestIsRejected() async {
        let c = checker(current: "1.0.0", channel: .stable) { Data("not json".utf8) }
        #expect(await c.check() == .failed(.malformedManifest))
    }

    /// A non-https releaseURL is dropped, so the UI can never offer to open it.
    @Test func nonHTTPSReleaseURLIsDropped() {
        let data = try! JSONSerialization.data(withJSONObject: [
            "version": "1.0.0", "releaseURL": "http://evil.example/x",
        ])
        #expect(UpdateChecker.parse(data)?.releaseURL == nil)
    }

    @Test func parsesVerifiedArtifactMetadata() {
        let data = try! JSONSerialization.data(withJSONObject: [
            "version": "1.0.0",
            "releaseURL": "https://github.com/ahmetbsbnr/coretend/releases/tag/v1.0.0",
            "minimumMacOS": "14.0",
            "architecture": "arm64",
            "dmgName": "CoreTend-1.0.0-arm64.dmg",
            "dmgURL": "https://github.com/ahmetbsbnr/coretend/releases/download/v1.0.0/CoreTend-1.0.0-arm64.dmg",
            "dmgSHA256": String(repeating: "A", count: 64),
            "dmgSize": 42,
        ])
        let info = UpdateChecker.parse(data)
        #expect(info?.minimumMacOS == "14.0")
        #expect(info?.architecture == "arm64")
        #expect(info?.dmg?.name == "CoreTend-1.0.0-arm64.dmg")
        #expect(info?.dmg?.sha256 == String(repeating: "a", count: 64))
        #expect(info?.dmg?.size == 42)
    }

    @Test func dropsUnverifiedArtifactMetadata() {
        let data = try! JSONSerialization.data(withJSONObject: [
            "version": "1.0.0",
            "dmgName": "CoreTend-1.0.0-arm64.dmg",
            "dmgURL": "http://example.com/CoreTend.dmg",
            "dmgSHA256": "not-a-sha",
            "dmgSize": 42,
            "zipName": "CoreTend-1.0.0-arm64.zip",
            "zipURL": "https://github.com/ahmetbsbnr/coretend/releases/download/v1.0.0/CoreTend.zip",
            "zipSHA256": String(repeating: "b", count: 64),
            "zipSize": 0,
        ])
        let info = UpdateChecker.parse(data)
        #expect(info?.dmg == nil)
        #expect(info?.zip == nil)
    }

    @Test func httpErrorIsSurfaced() async {
        let c = UpdateChecker(
            manifestURL: URL(string: "https://coretend.ahmetbsbnr.com/latest.json")!,
            currentVersion: "1.0.0", channel: .stable,
            fetch: { url in
                (Data(), HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!)
            })!
        #expect(await c.check() == .failed(.badResponse(503)))
    }
}
