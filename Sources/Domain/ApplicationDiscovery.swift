import Foundation
import Darwin
import ProductContract

public struct ApplicationRecord: Sendable, Equatable, Identifiable {
    public let id: String
    public let bundleIdentifier: String
    public let displayName: String
    public let version: String?
    public let url: URL
    public let updateAvailability: ProductMeasurement<String>
}

public struct ApplicationDiscoveryIssue: Sendable, Equatable {
    public let path: String
    public let reason: String
}

public struct ApplicationDiscoveryReport: Sendable, Equatable {
    public let applications: [ApplicationRecord]
    public let issues: [ApplicationDiscoveryIssue]
}

public struct ApplicationDiscoveryService: Sendable {
    public init() {}

    public func discover(in selectedRoot: URL) -> ApplicationDiscoveryReport {
        var rootInfo = stat()
        guard lstat(selectedRoot.path, &rootInfo) == 0, (rootInfo.st_mode & S_IFMT) == S_IFDIR else {
            return ApplicationDiscoveryReport(applications: [], issues: [.init(path: selectedRoot.path, reason: "selected_root_unavailable")])
        }
        let children: [URL]
        do { children = try FileManager.default.contentsOfDirectory(at: selectedRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) }
        catch { return ApplicationDiscoveryReport(applications: [], issues: [.init(path: selectedRoot.path, reason: "selected_root_unreadable")]) }
        var applications: [ApplicationRecord] = []
        var issues: [ApplicationDiscoveryIssue] = []
        for appURL in children where appURL.pathExtension.lowercased() == "app" {
            var appInfo = stat()
            guard lstat(appURL.path, &appInfo) == 0, (appInfo.st_mode & S_IFMT) == S_IFDIR else { continue }
            let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
            var contentsInfo = stat()
            guard lstat(contentsURL.path, &contentsInfo) == 0, (contentsInfo.st_mode & S_IFMT) == S_IFDIR else {
                issues.append(.init(path: appURL.path, reason: "bundle_contents_unavailable")); continue
            }
            let infoURL = contentsURL.appendingPathComponent("Info.plist")
            do {
                let data = try Self.readRegularFileNoFollow(infoURL)
                guard let info = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                      let identifier = info["CFBundleIdentifier"] as? String, !identifier.isEmpty else {
                    issues.append(.init(path: appURL.path, reason: "bundle_identifier_missing")); continue
                }
                let displayName = (info["CFBundleDisplayName"] as? String)
                    ?? (info["CFBundleName"] as? String)
                    ?? appURL.deletingPathExtension().lastPathComponent
                let version = (info["CFBundleShortVersionString"] as? String) ?? (info["CFBundleVersion"] as? String)
                applications.append(ApplicationRecord(id: appURL.path, bundleIdentifier: identifier,
                                                       displayName: displayName, version: version, url: appURL,
                                                       updateAvailability: .unknown(reason: "update_source_not_checked")))
            } catch {
                issues.append(.init(path: appURL.path, reason: "bundle_metadata_unavailable"))
            }
        }
        return ApplicationDiscoveryReport(applications: applications.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }, issues: issues)
    }

    private static func readRegularFileNoFollow(_ url: URL) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoPermission) }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_size >= 0, info.st_size <= 2_000_000 else { throw CocoaError(.fileReadCorruptFile) }
        var bytes = [UInt8](repeating: 0, count: Int(info.st_size))
        var offset = 0
        while offset < bytes.count {
            let count = read(descriptor, &bytes[offset], bytes.count - offset)
            guard count > 0 else { throw CocoaError(.fileReadCorruptFile) }
            offset += count
        }
        return Data(bytes)
    }
}
