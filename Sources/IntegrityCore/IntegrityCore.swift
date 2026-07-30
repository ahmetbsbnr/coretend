// Replaces the ClamAV-based "Protection" module. See
// Documentation/CLAMAV_DECISION.md for why: the prior design required the
// user to install a third-party engine themselves via Terminal/Homebrew,
// which the product's own bar for this feature ("never open Terminal, never
// install Homebrew") ruled out, and which could never be bundled/signed by
// this project.
//
// Everything here reads macOS's own, already-true signals — no scanning
// engine, no signature database, no network call, no third-party binary.

import Foundation
import Security

// MARK: - Download provenance

/// Where a file came from, as macOS itself recorded it at download time.
/// `NSURLQuarantinePropertiesKey` is the same metadata Finder's Info panel
/// and Safari's download list read from; this never re-derives it by
/// guessing from file contents.
public struct DownloadProvenance: Sendable, Identifiable, Equatable {
    public let id: String
    public let path: String
    public let name: String
    public let isQuarantined: Bool
    public let sourceURL: String?
    public let originURL: String?
    public let agentName: String?
    public let downloadedAt: Date?

    public init(path: String, name: String, isQuarantined: Bool, sourceURL: String?,
                originURL: String?, agentName: String?, downloadedAt: Date?) {
        self.id = path
        self.path = path
        self.name = name
        self.isQuarantined = isQuarantined
        self.sourceURL = sourceURL
        self.originURL = originURL
        self.agentName = agentName
        self.downloadedAt = downloadedAt
    }
}

public enum ProvenanceScanner {
    /// Quarantine property dictionary keys, from LaunchServices' LSQuarantine.h.
    /// Used as raw strings so this file needs nothing beyond Foundation.
    private enum Key {
        static let dataURL = "LSQuarantineDataURL"
        static let originURL = "LSQuarantineOriginURL"
        static let agentName = "LSQuarantineAgentName"
        static let timeStamp = "LSQuarantineTimeStamp"
    }

    /// Scans one folder, non-recursively, newest first. Never throws: a file
    /// this can't read is simply omitted, the same honesty rule as the rest
    /// of the app's scanners.
    public static func scan(folder: URL, limit: Int = 200) -> [DownloadProvenance] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .quarantinePropertiesKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let files = entries.compactMap { url -> (URL, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true else { return nil }
            return (url, values.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(limit)

        return files.map { url, _ in
            let quarantine = (try? url.resourceValues(forKeys: [.quarantinePropertiesKey]))?.quarantineProperties
            let timestamp = quarantine?[Key.timeStamp] as? Date
            return DownloadProvenance(
                path: url.path,
                name: url.lastPathComponent,
                isQuarantined: quarantine != nil,
                sourceURL: quarantine?[Key.dataURL] as? String,
                originURL: quarantine?[Key.originURL] as? String,
                agentName: quarantine?[Key.agentName] as? String,
                downloadedAt: timestamp
            )
        }
    }
}

// MARK: - Code signature status

/// Deliberately three tiers, no more: each is independently verifiable from
/// `SecStaticCode`, so nothing here is a guess dressed up as a fact. A
/// finer split (Developer ID vs. Mac App Store vs. Apple-internal) would
/// need certificate-chain inspection this module doesn't attempt yet — better
/// to under-claim than to label something with a distinction it can't prove.
public enum CodeSignTier: String, Sendable, CaseIterable {
    case appleSigned
    case teamSigned
    case adHocOrUnsigned
}

public struct CodeSignInfo: Sendable, Equatable {
    public let tier: CodeSignTier
    public let teamIdentifier: String?
    public let signingIdentifier: String?
    public let signatureValid: Bool

    public init(tier: CodeSignTier, teamIdentifier: String?, signingIdentifier: String?, signatureValid: Bool) {
        self.tier = tier
        self.teamIdentifier = teamIdentifier
        self.signingIdentifier = signingIdentifier
        self.signatureValid = signatureValid
    }

    static let unsigned = CodeSignInfo(tier: .adHocOrUnsigned, teamIdentifier: nil, signingIdentifier: nil, signatureValid: false)
}

public enum CodeSignInspector {
    /// Inspects a bundle or executable via the Security framework directly —
    /// no `codesign`/`spctl` subprocess, so this can't be broken by PATH, a
    /// missing command-line-tools install, or output-format drift.
    public static func inspect(at url: URL) -> CodeSignInfo {
        var staticCodeRef: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCodeRef) == errSecSuccess,
              let staticCode = staticCodeRef else {
            return .unsigned
        }

        let signatureValid = SecStaticCodeCheckValidity(staticCode, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), nil) == errSecSuccess

        var infoRef: CFDictionary?
        _ = SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &infoRef)
        let info = (infoRef as? [String: Any]) ?? [:]
        let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String
        let identifier = info[kSecCodeInfoIdentifier as String] as? String
        let flags = (info[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value ?? 0
        // CS_ADHOC from cs_blobs.h is 0x00000002 — verified against a real
        // `codesign -s -` output (`flags=0x2(adhoc)`), not assumed: 0x00000004
        // is CS_FORCED_LV (hardened-runtime library validation), an unrelated
        // bit that happens to be adjacent. Not bridged into Swift under either
        // name, so the raw value is used directly rather than guessing at an
        // import that exposes it.
        let isAdHoc = flags & 0x0000_0002 != 0

        if isAdHoc || !signatureValid {
            return CodeSignInfo(tier: .adHocOrUnsigned, teamIdentifier: teamID, signingIdentifier: identifier, signatureValid: signatureValid)
        }

        var appleRequirement: SecRequirement?
        let isAppleSigned = SecRequirementCreateWithString("anchor apple" as CFString, [], &appleRequirement) == errSecSuccess
            && appleRequirement != nil
            && SecStaticCodeCheckValidity(staticCode, [], appleRequirement) == errSecSuccess

        return CodeSignInfo(
            tier: isAppleSigned ? .appleSigned : .teamSigned,
            teamIdentifier: teamID,
            signingIdentifier: identifier,
            signatureValid: signatureValid
        )
    }
}

// MARK: - Login items

/// A launch agent/daemon found on disk. Reads only world-readable locations
/// — no elevated access, no private API, nothing that needs its own
/// permission prompt.
public struct LoginItem: Sendable, Identifiable, Equatable {
    public enum Scope: String, Sendable { case userAgent, globalAgent, globalDaemon }

    public let id: String
    public let label: String
    public let programPath: String?
    public let scope: Scope
    public let plistPath: String

    public init(label: String, programPath: String?, scope: Scope, plistPath: String) {
        self.id = plistPath
        self.label = label
        self.programPath = programPath
        self.scope = scope
        self.plistPath = plistPath
    }
}

public enum LoginItemScanner {
    /// Real system locations, in the order they're reported.
    public static func defaultLocations() -> [(URL, LoginItem.Scope)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            (home.appendingPathComponent("Library/LaunchAgents"), .userAgent),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .globalAgent),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .globalDaemon),
        ]
    }

    /// `locations` defaults to the three real system directories; tests inject
    /// isolated temp directories here instead of writing into the real
    /// per-user LaunchAgents folder.
    public static func scan(locations: [(URL, LoginItem.Scope)] = defaultLocations()) -> [LoginItem] {
        let fm = FileManager.default
        var items: [LoginItem] = []
        for (folder, scope) in locations {
            guard let entries = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
            for plistURL in entries where plistURL.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: plistURL),
                      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
                else { continue }
                let label = plist["Label"] as? String ?? plistURL.deletingPathExtension().lastPathComponent
                let program = (plist["Program"] as? String)
                    ?? (plist["ProgramArguments"] as? [String])?.first
                items.append(LoginItem(label: label, programPath: program, scope: scope, plistPath: plistURL.path))
            }
        }
        return items.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }
}
