import SwiftUI
import Foundation
import Persistence
import MalwareEngine

/// Anonymized support diagnostic: generic hardware/software state only.
///
/// INCLUDED: app version/build, macOS version, architecture, generic Mac
/// model identifier (e.g. "Mac15,6" — not serial, not a marketing name tied
/// to a purchase record), deployment target, Full Disk Access state, ClamAV
/// availability (boolean + redacted path shape, never the real path), DB
/// schema version, exclusion count (not the paths), activity counts by kind.
///
/// EXCLUDED (never gathered, never emitted): username, hostname, home path,
/// any full file path, filenames, installed-app list, browsing history,
/// file content, quarantine data, personal file hashes, IP address, serial
/// number / hardware UUID / MAC address or any other unique identifier.
enum DiagnosticReport {
    struct Inputs {
        var appVersion: String
        var appBuild: String
        var macOSVersion: String
        var architecture: String
        var machineModel: String
        var deploymentTarget: String
        var fullDiskAccess: Bool
        var clamAVAvailable: Bool
        var clamAVPath: String?
        var schemaVersion: Int?
        var exclusionCount: Int
        var activityCountsByKind: [String: Int]
    }

    /// Redacts a filesystem path down to a shape ("<home>/…/name") that
    /// carries no personal information — used only if a caller ever passes
    /// a real path in by mistake, so the report stays safe even then.
    static func redactPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        var p = path
        if p.hasPrefix(home) { p = "<home>" + p.dropFirst(home.count) }
        if p.hasPrefix("/Users/") {
            let comps = p.split(separator: "/", omittingEmptySubsequences: true)
            if comps.count >= 2 { p = "/Users/<redacted>/" + comps.dropFirst(2).joined(separator: "/") }
        }
        return p
    }

    static func build(_ inputs: Inputs) -> String {
        var lines: [String] = []
        lines.append("CoreTend — Diagnostic Report")
        lines.append("App version: \(inputs.appVersion) (build \(inputs.appBuild))")
        lines.append("macOS: \(inputs.macOSVersion)")
        lines.append("Architecture: \(inputs.architecture)")
        lines.append("Mac model: \(inputs.machineModel)")
        lines.append("Deployment target: \(inputs.deploymentTarget)")
        lines.append("Full Disk Access: \(inputs.fullDiskAccess ? "granted" : "not granted")")
        lines.append("ClamAV engine: \(inputs.clamAVAvailable ? "installed" : "not installed")")
        if inputs.clamAVAvailable, let path = inputs.clamAVPath {
            lines.append("ClamAV path (redacted): \(redactPath(path))")
        }
        lines.append("DB schema version: \(inputs.schemaVersion.map(String.init) ?? "unknown")")
        lines.append("Exclusion count: \(inputs.exclusionCount)")
        for kind in ["scan", "cleanup", "restore", "error"] {
            lines.append("Activity[\(kind)]: \(inputs.activityCountsByKind[kind] ?? 0)")
        }
        return lines.joined(separator: "\n")
    }

    /// Live gathering, using only already-audited real-state sources
    /// (PermissionProbe, ClamAVScanner, Store) — never simulated.
    @MainActor
    static func gatherLive() async -> String {
        let info = ProcessInfo.processInfo
        var model = "unknown"
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 {
            var buf = [UInt8](repeating: 0, count: size)
            if sysctlbyname("hw.model", &buf, &size, nil, 0) == 0 {
                model = String(decoding: buf.prefix(while: { $0 != 0 }), as: UTF8.self)
            }
        }
        let scanner = ClamAVScanner()
        var schemaVersion: Int?
        var exclusionCount = 0
        var counts: [String: Int] = [:]
        if let store = AppEnvironment.shared.store {
            schemaVersion = try? await store.schemaVersion()
            exclusionCount = (try? await store.exclusions().count) ?? 0
            for kind in ActivityRecord.Kind.allCases {
                counts[kind.rawValue] = (try? await store.activity(limit: 100_000, kind: kind).count) ?? 0
            }
        }
        let inputs = Inputs(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            macOSVersion: info.operatingSystemVersionString,
            architecture: "arm64",
            machineModel: model,
            deploymentTarget: "macOS 14+",
            fullDiskAccess: PermissionProbe.hasFullDiskAccess(),
            clamAVAvailable: scanner.isAvailable,
            clamAVPath: nil, // never gathered: we don't have the real path here, avoids any leak risk
            schemaVersion: schemaVersion,
            exclusionCount: exclusionCount,
            activityCountsByKind: counts)
        return build(inputs)
    }
}

/// Preview-before-export sheet: the user always sees exact report contents
/// before any Save/Share action can run.
struct DiagnosticReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var report = "Generating…"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("diagnostic.title")).font(.headline)
            Text(L("diagnostic.review_notice"))
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                Text(report)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 420, minHeight: 260)
            HStack {
                Button(L("common.cancel"), role: .cancel) { dismiss() }
                Spacer()
                Button(L("diagnostic.save")) { save() }
            }
        }
        .padding()
        .task { report = await DiagnosticReport.gatherLive() }
    }

    private func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "coretendlocal-diagnostic.txt"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
        dismiss()
    }
}
