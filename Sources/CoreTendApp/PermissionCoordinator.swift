// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// PermissionCoordinator — the single authoritative source of macOS permission
// state for the whole app. Settings, Deep Scan, Onboarding and Diagnostics all
// read from this one object so they can never disagree.
//
// Design rules (see the v1.2.0-beta.1 "settings + permission reliability"
// blocker):
//
//   * A persisted value is NEVER authoritative. Only `lastCheckedAt`,
//     `lastSuccessfulCheckAt`, `lastKnownState` and `lastFailureReason` are
//     persisted, purely for the diagnostics panel. Every read of the live
//     state comes from a fresh probe.
//   * Full Disk Access is inferred from MULTIPLE independent read-only
//     signals, never one hardcoded path. A missing probe target is "missing",
//     not "denied".
//   * The probe never reads a private TCC database's contents; it only tries
//     to *list* directories that macOS gates behind Full Disk Access.
//   * Refreshes are coalesced/debounced and happen automatically on launch,
//     when Settings appears, when the app becomes active, on return from
//     System Settings, and before a Deep Scan.

import Foundation
import AppKit
@preconcurrency import UserNotifications

// MARK: - Explicit state

public enum PermissionState: String, Sendable, Codable, CaseIterable {
    case checking
    case granted
    case partial
    case denied
    case notRequested
    case needsReauthorization
    case unavailable          // cannot be determined on this machine
    case error                // the probe itself failed

    /// Whether CoreTend can currently see the whole home volume.
    public var isFull: Bool { self == .granted }
    /// Whether it is safe to say "you need to grant access".
    public var needsUserAction: Bool {
        self == .denied || self == .partial || self == .needsReauthorization || self == .notRequested
    }
}

// MARK: - Injectable filesystem probing

public protocol PermissionFileProbing: Sendable {
    /// Returns the directory listing, or throws. Used only to detect EPERM
    /// vs. ENOENT vs. success — the contents are ignored.
    func listDirectory(_ path: String) throws -> [String]
    func fileExists(_ path: String) -> Bool
}

public struct RealFileProbing: PermissionFileProbing {
    public init() {}
    public func listDirectory(_ path: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: path)
    }
    public func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

// MARK: - Full Disk Access probe (pure, multi-signal)

public struct FullDiskAccessProbe: Sendable {
    public struct Result: Sendable, Equatable {
        public var state: PermissionState
        public var targetsTried: Int
        public var readable: Int
        public var permissionDenied: Int
        public var missing: Int
        public var otherErrors: Int
        public var failureReason: String?
    }

    /// TCC-gated directories. Order is not significant; results are aggregated.
    /// `/Library/Application Support/com.apple.TCC` exists on every Mac and is
    /// gated by Full Disk Access, so it is a reliable primary signal even on a
    /// brand-new account where the per-user Library subfolders don't exist yet.
    static func targets(home: String) -> [String] {
        [
            "/Library/Application Support/com.apple.TCC",
            home + "/Library/Application Support/com.apple.TCC",
            home + "/Library/Safari",
            home + "/Library/Mail",
            home + "/Library/Messages",
            home + "/Library/Suggestions",
            home + "/Library/Application Support/com.apple.sharedfilelist",
            home + "/Library/Containers/com.apple.Safari",
        ]
    }

    public init() {}

    public func probe(home: String = NSHomeDirectory(),
                      fs: PermissionFileProbing = RealFileProbing()) -> Result {
        var readable = 0, denied = 0, missing = 0, other = 0
        var reasons: [String] = []
        let targets = Self.targets(home: home)
        for t in targets {
            guard fs.fileExists(t) else { missing += 1; continue }
            do {
                _ = try fs.listDirectory(t)
                readable += 1
            } catch let e as NSError {
                // EPERM / EACCES => TCC is blocking us. Anything else is a
                // genuine probe error we should not read as "denied".
                if e.domain == NSCocoaErrorDomain,
                   let underlying = e.userInfo[NSUnderlyingErrorKey] as? NSError,
                   underlying.domain == NSPOSIXErrorDomain,
                   underlying.code == Int(EPERM) || underlying.code == Int(EACCES) {
                    denied += 1
                } else if e.domain == NSPOSIXErrorDomain,
                          e.code == Int(EPERM) || e.code == Int(EACCES) {
                    denied += 1
                } else if (e.userInfo[NSUnderlyingErrorKey] as? NSError)?.code == Int(EPERM)
                            || (e.userInfo[NSUnderlyingErrorKey] as? NSError)?.code == Int(EACCES) {
                    denied += 1
                } else {
                    other += 1
                    reasons.append("\(t.split(separator: "/").last ?? ""): \(e.code)")
                }
            }
        }

        let present = readable + denied + other
        let state: PermissionState
        var reason: String?
        if present == 0 {
            // Nothing to probe against — genuinely can't tell. Not "denied".
            state = .unavailable
            reason = "no probe targets present"
        } else if readable > 0 && denied == 0 {
            state = .granted
        } else if readable > 0 && denied > 0 {
            state = .partial
            reason = "\(denied) of \(present) protected locations unreadable"
        } else if readable == 0 && denied > 0 {
            state = .denied
        } else {
            // Only non-EPERM errors — treat as probe error, keep prior state.
            state = .error
            reason = reasons.joined(separator: ", ")
        }

        return Result(state: state, targetsTried: targets.count, readable: readable,
                      permissionDenied: denied, missing: missing, otherErrors: other,
                      failureReason: reason)
    }
}

// MARK: - Notification permission

public enum NotificationPermission: String, Sendable, Codable {
    case notRequested, allowed, denied, provisional, unavailable

    init(_ s: UNAuthorizationStatus) {
        switch s {
        case .authorized, .ephemeral: self = .allowed
        case .provisional: self = .provisional
        case .denied: self = .denied
        case .notDetermined: self = .notRequested
        @unknown default: self = .unavailable
        }
    }
}

// MARK: - Persisted diagnostics (never authoritative)

struct PermissionDiagnostics: Codable, Equatable {
    var lastCheckedAt: Date?
    var lastSuccessfulCheckAt: Date?
    var lastKnownState: String?           // PermissionState.rawValue
    var lastFailureReason: String?
    var successfulProbes: Int = 0
    var deniedProbes: Int = 0
}

// MARK: - Coordinator

@MainActor
@Observable
public final class PermissionCoordinator {
    public static let shared = PermissionCoordinator()

    // Live, always-fresh-on-read-ish state (updated by refresh()).
    public private(set) var fullDiskAccess: PermissionState = .checking
    public private(set) var notifications: NotificationPermission = .notRequested
    public private(set) var lastProbe: FullDiskAccessProbe.Result?
    public private(set) var lastCheckedAt: Date?
    public private(set) var lastSuccessfulCheckAt: Date?
    public private(set) var lastFailureReason: String?

    private let probe: FullDiskAccessProbe
    private let fs: PermissionFileProbing
    private let defaults: UserDefaults
    /// Injectable so tests don't touch `UNUserNotificationCenter.current()`,
    /// which hard-traps in a non-app process.
    private let notificationStatusProvider: @Sendable () async -> UNAuthorizationStatus
    private var refreshTask: Task<Void, Never>?
    private var lastRefreshRequest: Date = .distantPast

    private static let diagKey = "permission.diagnostics.v2"
    private static let legacyKeys = [
        "permissionChecked", "fdaVerified", "fullDiskAccessVerified",
        "folderAccessVerified", "permissionsUnverified", "hasFullDiskAccess",
    ]

    public init(probe: FullDiskAccessProbe = FullDiskAccessProbe(),
                fs: PermissionFileProbing = RealFileProbing(),
                defaults: UserDefaults = .standard,
                notificationStatusProvider: (@Sendable () async -> UNAuthorizationStatus)? = nil) {
        self.probe = probe
        self.fs = fs
        self.defaults = defaults
        self.notificationStatusProvider = notificationStatusProvider ?? {
            // Only a real app bundle may talk to UNUserNotificationCenter.
            guard let id = Bundle.main.bundleIdentifier, !id.hasPrefix("com.apple.dt.") else {
                return .notDetermined
            }
            return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
        migrateLegacyState()
        if let d = loadDiagnostics() {
            lastCheckedAt = d.lastCheckedAt
            lastSuccessfulCheckAt = d.lastSuccessfulCheckAt
            lastFailureReason = d.lastFailureReason
            // A persisted state is shown only as a hint until the first fresh
            // probe completes — it is never treated as authoritative.
        }
    }

    // MARK: refresh

    public enum Trigger: String { case launch, settingsAppear, appActive, returnFromSystemSettings, manual, beforeDeepScan, folderSelection }

    /// Coalesced/debounced refresh. Repeated triggers within 400 ms collapse.
    public func refresh(_ trigger: Trigger, debounce: Duration = .milliseconds(400)) {
        lastRefreshRequest = Date()
        let requestedAt = lastRefreshRequest
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard let self, !Task.isCancelled, self.lastRefreshRequest == requestedAt else { return }
            await self.refreshNow(trigger)
        }
    }

    /// Immediate, un-debounced probe. Always performs a fresh filesystem probe;
    /// the persisted diagnostics do not influence the result.
    @discardableResult
    public func refreshNow(_ trigger: Trigger = .manual) async -> PermissionState {
        if fullDiskAccess != .granted && fullDiskAccess != .partial { fullDiskAccess = .checking }

        // A brand-new process may probe before tccd has associated it. One
        // short retry absorbs that race without masking a real denial.
        var result = probe.probe(fs: fs)
        if result.state == .denied || result.state == .error {
            try? await Task.sleep(for: .milliseconds(150))
            let retry = probe.probe(fs: fs)
            if retry.readable > result.readable { result = retry }
        }

        lastProbe = result
        lastCheckedAt = Date()
        lastFailureReason = result.failureReason
        if result.state == .granted || result.state == .partial {
            lastSuccessfulCheckAt = lastCheckedAt
        }
        // Never let a transient .error/.unavailable overwrite a known-good
        // state on screen; keep the last real state and surface the reason.
        if result.state == .error || result.state == .unavailable,
           fullDiskAccess == .granted || fullDiskAccess == .partial {
            // keep fullDiskAccess as-is
        } else {
            fullDiskAccess = result.state
        }

        notifications = NotificationPermission(await notificationStatusProvider())

        persistDiagnostics(state: fullDiskAccess, result: result)
        return fullDiskAccess
    }

    /// Opens System Settings at the Full Disk Access pane.
    public func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Relaunch CoreTend (used when macOS requires a restart to pick up a
    /// newly-granted permission).
    public func relaunchApp() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", path]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: diagnostics text

    public func diagnosticsText(appVersion: String, buildNumber: String, channel: String,
                                bundleID: String, signingMode: String, teamID: String?) -> String {
        let f = ISO8601DateFormatter()
        let p = lastProbe
        return """
        CoreTend permission diagnostics
        version: \(appVersion) (build \(buildNumber), \(channel))
        bundle id: \(bundleID)
        signing: \(signingMode)\(teamID.map { " (team \($0))" } ?? "")
        full disk access: \(fullDiskAccess.rawValue)
        probe: readable=\(p?.readable ?? 0) denied=\(p?.permissionDenied ?? 0) missing=\(p?.missing ?? 0) other=\(p?.otherErrors ?? 0) of \(p?.targetsTried ?? 0)
        notifications: \(notifications.rawValue)
        last checked: \(lastCheckedAt.map { f.string(from: $0) } ?? "never")
        last successful: \(lastSuccessfulCheckAt.map { f.string(from: $0) } ?? "never")
        last failure: \(lastFailureReason ?? "none")
        """
    }

    // MARK: persistence (diagnostics only)

    private func loadDiagnostics() -> PermissionDiagnostics? {
        guard let data = defaults.data(forKey: Self.diagKey) else { return nil }
        return try? JSONDecoder().decode(PermissionDiagnostics.self, from: data)
    }

    private func persistDiagnostics(state: PermissionState, result: FullDiskAccessProbe.Result) {
        var d = loadDiagnostics() ?? PermissionDiagnostics()
        d.lastCheckedAt = lastCheckedAt
        d.lastSuccessfulCheckAt = lastSuccessfulCheckAt
        d.lastKnownState = state.rawValue
        d.lastFailureReason = result.failureReason
        if result.state == .granted || result.state == .partial { d.successfulProbes += 1 }
        if result.state == .denied { d.deniedProbes += 1 }
        if let data = try? JSONEncoder().encode(d) { defaults.set(data, forKey: Self.diagKey) }
    }

    private func migrateLegacyState() {
        // Old boolean "verified" keys must never override a fresh probe.
        // Remove them so nothing reads them again.
        var removedAny = false
        for k in Self.legacyKeys where defaults.object(forKey: k) != nil {
            defaults.removeObject(forKey: k)
            removedAny = true
        }
        if removedAny {
            var d = loadDiagnostics() ?? PermissionDiagnostics()
            d.lastFailureReason = "legacy permission keys retired on this launch"
            if let data = try? JSONEncoder().encode(d) { defaults.set(data, forKey: Self.diagKey) }
        }
    }
}
