import Foundation
import Darwin

/// What an app leaves in the home folder's Library, found only at the places macOS gives each app
/// and only by an exact name: the app's bundle identifier, or — for Application Support, Caches and
/// Logs, where many apps use it — the app's own name. Nothing is guessed from a partial match.
public struct AppLeftover: Sendable, Equatable, Identifiable {
    public var id: URL { url }
    public let url: URL
    public let evidence: AssociationEvidence
    public let bytes: Int64
}

public struct AppLeftoverFinder: Sendable {
    private let library: URL

    public init(home: URL) {
        library = home.appendingPathComponent("Library", isDirectory: true)
    }

    /// The Library folder, the only place leftovers are taken from.
    public var root: URL { library }

    /// Apple's own apps are part of macOS; their data is not offered.
    public static func offersLeftovers(for bundleIdentifier: String) -> Bool {
        !bundleIdentifier.isEmpty && !bundleIdentifier.hasPrefix("com.apple.")
    }

    public func find(bundleIdentifier id: String, displayName: String) -> [AppLeftover] {
        guard Self.offersLeftovers(for: id), Self.isPlainName(id) else { return [] }
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let usableName = Self.isPlainName(name) && name.count >= 4
            && !ApplicationAssociationMatcher.genericNames.contains(name.lowercased())
        var candidates: [(String, AssociationEvidence)] = [
            ("Application Support/\(id)", .identifier), ("Caches/\(id)", .identifier),
            ("Containers/\(id)", .identifier), ("Preferences/\(id).plist", .identifier),
            ("Saved Application State/\(id).savedState", .identifier), ("HTTPStorages/\(id)", .identifier),
            ("HTTPStorages/\(id).binarycookies", .identifier), ("WebKit/\(id)", .identifier),
            ("Logs/\(id)", .identifier), ("Cookies/\(id).binarycookies", .identifier),
            ("LaunchAgents/\(id).plist", .identifier), ("Application Scripts/\(id)", .identifier),
        ]
        if usableName {
            candidates += [("Application Support/\(name)", .name), ("Caches/\(name)", .name), ("Logs/\(name)", .name)]
        }
        var found: [AppLeftover] = []
        var seen = Set<String>()
        for (relative, evidence) in candidates {
            let url = library.appendingPathComponent(relative)
            var info = stat()
            guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) != S_IFLNK, seen.insert(url.path).inserted else { continue }
            found.append(AppLeftover(url: url, evidence: evidence, bytes: Self.allocatedBytes(url)))
        }
        // Per-host preferences: ByHost/<id>.<host UUID>.plist
        let byHost = library.appendingPathComponent("Preferences/ByHost")
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: byHost.path) {
            for entry in entries where entry.hasPrefix(id + ".") && entry.hasSuffix(".plist") {
                let url = byHost.appendingPathComponent(entry)
                found.append(AppLeftover(url: url, evidence: .identifier, bytes: Self.allocatedBytes(url)))
            }
        }
        return found.sorted { $0.bytes > $1.bytes }
    }

    private static func isPlainName(_ value: String) -> Bool {
        !value.isEmpty && !value.contains("/") && value != "." && value != ".." && !value.hasPrefix(".")
    }

    /// Allocated bytes of a file or folder, symbolic links not followed.
    static func allocatedBytes(_ url: URL) -> Int64 {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return 0 }
        if (info.st_mode & S_IFMT) != S_IFDIR { return Int64(info.st_blocks) * 512 }
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isSymbolicLinkKey]
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) else { return 0 }
        for case let item as URL in walker {
            guard let values = try? item.resourceValues(forKeys: Set(keys)), values.isSymbolicLink != true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
