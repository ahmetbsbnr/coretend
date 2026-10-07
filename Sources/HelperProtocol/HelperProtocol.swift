import Foundation

/// The optional system helper (decision 0006): a launchd daemon the person installs from Settings,
/// reached over XPC. It answers only the requests below, only from CoreTend signed by its team.
/// Every move goes to the asking person's Trash; nothing is ever erased.
@objc public protocol CoreTendHelperProtocol {
    /// The helper's version, to tell an old helper from the app's own.
    func version(reply: @escaping (String) -> Void)

    /// Direct children of /Library/Caches (Apple's own `com.apple.*` are left out), as JSON
    /// `[{"path": String, "bytes": Int}]`.
    func systemCaches(reply: @escaping (Data?, String?) -> Void)

    /// Moves one item listed by `systemCaches` to the Trash of the person who asked; replies with
    /// where it now is.
    func trashSystemCache(path: String, reply: @escaping (String?, String?) -> Void)

    /// Puts an item moved by `trashSystemCache` back where it was, if that place is still free.
    func restoreSystemCache(trashPath: String, originalPath: String, reply: @escaping (String?) -> Void)

    /// Third-party daemons of /Library/LaunchDaemons, as JSON
    /// `[{"label": String, "program": String, "disabled": Bool}]`.
    func launchDaemons(reply: @escaping (Data?, String?) -> Void)

    /// `launchctl disable|enable system/<label>`, for a label listed by `launchDaemons`. Takes effect
    /// at the next start; the daemon's file is never moved.
    func setLaunchDaemon(label: String, enabled: Bool, reply: @escaping (String?) -> Void)
}

public enum HelperIdentity {
    public static let label = "com.ahmetbsbnr.coretend.helper"
    public static let machService = "com.ahmetbsbnr.coretend.helper"
    public static let plistName = "com.ahmetbsbnr.coretend.helper.plist"
    public static let version = "1"
    public static let teamIdentifier = "NSCUV5G738"
    /// Who may talk to the helper: CoreTend, signed by its team with a Developer ID.
    public static let clientRequirement =
        #"identifier "com.ahmetbsbnr.coretend" and anchor apple generic and certificate leaf[subject.OU] = "NSCUV5G738""#

    /// What CoreTend expects at the other end: the helper, signed by the same team.
    public static let helperRequirement =
        #"identifier "com.ahmetbsbnr.coretend.helper" and anchor apple generic and certificate leaf[subject.OU] = "NSCUV5G738""#

    public static func interface() -> NSXPCInterface {
        NSXPCInterface(with: CoreTendHelperProtocol.self)
    }
}

/// One item of `systemCaches`.
public struct SystemCacheItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String { path }
    public let path: String
    public let bytes: Int64
    public init(path: String, bytes: Int64) { self.path = path; self.bytes = bytes }
}

/// One item of `launchDaemons`.
public struct LaunchDaemonItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String { label }
    public let label: String
    public let program: String
    public let disabled: Bool
    public init(label: String, program: String, disabled: Bool) { self.label = label; self.program = program; self.disabled = disabled }
}

/// Reading `launchctl print-disabled system`.
public enum LaunchctlOutput {
    /// Lines look like `"com.example.daemon" => disabled` (or `=> true` on older systems).
    public static func disabledLabels(_ output: String) -> Set<String> {
        var labels = Set<String>()
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\"", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            let state = parts[2].trimmingCharacters(in: .whitespaces)
            if state.hasSuffix("disabled") || state.hasSuffix("true") { labels.insert(String(parts[1])) }
        }
        return labels
    }
}
