// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

// Applications Center 2.0's inspection domain. Everything here is read-only:
// no filesystem mutation, no launchctl, no binary rewriting, no process
// termination. See Documentation/APPLICATIONS_CENTER.md for the product-level
// explanation of every distinction drawn below (known vs. exhaustive storage,
// installation source vs. update mechanism, signed vs. safe, shared vs.
// removable).

import Foundation
import AppKit
import AppDiscovery
import IntegrityCore
import SafetyCore

// MARK: - Universal binary slice sizes (read-only Mach-O inspection)

/// One architecture slice inside a universal (fat) Mach-O executable.
struct MachOSlice: Sendable, Equatable {
    let architecture: String
    let sizeBytes: Int64
}

/// Parses a fat Mach-O header to report each architecture slice's size,
/// entirely from the file's own header structure. Never shells out to
/// `lipo`, never rewrites the file, never thins it. This is a parser over
/// untrusted bytes (an app bundle's executable is not a CoreTend-controlled
/// input), so every step fails closed: a short read, an implausible slice
/// count, or an offset/size that would run past the real file's end all
/// produce `nil` rather than a best-effort guess.
enum UniversalBinaryAnalyzer {
    /// `FAT_MAGIC` (big-endian, the form written to a fat binary on disk —
    /// `FAT_CIGAM` is only the in-memory byte-swapped view and never appears
    /// literally in a file's first four bytes read this way). A thin
    /// (single-architecture) Mach-O never starts with this value, so seeing
    /// anything else here is a legitimate, silent "not universal" — not
    /// treated as an error.
    private static let fatMagic: UInt32 = 0xCAFE_BABE
    /// One `fat_arch` entry: cputype(4) + cpusubtype(4) + offset(4) + size(4)
    /// + align(4), all big-endian.
    private static let fatArchSize = 20
    /// A real universal macOS binary has 2–3 slices; bounding well above
    /// that stops a corrupted count field from causing an unbounded loop
    /// or allocation.
    private static let maxPlausibleSliceCount: UInt32 = 64

    static func slices(at url: URL) -> [MachOSlice]? {
        try? parse(at: url)
    }

    private static func parse(at url: URL) throws -> [MachOSlice]? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()
        try handle.seek(toOffset: 0)

        guard let header = try handle.read(upToCount: 8), header.count == 8 else { return nil }
        guard beUInt32(header, at: 0) == fatMagic else { return nil }
        let nfatArch = beUInt32(header, at: 4)
        guard nfatArch > 0, nfatArch <= maxPlausibleSliceCount else { return nil }

        var slices: [MachOSlice] = []
        for _ in 0..<nfatArch {
            guard let entry = try handle.read(upToCount: fatArchSize), entry.count == fatArchSize else { return nil }
            let cpuType = beUInt32(entry, at: 0)
            let offset = UInt64(beUInt32(entry, at: 8))
            let size = UInt64(beUInt32(entry, at: 12))
            let (end, overflowed) = offset.addingReportingOverflow(size)
            guard !overflowed, end <= fileSize else { return nil }
            slices.append(MachOSlice(architecture: architectureName(cpuType: cpuType), sizeBytes: Int64(size)))
        }
        return slices
    }

    /// Big-endian 4-byte read at `offset` within `data`. Caller guarantees
    /// `data` has at least `offset + 4` bytes (every call site checks
    /// `.count` immediately beforehand).
    private static func beUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let bytes = data[data.startIndex + offset..<data.startIndex + offset + 4]
        return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    /// Matches the CPU type constants already used by
    /// `AppDiscovery.architectures(of:plist:)`, so both places agree.
    private static func architectureName(cpuType: UInt32) -> String {
        switch cpuType {
        case 0x0100_000C: return "arm64"
        case 0x0100_0007: return "x86_64"
        default: return "unknown"
        }
    }
}

// MARK: - Architecture detail (existing thin/universal detection + slice sizes)

/// Wraps `InstalledApp.architectures` (already computed by AppDiscovery) with
/// optional per-slice sizes. Slice sizes are only ever populated for a
/// genuinely universal binary — `nil` for a thin binary (nothing to
/// break down) or when the header couldn't be parsed, never a fabricated
/// even split of the app's total size.
struct ApplicationArchitectureDetail: Sendable, Equatable {
    let architectures: [String]
    let slices: [MachOSlice]?

    var isUniversal: Bool { architectures == ["universal"] }

    static func inspect(app: InstalledApp) -> ApplicationArchitectureDetail {
        guard app.architectures == ["universal"] else {
            return ApplicationArchitectureDetail(architectures: app.architectures, slices: nil)
        }
        let executableName = app.name
        // Mirrors AppDiscovery.architectures' own executable-path guess when
        // CFBundleExecutable isn't separately available here; a failed guess
        // just yields nil slices, never a crash or a wrong path assumed correct.
        let candidates = [
            app.path.appendingPathComponent("Contents/MacOS/\(executableName)"),
            app.path.appendingPathComponent("Contents/MacOS").appendingPathComponent(app.path.deletingPathExtension().lastPathComponent),
        ]
        for candidate in candidates {
            if let slices = UniversalBinaryAnalyzer.slices(at: candidate) {
                return ApplicationArchitectureDetail(architectures: app.architectures, slices: slices)
            }
        }
        return ApplicationArchitectureDetail(architectures: app.architectures, slices: nil)
    }
}

// MARK: - Associated item confidence

/// How an associated item was matched to an app — always traceable to a real
/// signal, never a bare filename guess.
enum AssociationMethod: String, Sendable {
    /// Directory/plist name is an exact match of the app's own bundle
    /// identifier (`AppDiscovery.associatedItems(for:)`).
    case exactBundleIdentifier
    /// Group Container matched only by vendor-prefix (see
    /// `AppDiscovery.vendorPrefix`) — a real signal, but not proof of
    /// ownership, since CoreTend does not read the app's actual
    /// application-groups entitlement.
    case vendorPrefixHeuristic
}

struct AssociatedItemAssociation: Sendable, Identifiable {
    var id: String { item.id }
    let item: AssociatedItem
    let confidence: AdvisorConfidence
    let method: AssociationMethod
    /// True when this item is known (or, for the heuristic method,
    /// suspected) to also belong to another installed app. Shared items are
    /// never preselected for uninstall regardless of confidence.
    let isShared: Bool
}

enum AssociatedItemConfidence {
    /// `item` must come from `AppDiscovery.associatedItems(for:)` — its exact
    /// bundle-id match is not, by itself, sharable across apps (two apps
    /// cannot have the same bundle identifier), so `isShared` is always
    /// `false` here.
    static func classifyExact(_ item: AssociatedItem) -> AssociatedItemAssociation {
        AssociatedItemAssociation(item: item, confidence: .exact, method: .exactBundleIdentifier, isShared: false)
    }

    /// `candidate` must come from `AppDiscovery.groupContainerCandidates(installedApps:)`.
    /// Never `.exact`: a vendor-prefix match is a real signal, not an
    /// entitlement-verified identity.
    static func classify(_ candidate: AppDiscovery.GroupContainerCandidate) -> AssociatedItemAssociation {
        AssociatedItemAssociation(item: candidate.item, confidence: .probable, method: .vendorPrefixHeuristic,
                                  isShared: candidate.sharingAppCount > 1)
    }
}

// MARK: - Storage breakdown

/// Per-kind storage for one app. Deliberately exposes `knownAssociatedStorageBytes`
/// rather than a "Total" — CoreTend only sums the associated-item kinds it
/// actually looked for (see `AppDiscovery.associatedItems`'s fixed candidate
/// list); there is no claim of exhaustiveness over every possible location an
/// app could have left data.
struct ApplicationStorageBreakdown: Sendable, Equatable {
    let applicationBytes: Int64
    let byKind: [(kind: AssociatedItem.Kind, bytes: Int64)]

    static func == (lhs: ApplicationStorageBreakdown, rhs: ApplicationStorageBreakdown) -> Bool {
        lhs.applicationBytes == rhs.applicationBytes
            && lhs.byKind.map(\.kind) == rhs.byKind.map(\.kind)
            && lhs.byKind.map(\.bytes) == rhs.byKind.map(\.bytes)
    }

    var knownAssociatedStorageBytes: Int64 { byKind.reduce(0) { $0 + $1.bytes } }

    static func build(applicationBytes: Int64, associations: [AssociatedItemAssociation]) -> ApplicationStorageBreakdown {
        var totals: [AssociatedItem.Kind: Int64] = [:]
        var order: [AssociatedItem.Kind] = []
        for association in associations {
            let kind = association.item.kind
            if totals[kind] == nil { order.append(kind) }
            totals[kind, default: 0] += association.item.sizeBytes
        }
        return ApplicationStorageBreakdown(applicationBytes: applicationBytes,
                                           byKind: order.map { (kind: $0, bytes: totals[$0] ?? 0) })
    }
}

// MARK: - Launch items

/// A `LoginItem` matched to an app by a genuinely reliable signal — never by
/// name resemblance alone. A launch item whose name merely looks like an
/// app's is simply not surfaced here at all, rather than surfaced with a
/// misleadingly low confidence: an unrelated helper showing up in every app's
/// "Launch Items" list would be noise, not information.
struct LaunchItemAssociation: Sendable, Identifiable {
    var id: String { item.id }
    let item: LoginItem
    let confidence: AdvisorConfidence
}

enum LaunchItemAssociator {
    /// `.exact`: the item's program path resolves inside the app's own
    /// bundle (direct, verifiable evidence the app itself installed it).
    /// `.high`: the item's Label matches the app's bundle identifier exactly,
    /// or is that bundle identifier plus a `.`-separated suffix (Apple's own
    /// convention for a helper/agent Label, e.g. `com.acme.App.Helper`).
    /// Anything weaker (a Label that merely contains the app's name) is
    /// omitted, per `AssociationMethod`'s exact-signal-only rule.
    static func associations(for app: InstalledApp, in items: [LoginItem]) -> [LaunchItemAssociation] {
        guard let bundleID = app.bundleIdentifier else { return [] }
        var results: [LaunchItemAssociation] = []
        for item in items {
            if let programPath = item.programPath,
               URL(fileURLWithPath: programPath).standardizedFileURL.path.hasPrefix(app.path.standardizedFileURL.path + "/") {
                results.append(LaunchItemAssociation(item: item, confidence: .exact))
            } else if item.label == bundleID || item.label.hasPrefix(bundleID + ".") {
                results.append(LaunchItemAssociation(item: item, confidence: .high))
            }
        }
        return results
    }
}

// MARK: - Runtime state

/// Whether an app is currently running — informational only in this pass; no
/// action (force-quit, block uninstall) is taken based on it.
enum ApplicationRuntimeState: Sendable, Equatable {
    case running
    case notRunning
    /// No bundle identifier to check against — CoreTend does not fall back to
    /// matching by process name or path, since that would be a much weaker
    /// signal presented with the same confidence as a real bundle-id match.
    case unknown
}

enum ApplicationRuntimeInspector {
    /// Pure, testable core: given the live set of running bundle
    /// identifiers, classify one app.
    static func classify(bundleIdentifier: String?, runningBundleIdentifiers: Set<String>) -> ApplicationRuntimeState {
        guard let bundleIdentifier else { return .unknown }
        return runningBundleIdentifiers.contains(bundleIdentifier) ? .running : .notRunning
    }

    /// Real snapshot via the public `NSWorkspace` API — no process listing,
    /// no `ps`/`lsof` subprocess, no elevated access.
    @MainActor
    static func liveRunningBundleIdentifiers() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }
}

// MARK: - Read-only, non-actionable explanation for an associated item

/// A structured "why is this associated, and what would happen" explanation
/// for one associated item — deliberately not an `AdvisorFinding`. It reuses
/// the exact same `RiskLevel`/`AdvisorConfidence`/`AdvisorReversibility`
/// vocabulary so the two never drift into inconsistent language, but
/// `AdvisorFinding.category` is a `TimelineScope`, and Applications Center
/// does not participate in Timeline (no scan, no snapshot, no comparison) —
/// giving an associated item a `TimelineScope` would claim a relationship
/// that does not exist. See `Documentation/APPLICATIONS_CENTER.md`.
struct AssociatedItemAdvisory: Sendable, Equatable {
    let confidence: AdvisorConfidence
    let risk: RiskLevel
    let reversibility: AdvisorReversibility
    let isShared: Bool

    /// Shared items are never treated as low-risk: removing storage another
    /// app may depend on is exactly the case this whole feature exists to
    /// prevent.
    static func advise(_ association: AssociatedItemAssociation) -> AssociatedItemAdvisory {
        AssociatedItemAdvisory(
            confidence: association.confidence,
            risk: association.isShared ? .high : (association.item.kind == .caches ? .low : .medium),
            reversibility: .trash,
            isShared: association.isShared)
    }
}

// MARK: - Composed inspection

/// One application's full read-only inspection — a composition of narrow
/// sub-models, not one giant struct, so each piece can be computed (and
/// tested) independently and a missing/failed piece never blocks the rest.
struct ApplicationInspection: Sendable {
    let app: InstalledApp
    let storage: ApplicationStorageBreakdown
    let associatedItems: [AssociatedItemAssociation]
    let installationSource: InstallationSource
    let updateMechanism: UpdateMechanism
    /// `nil` only when `CodeSignInspector` itself couldn't create a static
    /// code reference at all (e.g. the bundle vanished mid-inspection) —
    /// distinct from a real "unsigned" result, which is a value, not a nil.
    let signature: CodeSignInfo?
    let architecture: ApplicationArchitectureDetail
    let launchItems: [LaunchItemAssociation]
    let runtimeState: ApplicationRuntimeState
}

/// Orchestrates every inspector for one app. SwiftUI never talks to
/// `AppDiscovery`/`IntegrityCore`/`UniversalBinaryAnalyzer` directly — only to
/// this service, matching the layering already established by
/// `APFSIntelligenceService`. Deliberately per-app, on demand: nothing here
/// runs for CoreTend's whole app list at launch (see
/// `Documentation/APPLICATIONS_CENTER.md` "Performance").
@MainActor
enum ApplicationInspectionService {
    static func inspect(app: InstalledApp, allInstalledApps: [InstalledApp],
                        discovery: AppDiscovery, caskIndex: HomebrewCaskIndex,
                        loginItems: [LoginItem]) async -> ApplicationInspection {
        async let exactItems = Task.detached(priority: .utility) { discovery.associatedItems(for: app) }.value
        async let groupCandidates = Task.detached(priority: .utility) {
            discovery.groupContainerCandidates(for: app, allInstalledApps: allInstalledApps)
        }.value
        async let signature = Task.detached(priority: .utility) { CodeSignInspector.inspect(at: app.path) }.value
        async let architecture = Task.detached(priority: .utility) { ApplicationArchitectureDetail.inspect(app: app) }.value

        let associations = await exactItems.map(AssociatedItemConfidence.classifyExact)
            + (await groupCandidates).map(AssociatedItemConfidence.classify)

        return ApplicationInspection(
            app: app,
            storage: .build(applicationBytes: app.sizeBytes, associations: associations),
            associatedItems: associations,
            installationSource: discovery.installationSource(for: app.path, caskIndex: caskIndex),
            updateMechanism: discovery.updateMechanism(for: app.path, caskIndex: caskIndex),
            signature: await signature,
            architecture: await architecture,
            launchItems: LaunchItemAssociator.associations(for: app, in: loginItems),
            runtimeState: ApplicationRuntimeInspector.classify(
                bundleIdentifier: app.bundleIdentifier,
                runningBundleIdentifiers: ApplicationRuntimeInspector.liveRunningBundleIdentifiers()))
    }
}
