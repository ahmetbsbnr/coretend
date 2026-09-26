import Foundation
import Darwin

public enum LaunchAgentIssueReason: String, Sendable, Equatable, Hashable {
    case directoryUnreadable
    case plistUnreadable
    case malformedPlist
    case plistTooLarge
    case candidateLimitReached
}

public struct LaunchAgentCandidate: Sendable, Equatable {
    public let plistURL: URL
    public let label: String?
    public let executablePath: String?
}

public struct LaunchAgentIssue: Sendable, Equatable {
    public let plistURL: URL?
    public let reason: LaunchAgentIssueReason
}

public struct LaunchAgentInspectionReport: Sendable, Equatable {
    public let candidates: [LaunchAgentCandidate]
    public let issues: [LaunchAgentIssue]
}

/// Reads configured LaunchAgents plist metadata from one caller-selected directory.
public struct LaunchAgentInspector: Sendable {
    public static let maximumCandidates = 500
    public static let maximumPlistBytes = 1_048_576

    public init() {}

    public func inspect(in directory: URL) -> LaunchAgentInspectionReport {
        let rootDescriptor = directory.path.withCString { open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC) }
        guard rootDescriptor >= 0 else {
            return LaunchAgentInspectionReport(candidates: [], issues: [LaunchAgentIssue(plistURL: directory, reason: .directoryUnreadable)])
        }
        defer { _ = close(rootDescriptor) }

        var issues: [LaunchAgentIssue] = []
        var urls: [URL] = []
        guard let enumerator = FileManager.default.enumerator(at: directory,
                                                             includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey],
                                                             options: [],
                                                             errorHandler: { url, _ in
            let isPlist = url.pathExtension.lowercased() == "plist"
            issues.append(LaunchAgentIssue(plistURL: isPlist ? url : directory,
                                           reason: isPlist ? .plistUnreadable : .directoryUnreadable))
            return true
        }) else {
            return LaunchAgentInspectionReport(candidates: [], issues: [LaunchAgentIssue(plistURL: directory, reason: .directoryUnreadable)])
        }

        while let url = enumerator.nextObject() as? URL {
            guard url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
                enumerator.skipDescendants()
                continue
            }
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                enumerator.skipDescendants()
                continue
            }
            guard url.pathExtension.lowercased() == "plist" else { continue }
            let values: URLResourceValues
            do { values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey]) }
            catch { issues.append(LaunchAgentIssue(plistURL: url, reason: .plistUnreadable)); continue }
            guard values.isSymbolicLink != true, values.isRegularFile == true else { continue }
            urls.append(url)
            if urls.count > Self.maximumCandidates {
                issues.append(LaunchAgentIssue(plistURL: nil, reason: .candidateLimitReached))
                break
            }
        }

        urls.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        var candidates: [LaunchAgentCandidate] = []
        for url in urls.prefix(Self.maximumCandidates) {
            let data: Data
            do {
                data = try Self.readPlistData(named: url.lastPathComponent, relativeTo: rootDescriptor)
            } catch LaunchAgentReadError.tooLarge {
                issues.append(LaunchAgentIssue(plistURL: url, reason: .plistTooLarge)); continue
            } catch {
                issues.append(LaunchAgentIssue(plistURL: url, reason: .plistUnreadable)); continue
            }
            guard let value = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let dictionary = value as? [String: Any] else {
                issues.append(LaunchAgentIssue(plistURL: url, reason: .malformedPlist)); continue
            }
            let label = dictionary["Label"] as? String
            let program = dictionary["Program"] as? String
            let arguments = dictionary["ProgramArguments"] as? [String]
            let executable = program ?? arguments?.first
            if label != nil || executable != nil {
                candidates.append(LaunchAgentCandidate(plistURL: url, label: label, executablePath: executable))
            }
        }
        return LaunchAgentInspectionReport(candidates: candidates, issues: issues)
    }

    static func readPlistData(named fileName: String, relativeTo rootDescriptor: Int32) throws -> Data {
        guard !fileName.isEmpty, URL(fileURLWithPath: fileName).lastPathComponent == fileName else {
            throw LaunchAgentReadError.unreadable
        }
        let descriptor = fileName.withCString { openat(rootDescriptor, $0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC) }
        guard descriptor >= 0 else { throw LaunchAgentReadError.unreadable }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else {
            _ = close(descriptor)
            throw LaunchAgentReadError.unreadable
        }
        guard info.st_size >= 0, info.st_size <= Self.maximumPlistBytes else {
            _ = close(descriptor)
            throw LaunchAgentReadError.tooLarge
        }
        do {
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            let data = try handle.read(upToCount: Self.maximumPlistBytes + 1) ?? Data()
            try handle.close()
            guard data.count <= Self.maximumPlistBytes else { throw LaunchAgentReadError.tooLarge }
            return data
        } catch {
            throw error
        }
    }
}

private enum LaunchAgentReadError: Error {
    case unreadable
    case tooLarge
}
