// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// What macOS lets this copy of CoreTend actually reach, capability by
/// capability, and what stops working when it does not.
///
/// This replaces a single `hasFullDiskAccess() -> Bool`. That boolean was
/// wrong in three ways that matter for an app whose entire job is reading the
/// user's disk:
///
/// 1. **It collapsed "denied" and "cannot tell" into `false`.** On a Mac with
///    no Mail and no Safari data the probe found nothing to read and reported
///    "not granted" — telling a user to go fix a permission that was never the
///    problem. Undetermined is now its own state and is never rendered as a
///    denial.
/// 2. **macOS stopped having one permission.** Desktop, Documents, Downloads
///    and removable volumes are each their own TCC grant. Full Disk Access
///    implies them, but its absence does not deny them: a user can decline FDA
///    and still have granted Desktop. Probing only FDA reported such a Mac as
///    locked out of folders it could read perfectly well.
/// 3. **It said nothing about consequences.** "Not granted" does not tell
///    anyone what they lose. Each capability now carries the features it
///    gates, so the UI can say which scans will come back incomplete instead
///    of showing a yellow triangle.
///
/// Every probe is a real filesystem access. Nothing here is simulated, and
/// nothing asks macOS for a permission — TCC prompts are raised by the actual
/// work, not by a settings screen looking at itself.
public enum SystemAuthorization {

    // MARK: - Model

    /// One thing macOS can allow or refuse, that CoreTend depends on.
    public enum Capability: String, CaseIterable, Sendable {
        /// The blanket grant. Implies every folder below it.
        case fullDisk
        case desktop
        case documents
        case downloads
        /// External disks. Distinct from the folders: a Mac with none attached
        /// reports `.notApplicable`, not a denial.
        case removableVolumes

        /// Localization key for the capability's display name.
        public var titleKey: String { "authorization.\(rawValue).title" }

        /// Localization key for the one-sentence consequence of not having it.
        public var impactKey: String { "authorization.\(rawValue).impact" }

        /// Whether macOS exposes a Settings pane that grants this directly.
        /// Only Full Disk Access does; the per-folder grants are raised by use
        /// and revoked in Privacy & Security, so sending a user to a pane that
        /// cannot grant them would be a dead end.
        public var hasDirectSettingsPane: Bool { self == .fullDisk }
    }

    /// The outcome of probing one capability. Deliberately four cases: the two
    /// that are not a yes/no are exactly the ones the old boolean destroyed.
    public enum Grant: String, Sendable, Equatable {
        /// Read succeeded. Proven, not assumed.
        case granted
        /// Read failed with a permission error. Proven denial.
        case denied
        /// Nothing to probe — the location does not exist on this Mac. Not a
        /// denial, and must never be presented as one.
        case undetermined
        /// The capability is meaningless here (no removable volume attached).
        case notApplicable

        /// True only for a proven denial. `undetermined` is not a problem to
        /// report to the user, and this is the property the UI must branch on.
        public var needsAttention: Bool { self == .denied }
    }

    public struct Status: Sendable, Equatable, Identifiable {
        public let capability: Capability
        public let grant: Grant
        public var id: String { capability.rawValue }

        public init(capability: Capability, grant: Grant) {
            self.capability = capability
            self.grant = grant
        }
    }

    /// The whole picture, as one value the UI renders and tests assert on.
    public struct Report: Sendable, Equatable {
        public let statuses: [Status]

        public init(statuses: [Status]) { self.statuses = statuses }

        public func grant(for capability: Capability) -> Grant {
            statuses.first { $0.capability == capability }?.grant ?? .undetermined
        }

        /// Capabilities macOS is actively refusing. Empty is the good case.
        public var denied: [Capability] {
            statuses.filter { $0.grant.needsAttention }.map(\.capability)
        }

        /// True when scans can read everything they are asked to read.
        public var isComplete: Bool { denied.isEmpty }

        /// True when the blanket grant is in place, which is what
        /// `SystemCheck.Inputs.fullDiskAccess` means.
        public var hasFullDiskAccess: Bool { grant(for: .fullDisk) == .granted }

        /// Denials worth surfacing, worst first: the blanket grant before the
        /// individual folders, because fixing it fixes them all.
        public var actionable: [Status] {
            statuses
                .filter { $0.grant.needsAttention }
                .sorted { lhs, _ in lhs.capability == .fullDisk }
        }
    }

    // MARK: - Probing

    /// The filesystem operations a probe needs, injected so the decision logic
    /// is testable without depending on the running machine's real TCC state —
    /// which no test can control and which differs per developer.
    public struct Environment: Sendable {
        /// Whether a path exists at all.
        public var exists: @Sendable (String) -> Bool
        /// Attempt to list a directory. Returns the POSIX errno on failure, or
        /// nil on success. `EPERM`/`EACCES` is a denial; anything else is not.
        public var listErrno: @Sendable (String) -> Int32?
        /// Mount points under /Volumes, excluding the boot volume.
        public var removableVolumePaths: @Sendable () -> [String]
        public var home: URL

        public init(
            exists: @escaping @Sendable (String) -> Bool,
            listErrno: @escaping @Sendable (String) -> Int32?,
            removableVolumePaths: @escaping @Sendable () -> [String],
            home: URL
        ) {
            self.exists = exists
            self.listErrno = listErrno
            self.removableVolumePaths = removableVolumePaths
            self.home = home
        }
    }

    /// Paths whose readability proves Full Disk Access. Both are TCC-protected
    /// and neither is readable without the blanket grant.
    ///
    /// Two of them rather than one because a Mac that has never run Mail has
    /// no `~/Library/Mail`, and probing a path that does not exist proves
    /// nothing. If neither exists the answer is `.undetermined` — the state
    /// that did not exist before and that caused the false "not granted".
    static let fullDiskProbePaths = ["Library/Safari", "Library/Mail"]

    static func relativePath(for capability: Capability) -> String? {
        switch capability {
        case .fullDisk: nil
        case .desktop: "Desktop"
        case .documents: "Documents"
        case .downloads: "Downloads"
        case .removableVolumes: nil
        }
    }

    /// Classify one directory read. Split out so the errno-to-grant mapping is
    /// asserted directly: treating a missing directory as a denial is exactly
    /// the bug this type exists to prevent.
    static func classify(errno code: Int32?) -> Grant {
        switch code {
        case nil: .granted
        case EPERM?, EACCES?: .denied
        // ENOENT and friends: the directory went away between the existence
        // check and the read. Not a permission answer.
        default: .undetermined
        }
    }

    public static func probe(_ environment: Environment) -> Report {
        var statuses: [Status] = []

        // Full Disk Access
        var fullDisk = Grant.undetermined
        for relative in fullDiskProbePaths {
            let path = environment.home.appendingPathComponent(relative).path
            guard environment.exists(path) else { continue }
            let grant = classify(errno: environment.listErrno(path))
            // One readable protected path is proof. Keep looking only while
            // the answer is still not a grant.
            if grant == .granted { fullDisk = .granted; break }
            if grant == .denied { fullDisk = .denied }
        }
        statuses.append(Status(capability: .fullDisk, grant: fullDisk))

        // Per-folder grants
        for capability in [Capability.desktop, .documents, .downloads] {
            guard let relative = relativePath(for: capability) else { continue }
            let path = environment.home.appendingPathComponent(relative).path
            guard environment.exists(path) else {
                statuses.append(Status(capability: capability, grant: .undetermined))
                continue
            }
            statuses.append(Status(
                capability: capability,
                grant: classify(errno: environment.listErrno(path))))
        }

        // Removable volumes: no external disk is not a denial.
        let volumes = environment.removableVolumePaths()
        if volumes.isEmpty {
            statuses.append(Status(capability: .removableVolumes, grant: .notApplicable))
        } else {
            // Any readable volume is enough; the grant is per-app, not
            // per-disk, so one refusal with another readable means the refusal
            // is about that disk, not about CoreTend.
            let grants = volumes.map { classify(errno: environment.listErrno($0)) }
            statuses.append(Status(
                capability: .removableVolumes,
                grant: grants.contains(.granted) ? .granted
                     : grants.contains(.denied) ? .denied
                     : .undetermined))
        }

        return Report(statuses: statuses)
    }

    /// The real environment. Kept tiny and free of decisions: everything that
    /// can be got wrong lives in `probe`, which is tested.
    public static func liveEnvironment() -> Environment {
        Environment(
            exists: { FileManager.default.fileExists(atPath: $0) },
            listErrno: { path in
                errno = 0
                guard let handle = opendir(path) else { return errno }
                closedir(handle)
                return nil
            },
            removableVolumePaths: {
                let keys: [URLResourceKey] = [.volumeIsRemovableKey, .volumeIsInternalKey]
                let mounted = FileManager.default.mountedVolumeURLs(
                    includingResourceValuesForKeys: keys,
                    options: [.skipHiddenVolumes]) ?? []
                return mounted.compactMap { url in
                    let values = try? url.resourceValues(forKeys: Set(keys))
                    let internalVolume = values?.volumeIsInternal ?? true
                    return internalVolume ? nil : url.path
                }
            },
            home: FileManager.default.homeDirectoryForCurrentUser
        )
    }

    public static func probeLive() -> Report { probe(liveEnvironment()) }

    /// Opens the one Settings pane that can actually grant something. The
    /// per-folder grants have no pane that adds an app, so this is
    /// deliberately not offered for them.
    public static var fullDiskAccessSettingsURL: URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }
}
