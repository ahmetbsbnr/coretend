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

    /// Whether a folder the person chose is this rule's folder: its path ends with
    /// `relativePath` below at least one other component, so `/Library/Caches` and
    /// `/Downloads` are refused. Checked without reading HOME, which runtime code
    /// must not look up implicitly (`Scripts/audit_safety.py`).
    public func isExpectedRoot(_ url: URL) -> Bool {
        let components = url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        guard !relativePath.isEmpty, components.count >= relativePath.count + 2 else { return false }
        return Array(components.suffix(relativePath.count)) == relativePath
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
        .init(id: .iosBackups, titleKey: "cleanup.iosBackups", explanationKey: "cleanup.iosBackups.help", risk: .high, relativePath: ["Library", "Application Support", "MobileSync", "Backup"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .simulatorCaches, titleKey: "cleanup.simulatorCaches", explanationKey: "cleanup.simulatorCaches.help", risk: .low, relativePath: ["Library", "Developer", "CoreSimulator", "Caches"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .xcodeArchives, titleKey: "cleanup.xcodeArchives", explanationKey: "cleanup.xcodeArchives.help", risk: .medium, relativePath: ["Library", "Developer", "Xcode", "Archives"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .npmCache, titleKey: "cleanup.npmCache", explanationKey: "cleanup.npmCache.help", risk: .low, relativePath: [".npm", "_cacache"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .pnpmStore, titleKey: "cleanup.pnpmStore", explanationKey: "cleanup.pnpmStore.help", risk: .low, relativePath: ["Library", "pnpm", "store"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .gradleCaches, titleKey: "cleanup.gradleCaches", explanationKey: "cleanup.gradleCaches.help", risk: .low, relativePath: [".gradle", "caches"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .cargoCache, titleKey: "cleanup.cargoCache", explanationKey: "cleanup.cargoCache.help", risk: .low, relativePath: [".cargo", "registry", "cache"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .mailDownloads, titleKey: "cleanup.mailDownloads", explanationKey: "cleanup.mailDownloads.help", risk: .low, relativePath: ["Library", "Containers", "com.apple.mail", "Data", "Library", "Mail Downloads"], allowedExtensions: nil, excludedRelativePaths: [])
    ]
    public static func rule(_ id: ScanRule) -> CleanupRuleDescriptor? { rules.first { $0.id == id } }

}

public extension CleanupRuleDescriptor {
    /// A rule over a whole folder (caches, build products, backups) offers each entry directly
    /// inside that folder as one item — a cache folder goes to the Trash whole, so it can be put
    /// back whole. A rule that filters files (logs, crash reports, unfinished downloads) offers
    /// each matching file.
    var groupsTopLevelEntries: Bool { allowedExtensions == nil && excludedRelativePaths.isEmpty }
}

/// One thing the Clean space offers: a top-level entry of a rule's folder, or one matching file.
public struct CleanupItem: Sendable, Identifiable, Equatable {
    public var id: URL { url }
    public let url: URL
    public let ruleID: ScanRule
    public let risk: CandidateRisk
    /// Allocated bytes of the files whose size is known.
    public var bytes: Int64
    public var files: Int
    /// Files whose local size could not be established (cloud-backed or unreadable).
    public var unknownFiles: Int
    public var modifiedAt: Date?
}

/// Every item of one rule, largest first.
public struct CleanupGroup: Sendable, Identifiable, Equatable {
    public var id: ScanRule { rule.id }
    public let rule: CleanupRuleDescriptor
    public var items: [CleanupItem]
    public var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}

public struct CleanupSurveyReport: Sendable, Equatable {
    public let groups: [CleanupGroup]
    /// Paths CoreTend could not read, with the stable reason.
    public let issues: [String: String]
    public var bytes: Int64 { groups.reduce(0) { $0 + $1.bytes } }
    public init(groups: [CleanupGroup], issues: [String: String]) { self.groups = groups; self.issues = issues }
}

/// Reads every cleanup rule's folder under a home folder in one pass, read-only, and gathers the
/// files into the items the Clean space offers. Rules whose folder does not exist are skipped.
public struct CleanupSurvey: Sendable {
    private let home: URL
    private let rules: [CleanupRuleDescriptor]
    private let engine: any ScanEngine

    public init(home: URL, rules: [CleanupRuleDescriptor] = CleanupRuleCatalog.rules, engine: any ScanEngine = LocalScanEngine()) {
        self.home = home.standardizedFileURL
        self.rules = rules
        self.engine = engine
    }

    /// The rules whose folder exists, with that folder.
    public func presentRoots() -> [(rule: CleanupRuleDescriptor, root: URL)] {
        rules.compactMap { rule in
            let root = rule.root(homeDirectory: home)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
            return (rule, root)
        }
    }

    public func run(exclusions: [URL] = [], progress: @Sendable (Int) -> Void = { _ in }) async throws -> CleanupSurveyReport {
        let present = presentRoots()
        guard !present.isEmpty else { return CleanupSurveyReport(groups: [], issues: [:]) }
        let roots = Dictionary(uniqueKeysWithValues: present.map { ($0.rule.id, $0.root) })
        var items: [URL: CleanupItem] = [:]
        var issues: [String: String] = [:]
        let request = ScanRequest(roots: present.map { ScanRoot(url: $0.root, ruleID: $0.rule.id) }, exclusions: exclusions)
        for try await event in engine.scan(request) {
            try Task.checkCancellation()
            switch event {
            case .result(let result):
                guard let rule = CleanupRuleCatalog.rule(result.ruleID), let root = roots[result.ruleID] else { continue }
                let key = rule.groupsTopLevelEntries ? Self.topLevelEntry(of: result.url, under: root) : result.url
                var item = items[key] ?? CleanupItem(url: key, ruleID: rule.id, risk: rule.risk, bytes: 0, files: 0, unknownFiles: 0, modifiedAt: nil)
                item.files += 1
                if case .known(let bytes) = result.allocatedBytes { item.bytes += bytes } else { item.unknownFiles += 1 }
                if let date = result.modifiedAt, date > (item.modifiedAt ?? .distantPast) { item.modifiedAt = date }
                items[key] = item
            case .itemFailure(let path, let reason): issues[path] = reason
            case .progress(let completed): progress(completed)
            case .finished: break
            }
        }
        let groups = present.compactMap { entry -> CleanupGroup? in
            let ruleItems = items.values.filter { $0.ruleID == entry.rule.id }.sorted { $0.bytes > $1.bytes }
            return ruleItems.isEmpty ? nil : CleanupGroup(rule: entry.rule, items: ruleItems)
        }
        return CleanupSurveyReport(groups: groups, issues: issues)
    }

    /// The entry directly inside `root` that contains `url`.
    static func topLevelEntry(of url: URL, under root: URL) -> URL {
        let rootComponents = root.standardizedFileURL.pathComponents
        let components = url.standardizedFileURL.pathComponents
        guard components.count > rootComponents.count, Array(components.prefix(rootComponents.count)) == rootComponents else { return url }
        return root.appendingPathComponent(components[rootComponents.count])
    }
}
