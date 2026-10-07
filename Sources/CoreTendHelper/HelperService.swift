import Darwin
import Foundation
import HelperProtocol
import SafetyCore

/// The helper's requests. Each one checks its input against what the helper itself lists, so a
/// caller can never name an arbitrary path or label.
final class HelperService: NSObject, CoreTendHelperProtocol, @unchecked Sendable {
    private let clientUID: uid_t
    private let trasher = SystemCacheTrasher()
    private let daemonsFolder = URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true)

    init(clientUID: uid_t) { self.clientUID = clientUID }

    func version(reply: @escaping (String) -> Void) { reply(HelperIdentity.version) }

    func systemCaches(reply: @escaping (Data?, String?) -> Void) {
        let items = cacheItems().map { SystemCacheItem(path: $0.path, bytes: Self.allocatedBytes(of: $0)) }
        reply(try? JSONEncoder().encode(items), nil)
    }

    func trashSystemCache(path: String, reply: @escaping (String?, String?) -> Void) {
        let item = URL(fileURLWithPath: path).standardizedFileURL
        guard cacheItems().contains(item) else { return reply(nil, "not-a-system-cache") }
        guard let trash = personTrash() else { return reply(nil, "no-trash-folder") }
        do { reply(try trasher.trash(item, into: trash, owner: clientUID).path, nil) } catch { reply(nil, "\(error)") }
    }

    func restoreSystemCache(trashPath: String, originalPath: String, reply: @escaping (String?) -> Void) {
        let original = URL(fileURLWithPath: originalPath).standardizedFileURL
        let trashed = URL(fileURLWithPath: trashPath).standardizedFileURL
        // Back only into /Library/Caches, and only from this person's Trash.
        guard original.deletingLastPathComponent().path == trasher.cachesRoot.path,
              let trash = personTrash(), trashed.deletingLastPathComponent().path == trash.path else {
            return reply("refused")
        }
        do { try TrashRestorer().restore(trashed, to: original); reply(nil) } catch { reply("\(error)") }
    }

    func launchDaemons(reply: @escaping (Data?, String?) -> Void) {
        reply(try? JSONEncoder().encode(daemons()), nil)
    }

    func setLaunchDaemon(label: String, enabled: Bool, reply: @escaping (String?) -> Void) {
        guard daemons().contains(where: { $0.label == label }) else { return reply("unknown-label") }
        let result = Launchctl.run([enabled ? "enable" : "disable", "system/\(label)"])
        reply(result.status == 0 ? nil : "launchctl-\(result.status)")
    }

    // MARK: - What the helper lists

    private func cacheItems() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: trasher.cachesRoot.path)) ?? []
        return names.map { trasher.cachesRoot.appendingPathComponent($0).standardizedFileURL }.filter(trasher.accepts)
    }

    private func daemons() -> [LaunchDaemonItem] {
        let disabled = Launchctl.disabledSystemLabels()
        let files = (try? FileManager.default.contentsOfDirectory(at: daemonsFolder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "plist" }.compactMap { file in
            guard let plist = NSDictionary(contentsOf: file), let label = plist["Label"] as? String,
                  !label.hasPrefix("com.apple."), label != HelperIdentity.label else { return nil }
            let program = plist["Program"] as? String ?? (plist["ProgramArguments"] as? [String])?.first ?? ""
            return LaunchDaemonItem(label: label, program: program, disabled: disabled.contains(label))
        }.sorted { $0.label < $1.label }
    }

    /// The Trash folder of the person whose CoreTend asked, from the system's user database.
    private func personTrash() -> URL? {
        guard clientUID != 0, let entry = getpwuid(clientUID), let home = entry.pointee.pw_dir else { return nil }
        let trash = URL(fileURLWithPath: String(cString: home), isDirectory: true).appendingPathComponent(".Trash", isDirectory: true)
        var folder: ObjCBool = false
        return FileManager.default.fileExists(atPath: trash.path, isDirectory: &folder) && folder.boolValue ? trash : nil
    }

    private static func allocatedBytes(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        var total: Int64 = 0
        if let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? 0)
        }
        let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true })
        while let next = walker?.nextObject() as? URL {
            if let values = try? next.resourceValues(forKeys: keys), values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }
}
