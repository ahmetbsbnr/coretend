// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// How this copy of CoreTend was distributed, and what that lets it do.
///
/// CoreTend ships as two products from one codebase:
///
/// - **Developer ID** — signed, notarized, downloaded from the website. No
///   sandbox. Full capability: it can read `~/Library/Caches`, enumerate
///   `/Applications`, find an app's leftovers, inspect login items, and check
///   for its own updates.
/// - **App Store** — sandboxed. Apple's rules and the sandbox's container model
///   remove four of those outright, and Apple delivers updates itself.
///
/// ## Why this is a value rather than a `#if`
///
/// A compile-time flag scattered through views produces two products that
/// diverge silently: a `#if` someone forgets leaves a button on screen in the
/// sandboxed build that cannot possibly work, and nothing catches it because
/// the other build compiles fine.
///
/// Capabilities are data. The sidebar is built from them, so a module the
/// sandbox forbids is **absent** rather than present-and-failing, and
/// `DistributionTests` asserts that every module the app routes is one the
/// running build can actually deliver.
///
/// ## What the sandbox actually removes, and why
///
/// Not a judgement about Apple — these follow from the container model:
///
/// - **Storage cleanup** reads `~/Library/Caches` and other apps' support
///   directories. A sandboxed app sees only its own container.
/// - **Applications** enumerates `/Applications`, reads other bundles, and
///   moves them to the Trash. All three are outside the container.
/// - **Privacy Cleaner** reads Safari, Chrome and Firefox cache directories.
///   Same reason.
/// - **Integrity** reads `~/Library/LaunchAgents` and `/Library/LaunchDaemons`
///   to report what runs at login, and probes TCC-protected paths to detect
///   Full Disk Access — which a sandboxed app cannot hold.
///
/// What survives is the half that works on folders the user picks: Space Lens,
/// Duplicates, Large & Old Files and Similar Images, reached through
/// `NSOpenPanel` and kept across launches with security-scoped bookmarks.
enum Distribution: String, Sendable, CaseIterable {
    case developerID
    case appStore

    /// The channel this binary was built for.
    ///
    /// The one `#if` in the product. Everything downstream branches on the
    /// value, not on the compiler.
    static var current: Distribution {
        #if CORETEND_APP_STORE
        .appStore
        #else
        .developerID
        #endif
    }

    /// True when macOS confines this process to a container.
    var isSandboxed: Bool { self == .appStore }
}

/// What the running build is able to do. Every capability corresponds to
/// something the user can see, so that a missing one produces an absence rather
/// than a failure.
struct AppCapabilities: Sendable, Equatable {
    /// Read locations outside the app's own container: `~/Library/Caches`,
    /// other apps' support data, `/Applications`.
    let canReachSystemLocations: Bool
    /// Enumerate, inspect and remove installed applications.
    let canManageApplications: Bool
    /// Read browser cache directories.
    let canCleanBrowserData: Bool
    /// Read login items and probe for Full Disk Access.
    let canInspectIntegrity: Bool
    /// Check for and verify its own updates. False on the App Store, where
    /// Apple delivers them and an in-app updater is not permitted.
    let canCheckForUpdates: Bool
    /// Whether scans must be confined to folders the user explicitly granted.
    let requiresUserSelectedFolders: Bool

    static func forCurrentBuild() -> AppCapabilities { of(Distribution.current) }

    static func of(_ distribution: Distribution) -> AppCapabilities {
        switch distribution {
        case .developerID:
            AppCapabilities(
                canReachSystemLocations: true,
                canManageApplications: true,
                canCleanBrowserData: true,
                canInspectIntegrity: true,
                canCheckForUpdates: true,
                requiresUserSelectedFolders: false)
        case .appStore:
            AppCapabilities(
                canReachSystemLocations: false,
                canManageApplications: false,
                canCleanBrowserData: false,
                canInspectIntegrity: false,
                // Apple delivers App Store updates. Shipping a checker that
                // points users at a download page would be both redundant and
                // a review rejection.
                canCheckForUpdates: false,
                requiresUserSelectedFolders: true)
        }
    }

    /// Whether a module can function at all in this build.
    ///
    /// Modules with no entry here work in both, which is the default that
    /// should hold for anything new: a module is only listed when the sandbox
    /// genuinely takes something away from it.
    func supports(_ module: ModuleID) -> Bool {
        switch module {
        case .cleanup: canReachSystemLocations
        case .applications: canManageApplications
        case .protection: canInspectIntegrity
        // Cloud Cleanup reads iCloud Drive's local mirror, which lives outside
        // the container.
        case .cloudCleanup: canReachSystemLocations
        case .smartCare, .performance, .duplicates, .myClutter,
             .spaceLens, .myActivity:
            true
        }
    }
}
