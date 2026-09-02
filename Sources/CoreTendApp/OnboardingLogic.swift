import Foundation

// Pure, testable logic behind the first-run wizard. No SwiftUI, no side effects
// here — everything is a value derived from explicit inputs so each decision
// (profile → config, system-check status, launch-location) is unit-tested.

// MARK: - Security profile

enum SecurityProfile: String, CaseIterable, Identifiable, Sendable {
    case recommended
    case cautious
    case custom
    var id: String { rawValue }
}

/// The fixed safety posture shown at first run: confirmed removals use the
/// Trash, medium-risk rules are never preselected, and CoreTend never empties
/// the Trash or quarantines files automatically.
struct SecurityConfig: Equatable, Sendable {
    var useTrash: Bool
    var mediumRiskRules: Bool
    var emptyTrash: Bool
    var autoQuarantine: Bool

    /// Plan-specified safe defaults, identical across every profile: the app
    /// never ships an unsafe default regardless of which profile is picked.
    static let safeDefaults = SecurityConfig(
        useTrash: true, mediumRiskRules: false,
        emptyTrash: false, autoQuarantine: false)

    static func forProfile(_ profile: SecurityProfile) -> SecurityConfig {
        // Every profile starts from the same safe baseline. Recommended and
        // Cautious differ only in intent/messaging; Custom is the same baseline
        // the user then edits. None ever enables an aggressive default.
        safeDefaults
    }
}

// MARK: - Launch location

enum LaunchLocation: Equatable, Sendable {
    case applications   // already in /Applications or ~/Applications
    case downloads      // ~/Downloads
    case diskImage      // running from a mounted .dmg
    case temporary      // temp dir or Gatekeeper App Translocation (read-only)
    case other

    /// Offer a move-to-Applications only when not already installed there.
    var canOfferMove: Bool { self != .applications }
}

extension LaunchLocation {
    /// Classify where the app bundle is running from, using only the bundle
    /// path and the home directory. Order matters: translocation and disk
    /// images are checked before the folder locations.
    static func detect(bundlePath: String, home: String) -> LaunchLocation {
        let p = bundlePath
        if p.contains("/AppTranslocation/") { return .temporary }
        if p.hasPrefix("/Volumes/") { return .diskImage }
        if p.hasPrefix("/private/var/folders/") || p.hasPrefix("/var/folders/")
            || p.hasPrefix("/tmp/") || p.hasPrefix("/private/tmp/") { return .temporary }
        if p.hasPrefix("/Applications/") || p.hasPrefix(home + "/Applications/") { return .applications }
        if p.hasPrefix(home + "/Downloads/") { return .downloads }
        return .other
    }
}

// MARK: - System self-check

/// Non-destructive first-run diagnostic. Every item is derived from an explicit
/// boolean/number gathered elsewhere (never simulated), so status derivation is
/// fully testable without touching the real system.
enum SystemCheck {
    enum Status: Sendable, Equatable { case ok, limited, actionRequired, unavailable }

    struct Item: Sendable, Equatable {
        let id: String
        let status: Status
    }

    struct Inputs: Sendable {
        var isARM64: Bool
        var macOSMajor: Int
        var bundleValid: Bool
        var resourcesPresent: Bool
        var sqliteAvailable: Bool
        var fullDiskAccess: Bool
        var freeSpaceBytes: Int64
        var configuredLocationAccessible: Bool
        var safetyCoreReady: Bool
    }

    static let minMacOSMajor = 14
    static let lowSpaceThreshold: Int64 = 2_000_000_000 // 2 GB

    static func items(_ i: Inputs) -> [Item] {
        [
            Item(id: "arch", status: i.isARM64 ? .ok : .unavailable),
            Item(id: "macos", status: i.macOSMajor >= minMacOSMajor ? .ok : .unavailable),
            Item(id: "bundle", status: i.bundleValid ? .ok : .actionRequired),
            Item(id: "resources", status: i.resourcesPresent ? .ok : .actionRequired),
            Item(id: "sqlite", status: i.sqliteAvailable ? .ok : .unavailable),
            // Optional capabilities degrade to "limited", never block.
            Item(id: "permissions", status: i.fullDiskAccess ? .ok : .limited),
            Item(id: "freespace", status: i.freeSpaceBytes >= lowSpaceThreshold ? .ok : .limited),
            Item(id: "location", status: i.configuredLocationAccessible ? .ok : .limited),
            Item(id: "safetycore", status: i.safetyCoreReady ? .ok : .actionRequired),
        ]
    }

    /// Worst item wins: unavailable > actionRequired > limited > ok.
    static func overall(_ items: [Item]) -> Status {
        if items.contains(where: { $0.status == .unavailable }) { return .unavailable }
        if items.contains(where: { $0.status == .actionRequired }) { return .actionRequired }
        if items.contains(where: { $0.status == .limited }) { return .limited }
        return .ok
    }
}
