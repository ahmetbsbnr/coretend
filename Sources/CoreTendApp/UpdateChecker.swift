import Foundation

/// Checks whether a newer CoreTend release exists. It **only checks**.
///
/// Why this deliberately does not install anything:
///
/// Installing an update means executing code fetched from the network, which
/// is only safe if the artifact's *publisher* can be cryptographically proven.
/// CoreTend has no Apple Developer ID, so its builds are neither signed nor
/// notarized, and Minisign signing is prepared but has no key yet. A SHA-256
/// checksum published beside the file it describes proves the download was not
/// corrupted — it proves nothing about who produced it, because anyone able to
/// replace the artifact can replace the checksum too.
///
/// So until a real publisher signature exists, this type does the honest
/// subset: it reports what version is available, shows the release notes, and
/// opens the official release page so the user downloads and verifies it
/// themselves. It never downloads an artifact, never writes to the app bundle,
/// and never builds a shell command.
///
/// The whole app remains fully functional offline: every failure below is a
/// state this type reports, never an error the rest of the app has to handle.
public enum UpdateCheckError: Error, Equatable, Sendable {
    case offline
    case notConfigured
    case badResponse(Int)
    case malformedManifest
    case cancelled
}

/// One release, as described by the published manifest.
public struct ReleaseArtifact: Sendable, Equatable {
    public let name: String
    public let url: URL
    public let sha256: String
    public let size: Int64
}

public struct ReleaseInfo: Sendable, Equatable {
    public let version: String
    public let channel: String
    public let prerelease: Bool
    public let releaseURL: URL?
    public let notes: String?
    public let signed: Bool
    public let notarized: Bool
    public let minimumMacOS: String?
    public let architecture: String?
    public let dmg: ReleaseArtifact?
    public let zip: ReleaseArtifact?
}

/// The result of a check, as the UI needs to render it.
public enum UpdateStatus: Sendable, Equatable {
    case upToDate(current: String)
    case updateAvailable(ReleaseInfo)
    case failed(UpdateCheckError)
}

/// Which releases a user has opted into.
public enum UpdateChannel: String, Sendable, CaseIterable {
    /// Stable releases only. A stable user is never offered a prerelease.
    case stable
    /// Stable plus release candidates and betas. Opt-in, never the default.
    case prerelease

    public var includesPrereleases: Bool { self == .prerelease }
}

/// SemVer comparison, precise enough for this project's version shapes
/// (`1.2.3`, `1.2.3-rc.1`, `1.2.3-beta.2`).
///
/// The rules that matter here and that a naive string compare gets wrong:
/// `1.10.0` is newer than `1.9.0`, and `1.0.0` is newer than `1.0.0-rc.1`
/// because a prerelease sorts *before* its own release.
public struct SemanticVersion: Comparable, Sendable, Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    /// Dot-separated prerelease identifiers; empty means a final release.
    public let prerelease: [String]

    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") { text.removeFirst() }
        // Build metadata is explicitly not part of precedence.
        if let plus = text.firstIndex(of: "+") { text = String(text[text.startIndex..<plus]) }

        let core: Substring
        let pre: [String]
        if let dash = text.firstIndex(of: "-") {
            core = text[text.startIndex..<dash]
            pre = String(text[text.index(after: dash)...]).split(separator: ".").map(String.init)
        } else {
            core = Substring(text)
            pre = []
        }

        let parts = core.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2]),
              major >= 0, minor >= 0, patch >= 0
        else { return nil }

        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = pre
    }

    public var isPrerelease: Bool { !prerelease.isEmpty }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        // Equal cores: a version WITH a prerelease is lower than one without.
        switch (lhs.prerelease.isEmpty, rhs.prerelease.isEmpty) {
        case (true, true): return false
        case (true, false): return false // 1.0.0 > 1.0.0-rc.1
        case (false, true): return true  // 1.0.0-rc.1 < 1.0.0
        case (false, false): break
        }

        for (l, r) in zip(lhs.prerelease, rhs.prerelease) where l != r {
            switch (Int(l), Int(r)) {
            case let (lNum?, rNum?): return lNum < rNum
            case (nil, _?): return false // numeric identifiers sort lower
            case (_?, nil): return true
            default: return l < r
            }
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}

/// Fetches and interprets the published release manifest.
public struct UpdateChecker: Sendable {
    /// The manifest published alongside every release. HTTPS only — an
    /// http:// URL is rejected at construction rather than downgraded.
    public let manifestURL: URL
    public let currentVersion: String
    public let channel: UpdateChannel

    /// Injected so tests exercise the decision logic without a network.
    private let fetch: @Sendable (URL) async throws -> (Data, URLResponse)

    public init?(
        manifestURL: URL,
        currentVersion: String,
        channel: UpdateChannel,
        fetch: (@Sendable (URL) async throws -> (Data, URLResponse))? = nil
    ) {
        guard manifestURL.scheme == "https" else { return nil }
        self.manifestURL = manifestURL
        self.currentVersion = currentVersion
        self.channel = channel
        self.fetch = fetch ?? { url in
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            // No cookies, no credentials, no identifying headers: this request
            // must reveal nothing beyond "someone asked for a public file".
            request.httpShouldHandleCookies = false
            let session = URLSession(configuration: .ephemeral)
            return try await session.data(for: request)
        }
    }

    /// Performs one check. Never throws: every outcome is a status the UI can
    /// render, because "the network is down" is a normal state for an app that
    /// is designed to work offline.
    public func check() async -> UpdateStatus {
        guard let current = SemanticVersion(currentVersion) else {
            return .failed(.malformedManifest)
        }
        do {
            let (data, response) = try await fetch(manifestURL)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return .failed(.badResponse(http.statusCode))
            }
            guard let info = Self.parse(data) else { return .failed(.malformedManifest) }
            guard let latest = SemanticVersion(info.version) else {
                return .failed(.malformedManifest)
            }
            // A stable user is never offered a prerelease, even a newer one.
            if latest.isPrerelease && !channel.includesPrereleases {
                return .upToDate(current: currentVersion)
            }
            // Strictly greater: equal or older never prompts, so a downgrade
            // can never be presented as an update.
            return latest > current ? .updateAvailable(info) : .upToDate(current: currentVersion)
        } catch is CancellationError {
            return .failed(.cancelled)
        } catch {
            let code = (error as NSError).code
            let offline = [NSURLErrorNotConnectedToInternet,
                           NSURLErrorNetworkConnectionLost,
                           NSURLErrorTimedOut,
                           NSURLErrorCannotFindHost,
                           NSURLErrorDataNotAllowed]
            return .failed(offline.contains(code) ? .offline : .badResponse(code))
        }
    }

    /// Pure, so the manifest contract is testable without any I/O.
    public static func parse(_ data: Data) -> ReleaseInfo? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let json = object as? [String: Any],
              let version = json["version"] as? String, !version.isEmpty
        else { return nil }

        let channel = json["channel"] as? String ?? "stable"
        let url = (json["releaseURL"] as? String).flatMap(URL.init(string:))
        return ReleaseInfo(
            version: version,
            channel: channel,
            prerelease: json["prerelease"] as? Bool ?? SemanticVersion(version)?.isPrerelease ?? false,
            // Only ever an https link, and only ever opened by explicit user
            // action — never fetched or executed by the app.
            releaseURL: url?.scheme == "https" ? url : nil,
            notes: json["releaseNotesText"] as? String,
            signed: json["signed"] as? Bool ?? false,
            notarized: json["notarized"] as? Bool ?? false,
            minimumMacOS: json["minimumMacOS"] as? String,
            architecture: json["architecture"] as? String,
            dmg: artifact(in: json, prefix: "dmg"),
            zip: artifact(in: json, prefix: "zip")
        )
    }

    private static func artifact(in json: [String: Any], prefix: String) -> ReleaseArtifact? {
        guard let name = json["\(prefix)Name"] as? String, !name.isEmpty,
              let urlText = json["\(prefix)URL"] as? String,
              let url = URL(string: urlText), url.scheme == "https",
              let sha = normalizedSHA256(json["\(prefix)SHA256"] as? String),
              let size = int64(json["\(prefix)Size"]), size > 0
        else { return nil }
        return ReleaseArtifact(name: name, url: url, sha256: sha, size: size)
    }

    private static func normalizedSHA256(_ raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              value.count == 64,
              value.allSatisfy({ ("0"..."9").contains($0) || ("a"..."f").contains($0) })
        else { return nil }
        return value
    }

    private static func int64(_ value: Any?) -> Int64? {
        switch value {
        case let number as Int:
            return Int64(number)
        case let number as Int64:
            return number
        case let number as NSNumber:
            return number.int64Value
        default:
            return nil
        }
    }
}
