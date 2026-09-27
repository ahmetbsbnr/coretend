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

public struct FoundationUbiquitousItemMetadataReader: UbiquitousItemMetadataReading {
    public init() {}

    public func isUbiquitousItem(at url: URL) -> Bool? {
        try? url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem
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
            var pending = [root.url]
            while let directory = pending.popLast() {
                guard !Task.isCancelled else { return }
                let children: [URL]
                do { children = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsPackageDescendants]) }
                catch {
                    continuation.yield(.itemFailure(path: directory.path, reason: Self.failureReason(error))); continue
                }
                for child in children {
                    guard !Task.isCancelled else { return }
                    if Self.isExcluded(child, by: exclusions) { continue }
                    var info = stat()
                    guard lstat(child.path, &info) == 0 else {
                        continuation.yield(.itemFailure(path: child.path, reason: Self.failureReason(errno: errno))); continue
                    }
                    if (info.st_mode & S_IFMT) == S_IFLNK { continue }
                    let resolved = child.resolvingSymlinksInPath().path
                    guard resolved == canonicalRoot || resolved.hasPrefix(canonicalRoot.hasSuffix("/") ? canonicalRoot : canonicalRoot + "/") else {
                        continuation.yield(.itemFailure(path: child.path, reason: "root_escape")); continue
                    }
                    if (info.st_mode & S_IFMT) == S_IFDIR { pending.append(child); continue }
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

    private static func isExcluded(_ url: URL, by exclusions: [String]) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        return exclusions.contains { path == $0 || path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }
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
        switch rule {
        case .userCaches, .userLogs, .crashReports: return .low
        case .xcodeDerivedData, .incompleteDownloads: return .medium
        case .xcodeDeviceSupport, .iosBackups: return .high
        case .explore: return .low
        case .duplicates: return .low
        }
    }
}
