import Foundation

/// How a rule turns the files it reads into the items the Clean space offers.
public enum CleanupGrouping: Sendable, Equatable {
    /// Each matching file is one item.
    case files
    /// Each entry `depth` levels below the rule's folder is one item, with every file inside it;
    /// a file standing higher up is an item of its own.
    case entries(depth: Int)
    /// Each folder below the rule's folder whose name is in the set is one item, with every file
    /// inside it. Files outside such a folder are not offered.
    case namedFolders(Set<String>)
    /// Each Ollama model (its manifest) is one item, carrying the layers no other model uses.
    /// Layers shared with another model stay where they are.
    case ollamaModels
}

public struct CleanupRuleDescriptor: Sendable, Equatable {
    public let id: ScanRule
    public let titleKey: String
    public let explanationKey: String
    public let risk: CandidateRisk
    public let relativePath: [String]
    public let allowedExtensions: Set<String>?
    public let excludedRelativePaths: [[String]]
    public let grouping: CleanupGrouping
    /// A symbolic link, relative to the home folder, that names the version in use (such as
    /// `~/.local/bin/claude`). The entry it points into is never offered; when it does not
    /// resolve into the rule's folder, nothing is offered, since the version in use is unknown.
    public let keepsEntryLinkedFrom: [String]?
    /// Offers only launch agents whose program is an absolute path to nothing.
    public let requiresMissingLaunchProgram: Bool

    public init(id: ScanRule, titleKey: String, explanationKey: String, risk: CandidateRisk, relativePath: [String],
                allowedExtensions: Set<String>?, excludedRelativePaths: [[String]], grouping: CleanupGrouping? = nil,
                keepsEntryLinkedFrom: [String]? = nil, requiresMissingLaunchProgram: Bool = false) {
        self.id = id
        self.titleKey = titleKey
        self.explanationKey = explanationKey
        self.risk = risk
        self.relativePath = relativePath
        self.allowedExtensions = allowedExtensions
        self.excludedRelativePaths = excludedRelativePaths
        // A rule over a whole folder (caches, build products, backups) offers each entry directly
        // inside that folder; a rule that filters files (logs, crash reports) offers each file.
        self.grouping = grouping ?? (allowedExtensions == nil && excludedRelativePaths.isEmpty ? .entries(depth: 1) : .files)
        self.keepsEntryLinkedFrom = keepsEntryLinkedFrom
        self.requiresMissingLaunchProgram = requiresMissingLaunchProgram
    }

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
        let below = rootURL.flatMap { Self.components(of: url, below: $0) }
        if let below, !excludedRelativePaths.isEmpty,
           excludedRelativePaths.contains(where: { excluded in below.starts(with: excluded) }) { return false }
        if case .namedFolders(let names) = grouping {
            let folders = (below ?? url.standardizedFileURL.pathComponents).dropLast()
            guard folders.contains(where: names.contains) else { return false }
        }
        if let keepsEntryLinkedFrom {
            // Without the rule's folder the version in use cannot be told apart: offer nothing.
            guard let rootURL, let first = below?.first,
                  let active = Self.activeEntry(linkedFrom: keepsEntryLinkedFrom, root: rootURL, relativePath: relativePath),
                  first != active else { return false }
        }
        if requiresMissingLaunchProgram, !Self.launchAgentProgramIsMissing(url) { return false }
        return true
    }

    /// The path components of `url` below `root`, or nil when it is not inside it.
    static func components(of url: URL, below root: URL) -> [String]? {
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let itemPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard itemPath.hasPrefix(prefix) else { return nil }
        return itemPath.dropFirst(prefix.count).split(separator: "/").map(String.init)
    }

    /// The name of the entry of `root` that the home-relative link `linkedFrom` resolves into.
    /// The home folder is the rule's folder minus its relative path, so HOME is never read.
    static func activeEntry(linkedFrom: [String], root: URL, relativePath: [String]) -> String? {
        var home = root.standardizedFileURL
        for _ in relativePath { home.deleteLastPathComponent() }
        let link = linkedFrom.reduce(home) { $0.appendingPathComponent($1) }
        guard (try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) != nil else { return nil }
        return components(of: link.resolvingSymlinksInPath(), below: root)?.first
    }

    /// Whether `url` is a launch agent property list naming, as its program, an absolute path
    /// where nothing stands any more. Anything unreadable or relative is not called missing.
    static func launchAgentProgramIsMissing(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return false }
        let program = (plist["Program"] as? String) ?? (plist["ProgramArguments"] as? [String])?.first
        guard let program, program.hasPrefix("/") else { return false }
        return !FileManager.default.fileExists(atPath: program)
    }
}

/// Names of the cache folders a Chromium browser profile rebuilds on its own.
private let chromiumCacheFolders: Set<String> = [
    "Cache", "Code Cache", "GPUCache", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache", "GraphiteDawnCache",
    "GrShaderCache", "ShaderCache", "CacheStorage", "component_crx_cache", "extensions_crx_cache"
]

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
        .init(id: .mailDownloads, titleKey: "cleanup.mailDownloads", explanationKey: "cleanup.mailDownloads.help", risk: .low, relativePath: ["Library", "Containers", "com.apple.mail", "Data", "Library", "Mail Downloads"], allowedExtensions: nil, excludedRelativePaths: []),
        // More Xcode files.
        .init(id: .xcodeMacDeviceSupport, titleKey: "cleanup.macDeviceSupport", explanationKey: "cleanup.deviceSupport.help", risk: .medium, relativePath: ["Library", "Developer", "Xcode", "macOS DeviceSupport"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .xcodeWatchDeviceSupport, titleKey: "cleanup.watchDeviceSupport", explanationKey: "cleanup.deviceSupport.help", risk: .medium, relativePath: ["Library", "Developer", "Xcode", "watchOS DeviceSupport"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .xcodeDeviceLogs, titleKey: "cleanup.deviceLogs", explanationKey: "cleanup.deviceLogs.help", risk: .low, relativePath: ["Library", "Developer", "Xcode", "iOS Device Logs"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .xcodeDocumentationCache, titleKey: "cleanup.documentationCache", explanationKey: "cleanup.documentationCache.help", risk: .low, relativePath: ["Library", "Developer", "Xcode", "DocumentationCache"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .xcodePreviews, titleKey: "cleanup.xcodePreviews", explanationKey: "cleanup.xcodePreviews.help", risk: .low, relativePath: ["Library", "Developer", "Xcode", "UserData", "Previews"], allowedExtensions: nil, excludedRelativePaths: []),
        // AI tools: their caches and logs, and command-line versions no longer in use.
        .init(id: .claudeCodeVersions, titleKey: "cleanup.claudeCodeVersions", explanationKey: "cleanup.claudeCodeVersions.help", risk: .low, relativePath: [".local", "share", "claude", "versions"], allowedExtensions: nil, excludedRelativePaths: [], keepsEntryLinkedFrom: [".local", "bin", "claude"]),
        .init(id: .claudeDesktopLogs, titleKey: "cleanup.claudeDesktopLogs", explanationKey: "cleanup.toolLogs.help", risk: .low, relativePath: ["Library", "Logs", "Claude"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .claudeCodeTelemetry, titleKey: "cleanup.claudeCodeTelemetry", explanationKey: "cleanup.claudeCodeTelemetry.help", risk: .low, relativePath: [".claude", "telemetry"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .codexCache, titleKey: "cleanup.codexCache", explanationKey: "cleanup.toolCache.help", risk: .low, relativePath: [".codex", "cache"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .openCodeLogs, titleKey: "cleanup.openCodeLogs", explanationKey: "cleanup.toolLogs.help", risk: .low, relativePath: [".local", "share", "opencode", "log"], allowedExtensions: nil, excludedRelativePaths: []),
        .init(id: .devtoolsMCPBrowserCaches, titleKey: "cleanup.devtoolsMCPBrowserCaches", explanationKey: "cleanup.browserProfileCaches.help", risk: .low, relativePath: [".cache", "chrome-devtools-mcp", "chrome-profile"], allowedExtensions: nil, excludedRelativePaths: [], grouping: .namedFolders(chromiumCacheFolders)),
        .init(id: .antigravityBrowserCaches, titleKey: "cleanup.antigravityBrowserCaches", explanationKey: "cleanup.browserProfileCaches.help", risk: .low, relativePath: [".gemini", "antigravity-browser-profile"], allowedExtensions: nil, excludedRelativePaths: [], grouping: .namedFolders(chromiumCacheFolders)),
        // Local AI models: large, and downloaded again only on request.
        .init(id: .ollamaModels, titleKey: "cleanup.ollamaModels", explanationKey: "cleanup.ollamaModels.help", risk: .medium, relativePath: [".ollama", "models"], allowedExtensions: nil, excludedRelativePaths: [], grouping: .ollamaModels),
        .init(id: .lmStudioModels, titleKey: "cleanup.lmStudioModels", explanationKey: "cleanup.lmStudioModels.help", risk: .medium, relativePath: [".lmstudio", "models"], allowedExtensions: nil, excludedRelativePaths: [], grouping: .entries(depth: 2)),
        // Leftovers: login agents whose program is gone, and installer disk images.
        .init(id: .brokenLaunchAgents, titleKey: "cleanup.brokenLaunchAgents", explanationKey: "cleanup.brokenLaunchAgents.help", risk: .medium, relativePath: ["Library", "LaunchAgents"], allowedExtensions: ["plist"], excludedRelativePaths: [], requiresMissingLaunchProgram: true),
        .init(id: .diskImages, titleKey: "cleanup.diskImages", explanationKey: "cleanup.diskImages.help", risk: .medium, relativePath: ["Downloads"], allowedExtensions: ["dmg"], excludedRelativePaths: [])
    ]
    public static func rule(_ id: ScanRule) -> CleanupRuleDescriptor? { rules.first { $0.id == id } }

}

public extension CleanupRuleDescriptor {
    /// Whether each entry directly inside the rule's folder is offered as one item.
    var groupsTopLevelEntries: Bool { grouping == .entries(depth: 1) }
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
    /// Files that leave with this item (an Ollama model's own layers), each inside the rule's folder.
    public var companions: [URL] = []
    /// A name better than the file's own (an Ollama model's `name:tag`).
    public var displayName: String?

    /// What the Clean space calls the item.
    public var title: String { displayName ?? url.lastPathComponent }
    /// Every file or folder to move to the Trash for this item: itself first, then its companions.
    public var targets: [URL] { [url] + companions }
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
        var ollamaFiles: [URL: ScanResult] = [:]
        let request = ScanRequest(roots: present.map { ScanRoot(url: $0.root, ruleID: $0.rule.id) }, exclusions: exclusions)
        for try await event in engine.scan(request) {
            try Task.checkCancellation()
            switch event {
            case .result(let result):
                guard let rule = CleanupRuleCatalog.rule(result.ruleID), let root = roots[result.ruleID] else { continue }
                if rule.grouping == .ollamaModels { ollamaFiles[result.url.standardizedFileURL] = result; continue }
                guard let key = Self.itemURL(of: result.url, under: root, grouping: rule.grouping) else { continue }
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
        if let ollama = present.first(where: { $0.rule.grouping == .ollamaModels }) {
            let found = OllamaModelGrouper.items(root: ollama.root, files: ollamaFiles, rule: ollama.rule)
            for item in found.items { items[item.url] = item }
            issues.merge(found.issues) { first, _ in first }
        }
        let groups = present.compactMap { entry -> CleanupGroup? in
            let ruleItems = items.values.filter { $0.ruleID == entry.rule.id }.sorted { $0.bytes > $1.bytes }
            return ruleItems.isEmpty ? nil : CleanupGroup(rule: entry.rule, items: ruleItems)
        }
        return CleanupSurveyReport(groups: groups, issues: issues)
    }

    /// The entry directly inside `root` that contains `url`.
    static func topLevelEntry(of url: URL, under root: URL) -> URL {
        entry(of: url, under: root, depth: 1)
    }

    /// The entry `depth` levels below `root` that contains `url`, or `url` itself when it stands higher.
    static func entry(of url: URL, under root: URL, depth: Int) -> URL {
        let rootComponents = root.standardizedFileURL.pathComponents
        let components = url.standardizedFileURL.pathComponents
        guard components.count > rootComponents.count, Array(components.prefix(rootComponents.count)) == rootComponents else { return url }
        let kept = min(components.count - rootComponents.count, max(depth, 1))
        return components[rootComponents.count..<(rootComponents.count + kept)].reduce(root) { $0.appendingPathComponent($1) }
    }

    /// The item a file read for a rule belongs to, or nil when the rule does not offer it.
    static func itemURL(of url: URL, under root: URL, grouping: CleanupGrouping) -> URL? {
        switch grouping {
        case .files: return url
        case .entries(let depth): return entry(of: url, under: root, depth: depth)
        case .namedFolders(let names):
            let rootComponents = root.standardizedFileURL.pathComponents
            let components = url.standardizedFileURL.pathComponents
            guard components.count > rootComponents.count, Array(components.prefix(rootComponents.count)) == rootComponents else { return nil }
            let below = components[rootComponents.count...].dropLast()
            guard let index = below.firstIndex(where: names.contains) else { return nil }
            return components[rootComponents.count...index].reduce(root) { $0.appendingPathComponent($1) }
        case .ollamaModels: return nil
        }
    }
}

/// Turns the files read under Ollama's `models` folder into one item per model. A model is its
/// manifest (`manifests/<registry>/<namespace>/<model>/<tag>`, JSON naming its layers by digest);
/// its layers are `blobs/sha256-<hex>`. Only the layers no other model names go with it, so the
/// size shown is what moving that model to the Trash actually takes out of the folder.
enum OllamaModelGrouper {
    struct Manifest: Decodable {
        struct Layer: Decodable { let digest: String }
        let config: Layer?
        let layers: [Layer]
    }

    static func items(root: URL, files: [URL: ScanResult], rule: CleanupRuleDescriptor) -> (items: [CleanupItem], issues: [String: String]) {
        let root = root.standardizedFileURL
        let manifestsRoot = root.appendingPathComponent("manifests").path + "/"
        let blobsRoot = root.appendingPathComponent("blobs")
        var issues: [String: String] = [:]
        var layersByManifest: [URL: [URL]] = [:]
        for url in files.keys where url.path.hasPrefix(manifestsRoot) {
            guard let data = try? Data(contentsOf: url), let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
                issues[url.path] = "manifest_unreadable"; continue
            }
            let digests = ([manifest.config].compactMap { $0 } + manifest.layers).map(\.digest)
            layersByManifest[url] = Set(digests).map { blobsRoot.appendingPathComponent($0.replacingOccurrences(of: ":", with: "-")).standardizedFileURL }
        }
        var users: [URL: Int] = [:]
        for layers in layersByManifest.values { for layer in layers { users[layer, default: 0] += 1 } }
        let items = layersByManifest.map { manifestURL, layers -> CleanupItem in
            let own = layers.filter { users[$0] == 1 && files[$0] != nil }.sorted { $0.path < $1.path }
            var item = CleanupItem(url: manifestURL, ruleID: rule.id, risk: rule.risk, bytes: 0, files: 0, unknownFiles: 0, modifiedAt: nil)
            for url in [manifestURL] + own {
                guard let result = files[url] else { continue }
                item.files += 1
                if case .known(let bytes) = result.allocatedBytes { item.bytes += bytes } else { item.unknownFiles += 1 }
                if let date = result.modifiedAt, date > (item.modifiedAt ?? .distantPast) { item.modifiedAt = date }
            }
            item.companions = own
            item.displayName = displayName(manifest: manifestURL, manifestsRoot: manifestsRoot)
            return item
        }
        return (items, issues)
    }

    /// `llama3:latest` for the default registry's library, `namespace/model:tag` otherwise.
    static func displayName(manifest: URL, manifestsRoot: String) -> String {
        let parts = manifest.path.dropFirst(manifestsRoot.count).split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return manifest.lastPathComponent }
        let tag = parts[parts.count - 1], model = parts[parts.count - 2]
        var path = Array(parts.dropLast(2))
        if path.first == "registry.ollama.ai" { path.removeFirst() }
        if path == ["library"] { path = [] }
        return (path + [model]).joined(separator: "/") + ":" + tag
    }
}
