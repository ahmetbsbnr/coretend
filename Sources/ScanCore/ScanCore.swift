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
    public let modifiedAt: Date?
    public let risk: CandidateRisk
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url && lhs.ruleID == rhs.ruleID && lhs.modifiedAt == rhs.modifiedAt && lhs.risk == rhs.risk
    }
}

public enum ScanEvent: Sendable {
    case progress(completed: Int)
    case result(ScanResult)
    case itemFailure(path: String, reason: String)
    case finished
}

public protocol ScanEngine: Sendable { func scan(_ request: ScanRequest) -> AsyncThrowingStream<ScanEvent, Error> }

public struct LocalScanEngine: ScanEngine {
    public init() {}

    public func scan(_ request: ScanRequest) -> AsyncThrowingStream<ScanEvent, Error> {
        AsyncThrowingStream { continuation in
            let worker = Task(priority: .utility) {
                await Self.run(request, continuation: continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in worker.cancel() }
        }
    }

    private static func run(_ request: ScanRequest, continuation: AsyncThrowingStream<ScanEvent, Error>.Continuation) async {
        var completed = 0
        let exclusions = request.exclusions.map { $0.resolvingSymlinksInPath().standardizedFileURL.path }
        for root in request.roots {
            guard !Task.isCancelled else { return }
            if isExcluded(root.url, by: exclusions) {
                continuation.yield(.itemFailure(path: root.url.path, reason: "root_excluded")); continue
            }
            var rootInfo = stat()
            guard lstat(root.url.path, &rootInfo) == 0 else {
                continuation.yield(.itemFailure(path: root.url.path, reason: failureReason(errno: errno))); continue
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
                    continuation.yield(.itemFailure(path: directory.path, reason: failureReason(error))); continue
                }
                for child in children {
                    guard !Task.isCancelled else { return }
                    if isExcluded(child, by: exclusions) { continue }
                    var info = stat()
                    guard lstat(child.path, &info) == 0 else {
                        continuation.yield(.itemFailure(path: child.path, reason: failureReason(errno: errno))); continue
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
                    let values = try? child.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isUbiquitousItemKey])
                    let logical = values?.fileSize.map(Int64.init).map(ProductMeasurement.known) ?? .unknown(reason: "size_unavailable")
                    let allocated: ProductMeasurement<Int64> = values?.isUbiquitousItem == true
                        ? .unknown(reason: "cloud_backed_local_bytes_unverified")
                        : .known(Int64(info.st_blocks) * 512)
                    continuation.yield(.result(ScanResult(url: child, ruleID: root.ruleID,
                                                          logicalBytes: logical, allocatedBytes: allocated,
                                                          modifiedAt: values?.contentModificationDate,
                                                          risk: risk(for: root.ruleID))))
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
