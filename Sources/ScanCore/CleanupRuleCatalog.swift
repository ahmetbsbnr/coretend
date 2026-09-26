import Foundation

public struct CleanupRuleDescriptor: Sendable, Equatable {
    public let id: ScanRule
    public let titleKey: String
    public let explanationKey: String
    public let risk: CandidateRisk
    public let relativePath: [String]
    public let allowedExtensions: Set<String>?
    public let excludedRelativePaths: [[String]]

    public func root(homeDirectory: URL) -> URL {
        relativePath.reduce(homeDirectory.standardizedFileURL) { $0.appendingPathComponent($1, isDirectory: true) }
    }

    public func includes(_ url: URL, rootURL: URL? = nil) -> Bool {
        if let allowedExtensions, !allowedExtensions.contains(url.pathExtension.lowercased()) { return false }
        if let rootURL, !excludedRelativePaths.isEmpty {
            let rootPath = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
            let itemPath = url.resolvingSymlinksInPath().standardizedFileURL.path
            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            if itemPath.hasPrefix(prefix) {
                let components = itemPath.dropFirst(prefix.count).split(separator: "/").map(String.init)
                if excludedRelativePaths.contains(where: { excluded in components.starts(with: excluded) }) { return false }
            }
        }
        return true
    }
}

public enum CleanupRuleCatalog {
    public static let rules: [CleanupRuleDescriptor] = [
        .init(id: .userCaches, titleKey: "cleanup.caches", explanationKey: "cleanup.caches.help", risk: .low, relativePath: ["Library", "Caches"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .userLogs, titleKey: "cleanup.logs", explanationKey: "cleanup.logs.help", risk: .low, relativePath: ["Library", "Logs"], allowedExtensions: nil, excludedRelativePaths: [["DiagnosticReports"]]),
        .init(id: .crashReports, titleKey: "cleanup.crashes", explanationKey: "cleanup.crashes.help", risk: .low, relativePath: ["Library", "Logs", "DiagnosticReports"], allowedExtensions: ["crash", "ips"], excludedRelativePaths: []),
        .init(id: .xcodeDerivedData, titleKey: "cleanup.derived", explanationKey: "cleanup.derived.help", risk: .low, relativePath: ["Library", "Developer", "Xcode", "DerivedData"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .incompleteDownloads, titleKey: "cleanup.downloads", explanationKey: "cleanup.downloads.help", risk: .low, relativePath: ["Downloads"], allowedExtensions: ["download"], excludedRelativePaths: []),
        .init(id: .xcodeDeviceSupport, titleKey: "cleanup.deviceSupport", explanationKey: "cleanup.deviceSupport.help", risk: .medium, relativePath: ["Library", "Developer", "Xcode", "iOS DeviceSupport"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .iosBackups, titleKey: "cleanup.iosBackups", explanationKey: "cleanup.iosBackups.help", risk: .high, relativePath: ["Library", "Application Support", "MobileSync", "Backup"], allowedExtensions: nil, excludedRelativePaths: [])
    ]
    public static func rule(_ id: ScanRule) -> CleanupRuleDescriptor? { rules.first { $0.id == id } }
}
