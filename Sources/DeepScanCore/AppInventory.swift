// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// AppInventory — a read-only census of installed applications, used by the
// ownership resolver and the orphaned-leftover detector. Nothing here writes
// or launches anything; it reads Info.plist and code-signing metadata only.

import Foundation

/// One installed application and the identity facts we can prove about it
/// without launching it.
public struct InstalledApp: Sendable, Codable, Hashable {
    public let bundleID: String
    public let bundleURL: String
    public let displayName: String
    /// Names the app is also known by (CFBundleName, executable name, the
    /// `.app` file name without extension). Used only as *weak* corroboration,
    /// never as the sole basis for attributing data.
    public let nameVariants: [String]
    public let teamID: String?
    /// Bundle IDs of helpers / XPC services / login items embedded in the app,
    /// so their containers are attributed to the parent, not called orphans.
    public let embeddedBundleIDs: [String]
    public let lastUsedDate: Date?

    public init(bundleID: String, bundleURL: String, displayName: String,
                nameVariants: [String], teamID: String?, embeddedBundleIDs: [String],
                lastUsedDate: Date?) {
        self.bundleID = bundleID
        self.bundleURL = bundleURL
        self.displayName = displayName
        self.nameVariants = nameVariants
        self.teamID = teamID
        self.embeddedBundleIDs = embeddedBundleIDs
        self.lastUsedDate = lastUsedDate
    }

    /// Every bundle ID this app legitimately answers for (itself + helpers).
    public var ownedBundleIDs: Set<String> {
        Set([bundleID] + embeddedBundleIDs)
    }
}

/// Scans the standard application locations. Pure filesystem + plist reads.
public struct AppInventoryScanner: Sendable {
    public init() {}

    public static func defaultSearchRoots(home: URL) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            home.appendingPathComponent("Applications"),
        ]
    }

    public func scan(roots: [URL]) -> [InstalledApp] {
        let fm = FileManager.default
        var out: [InstalledApp] = []
        var seenBundleIDs = Set<String>()
        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(at: root,
                    includingPropertiesForKeys: [.contentAccessDateKey], options: [.skipsHiddenFiles]) else { continue }
            for appURL in entries where appURL.pathExtension == "app" {
                guard let app = Self.readApp(at: appURL) else { continue }
                guard seenBundleIDs.insert(app.bundleID).inserted else { continue }
                out.append(app)
            }
        }
        return out
    }

    static func readApp(at appURL: URL) -> InstalledApp? {
        let infoPlist = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlist),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String else { return nil }

        let displayName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        var variants = Set<String>()
        variants.insert(appURL.deletingPathExtension().lastPathComponent)
        if let n = plist["CFBundleName"] as? String { variants.insert(n) }
        if let e = plist["CFBundleExecutable"] as? String { variants.insert(e) }

        // Embedded helper bundle IDs: shallow scan of the usual nesting spots.
        var embedded: [String] = []
        for sub in ["Contents/Library/LoginItems", "Contents/XPCServices",
                    "Contents/PlugIns", "Contents/Frameworks", "Contents/Helpers"] {
            let dir = appURL.appendingPathComponent(sub)
            guard let kids = try? FileManager.default.contentsOfDirectory(at: dir,
                    includingPropertiesForKeys: nil) else { continue }
            for k in kids {
                let kp = k.appendingPathComponent("Contents/Info.plist")
                if let d = try? Data(contentsOf: kp),
                   let p = try? PropertyListSerialization.propertyList(from: d, format: nil) as? [String: Any],
                   let bid = p["CFBundleIdentifier"] as? String {
                    embedded.append(bid)
                }
            }
        }

        let accessDate = try? appURL.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate

        return InstalledApp(bundleID: bundleID, bundleURL: appURL.standardizedFileURL.path,
                            displayName: displayName, nameVariants: Array(variants).sorted(),
                            teamID: Self.teamID(forBundle: appURL),
                            embeddedBundleIDs: Array(Set(embedded)).sorted(),
                            lastUsedDate: accessDate ?? nil)
    }

    /// Team ID from the code signature, via `codesign`. Read-only, best effort;
    /// nil when unsigned or the tool is unavailable.
    static func teamID(forBundle url: URL) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        p.arguments = ["-dv", "--verbose=4", url.path]
        let pipe = Pipe()
        p.standardError = pipe
        p.standardOutput = Pipe()
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        for line in out.split(separator: "\n") where line.hasPrefix("TeamIdentifier=") {
            let v = line.dropFirst("TeamIdentifier=".count).trimmingCharacters(in: .whitespaces)
            return v == "not set" ? nil : v
        }
        return nil
    }
}
