import Foundation
import Darwin
import ProductContract

public enum ScanRule: String, CaseIterable, Sendable {
    case explore = "scan.explore"
    case duplicates = "scan.duplicates"
    case userCaches = "cleanup.usercaches"
    case userLogs = "cleanup.userlogs"
    case crashReports = "cleanup.crashreports"
    case xcodeDerivedData = "cleanup.xcodederiveddata"
    case incompleteDownloads = "cleanup.incompletedownloads"
    case xcodeDeviceSupport = "cleanup.xcodedevicesupport"
    case iosBackups = "cleanup.iosbackups"
    case npmCache = "cleanup.npmcache"
    case pnpmStore = "cleanup.pnpmstore"
    case gradleCaches = "cleanup.gradlecaches"
    case cargoCache = "cleanup.cargocache"
    case xcodeArchives = "cleanup.xcodearchives"
    case simulatorCaches = "cleanup.simulatorcaches"
    case mailDownloads = "cleanup.maildownloads"
}

public enum CandidateRisk: String, Sendable { case low, medium, high }

public enum ExploreFileCategory: String, CaseIterable, Hashable, Sendable {
    case all, images, videos, audio, documents, archives, other

    private static let extensionsByCategory: [ExploreFileCategory: Set<String>] = [
        .images: ["bmp", "gif", "heic", "heif", "jpeg", "jpg", "png", "svg", "tif", "tiff", "webp"],
        .videos: ["avi", "m4v", "mkv", "mov", "mp4", "webm"],
        .audio: ["aac", "aif", "aiff", "flac", "m4a", "mp3", "ogg", "wav"],
        .documents: ["csv", "doc", "docx", "key", "md", "numbers", "odt", "pages", "pdf", "ppt", "pptx", "rtf", "txt", "xls", "xlsx"],
        .archives: ["7z", "bz2", "dmg", "gz", "iso", "rar", "tar", "xz", "zip"]
    ]

    private static let categorizedExtensions = extensionsByCategory.values.reduce(into: Set<String>()) { result, extensions in
        result.formUnion(extensions)
    }

    public var fileExtensions: [String] {
        Self.extensionsByCategory[self]?.sorted() ?? []
    }

    public func matches(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        guard self != .all else { return true }
        guard !fileExtension.isEmpty else { return self == .other }
        if self == .other { return !Self.categorizedExtensions.contains(fileExtension) }
        return Self.extensionsByCategory[self]?.contains(fileExtension) == true
    }
}

public enum ExplorePreset: String, CaseIterable, Sendable {
    case all
    case largeLocal
    case olderThan365Days

    public static let largeLocalThreshold: Int64 = 1_073_741_824
    public static let ageWindow: TimeInterval = 365 * 24 * 60 * 60

    public func matches(_ result: ScanResult, evaluatedAt: Date) -> Bool {
        switch self {
        case .all: return true
        case .largeLocal:
            guard case .known(let bytes) = result.allocatedBytes else { return false }
            return bytes >= Self.largeLocalThreshold
        case .olderThan365Days:
            guard let modifiedAt = result.modifiedAt else { return false }
            return modifiedAt <= evaluatedAt.addingTimeInterval(-Self.ageWindow)
        }
    }
}

public struct ScanRoot: Sendable {
    public let url: URL
    public let ruleID: ScanRule
    public init(url: URL, ruleID: ScanRule) { self.url = url; self.ruleID = ruleID }
}

public struct ScanRequest: Sendable {
    public let roots: [ScanRoot]
    public let exclusions: [URL]
    public init(roots: [ScanRoot], exclusions: [URL] = []) { self.roots = roots; self.exclusions = exclusions }
}

public struct ScanResult: Sendable, Equatable {
    public let url: URL
    public let ruleID: ScanRule
    public let logicalBytes: ProductMeasurement<Int64>
    public let allocatedBytes: ProductMeasurement<Int64>
    public let allocationIdentity: ScanAllocationIdentity?
    public let modifiedAt: Date?
    public let risk: CandidateRisk
    public init(url: URL, ruleID: ScanRule, logicalBytes: ProductMeasurement<Int64>,
                allocatedBytes: ProductMeasurement<Int64>, modifiedAt: Date?, risk: CandidateRisk,
                allocationIdentity: ScanAllocationIdentity? = nil) {
        self.url = url
        self.ruleID = ruleID
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
        self.allocationIdentity = allocationIdentity
        self.modifiedAt = modifiedAt
        self.risk = risk
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url && lhs.ruleID == rhs.ruleID && lhs.allocationIdentity == rhs.allocationIdentity
            && lhs.modifiedAt == rhs.modifiedAt && lhs.risk == rhs.risk
    }
}

public struct ScanAllocationIdentity: Hashable, Sendable {
    public let device: UInt64
    public let inode: UInt64

    public init(device: UInt64, inode: UInt64) {
        self.device = device
        self.inode = inode
    }
}

public enum ScanEvent: Sendable {
    case progress(completed: Int)
    case result(ScanResult)
    case itemFailure(path: String, reason: String)
    case finished
}

public protocol ScanEngine: Sendable { func scan(_ request: ScanRequest) -> AsyncThrowingStream<ScanEvent, Error> }

public protocol UbiquitousItemMetadataReading: Sendable {
    func isUbiquitousItem(at url: URL) -> Bool?
}

/// Asking Foundation whether each file is ubiquitous runs the File Provider heuristics per file and
/// was most of a scan's time. A file whose content is not on disk (dataless) is cloud-backed; any
/// other file is cloud-backed when its folder is, and each folder is asked once per scan.
public struct FoundationUbiquitousItemMetadataReader: UbiquitousItemMetadataReading {
    private let folders = FolderAnswers()

    public init() {}

    public func isUbiquitousItem(at url: URL) -> Bool? {
        var info = stat()
        if lstat(url.path, &info) == 0, info.st_flags & UInt32(SF_DATALESS) != 0 { return true }
        let folder = url.deletingLastPathComponent()
        if let known = folders.answer(for: folder.path) { return known }
        let answer = try? folder.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem
        folders.record(answer, for: folder.path)
        return answer
    }

    private final class FolderAnswers: @unchecked Sendable {
        private let lock = NSLock()
        private var answers: [String: Bool?] = [:]

        func answer(for path: String) -> Bool?? {
            lock.lock(); defer { lock.unlock() }
            return answers[path]
        }

        func record(_ answer: Bool?, for path: String) {
            lock.lock(); defer { lock.unlock() }
            answers[path] = .some(answer)
        }
    }
}

public struct LocalScanEngine: ScanEngine {
    private let metadataReader: any UbiquitousItemMetadataReading
    private let workerDidFinish: @Sendable () -> Void

    public init(metadataReader: any UbiquitousItemMetadataReading = FoundationUbiquitousItemMetadataReader()) {
        self.metadataReader = metadataReader
        self.workerDidFinish = {}
    }

    init(metadataReader: any UbiquitousItemMetadataReading, workerDidFinish: @escaping @Sendable () -> Void) {
        self.metadataReader = metadataReader
        self.workerDidFinish = workerDidFinish
    }

    public func scan(_ request: ScanRequest) -> AsyncThrowingStream<ScanEvent, Error> {
        AsyncThrowingStream { continuation in
            let worker = Task(priority: .utility) {
                defer { workerDidFinish() }
                await run(request, continuation: continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in worker.cancel() }
        }
    }

    private func run(_ request: ScanRequest, continuation: AsyncThrowingStream<ScanEvent, Error>.Continuation) async {
        var completed = 0
        let exclusions = request.exclusions.map { $0.resolvingSymlinksInPath().standardizedFileURL.path }
        for root in request.roots {
            guard !Task.isCancelled else { return }
            if Self.isExcluded(root.url, by: exclusions) {
                continuation.yield(.itemFailure(path: root.url.path, reason: "root_excluded")); continue
            }
            var rootInfo = stat()
            guard lstat(root.url.path, &rootInfo) == 0 else {
                continuation.yield(.itemFailure(path: root.url.path, reason: Self.failureReason(errno: errno))); continue
            }
            let rootType = rootInfo.st_mode & S_IFMT
            guard rootType != S_IFLNK else {
                continuation.yield(.itemFailure(path: root.url.path, reason: "root_symlink")); continue
            }
            guard rootType == S_IFDIR else {
                continuation.yield(.itemFailure(path: root.url.path, reason: "root_not_directory")); continue
            }
            let canonicalRoot = root.url.resolvingSymlinksInPath().path
            let canonicalPrefix = canonicalRoot.hasSuffix("/") ? canonicalRoot : canonicalRoot + "/"
            // Each directory travels with its canonical path. Symbolic links are never followed, so a
            // child's canonical path is its directory's plus its own name: no realpath call per file.
            var pending = [(url: root.url, canonical: canonicalRoot)]
            while let (directory, canonicalDirectory) = pending.popLast() {
                guard !Task.isCancelled else { return }
                let children: [URL]
                do { children = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Self.prefetchedKeys, options: [.skipsPackageDescendants]) }
                catch {
                    continuation.yield(.itemFailure(path: directory.path, reason: Self.failureReason(error))); continue
                }
                for child in children {
                    guard !Task.isCancelled else { return }
                    var info = stat()
                    guard lstat(child.path, &info) == 0 else {
                        continuation.yield(.itemFailure(path: child.path, reason: Self.failureReason(errno: errno))); continue
                    }
                    if (info.st_mode & S_IFMT) == S_IFLNK { continue }
                    let childPath = child.path
                    let name = child.lastPathComponent
                    let resolved = canonicalDirectory.hasSuffix("/") ? canonicalDirectory + name : canonicalDirectory + "/" + name
                    guard !name.isEmpty, name != ".", name != "..", resolved == canonicalRoot || resolved.hasPrefix(canonicalPrefix) else {
                        continuation.yield(.itemFailure(path: childPath, reason: "root_escape")); continue
                    }
                    if !exclusions.isEmpty, Self.isExcluded(path: resolved, by: exclusions) { continue }
                    if (info.st_mode & S_IFMT) == S_IFDIR { pending.append((child, resolved)); continue }
                    guard (info.st_mode & S_IFMT) == S_IFREG else { continue }
                    if let descriptor = CleanupRuleCatalog.rule(root.ruleID), !descriptor.includes(child, rootURL: root.url) { continue }
                    completed += 1
                    let values = try? child.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    let logical = values?.fileSize.map(Int64.init).map(ProductMeasurement.known) ?? .unknown(reason: "size_unavailable")
                    let allocated: ProductMeasurement<Int64> = metadataReader.isUbiquitousItem(at: child) == true
                        ? .unknown(reason: "cloud_backed_local_bytes_unverified")
                        : .known(Int64(info.st_blocks) * 512)
                    continuation.yield(.result(ScanResult(url: child, ruleID: root.ruleID,
                                                          logicalBytes: logical, allocatedBytes: allocated,
                                                          modifiedAt: values?.contentModificationDate,
                                                          risk: Self.risk(for: root.ruleID),
                                                          allocationIdentity: .init(device: UInt64(info.st_dev), inode: UInt64(info.st_ino)))))
                    continuation.yield(.progress(completed: completed))
                }
            }
        }
        if !Task.isCancelled { continuation.yield(.finished) }
    }

    private static let prefetchedKeys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey,
                                                             .contentModificationDateKey]

    private static func isExcluded(_ url: URL, by exclusions: [String]) -> Bool {
        isExcluded(path: url.resolvingSymlinksInPath().standardizedFileURL.path, by: exclusions)
    }
    private static func isExcluded(path: String, by exclusions: [String]) -> Bool {
        exclusions.contains { path == $0 || path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }
    }
    private static func failureReason(errno value: Int32) -> String {
        switch value {
        case EACCES, EPERM: "permission_denied"
        case ENOENT, ENOTDIR: "missing"
        default: "metadata_unavailable"
        }
    }
    private static func failureReason(_ error: Error) -> String {
        let value = error as NSError
        if value.domain == NSPOSIXErrorDomain {
            return failureReason(errno: Int32(value.code))
        }
        if value.domain == NSCocoaErrorDomain && value.code == CocoaError.fileReadNoPermission.rawValue {
            return "permission_denied"
        }
        return "directory_read_failed"
    }
    private static func risk(for rule: ScanRule) -> CandidateRisk {
        CleanupRuleCatalog.rule(rule)?.risk ?? .low
    }
}

public extension AsyncThrowingStream where Element == ScanEvent, Failure == Error {
    /// The same events, gathered into batches handed over at most once per `interval` (and once at
    /// the end). A window then updates a few times a second instead of once per file read, which
    /// is what kept the main thread busy during a scan.
    func batched(every interval: Duration = .milliseconds(100)) -> AsyncThrowingStream<[ScanEvent], Error> {
        AsyncThrowingStream<[ScanEvent], Error> { continuation in
            let pump = Task {
                let clock = ContinuousClock()
                var buffer: [ScanEvent] = []
                var lastHandOver = clock.now
                do {
                    for try await event in self {
                        buffer.append(event)
                        let now = clock.now
                        if now - lastHandOver >= interval {
                            continuation.yield(buffer)
                            buffer = []
                            lastHandOver = now
                        }
                    }
                    if !buffer.isEmpty { continuation.yield(buffer) }
                    continuation.finish()
                } catch {
                    if !buffer.isEmpty { continuation.yield(buffer) }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in pump.cancel() }
        }
    }
}
