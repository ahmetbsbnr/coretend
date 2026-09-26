import SwiftUI
import UniformTypeIdentifiers
import Domain
import AppShell

struct IntegrityView: View {
    let french: Bool
    @State private var selectingApp = false
    @State private var selectingAgentsFolder = false
    @State private var inspecting = false
    @State private var scanningAgents = false
    @State private var report: CodeSignatureReport?
    @State private var quarantine: QuarantineReport?
    @State private var launchAgentReport: LaunchAgentInspectionReport?
    @State private var appName: String?
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button { selectingApp = true } label: {
                Label(copy("integrity.choose"), systemImage: "app.badge.checkmark")
            }
            .disabled(inspecting)
            .accessibilityHint(copy("integrity.choose.hint"))
            Button { selectingAgentsFolder = true } label: {
                Label(copy("integrity.loginItems.choose"), systemImage: "person.crop.circle.badge.checkmark")
            }
            .disabled(scanningAgents)
            .accessibilityHint(copy("integrity.loginItems.choose.hint"))
            Text(copy("integrity.limit")).font(.callout).foregroundStyle(.secondary)
            Text(copy("integrity.loginItems.limit")).font(.callout).foregroundStyle(.secondary)
            if inspecting { ProgressView(copy("integrity.progress")) }
            if let status { Text(status).foregroundStyle(.secondary) }
            if let report {
                Label(signatureText(report.state), systemImage: signatureIcon(report.state))
                    .font(.title3.weight(.semibold))
                if let appName { Text(appName).font(.headline) }
                if let identifier = report.identifier { LabeledContent(copy("integrity.identifier"), value: identifier) }
                if let team = report.teamIdentifier { LabeledContent(copy("integrity.team"), value: team) }
                if report.statusCode != 0 {
                    LabeledContent(copy("integrity.status"), value: String(report.statusCode))
                        .font(.caption.monospaced())
                }
            }
            if let quarantine {
                Label(quarantineText(quarantine.state), systemImage: "arrow.down.doc")
                    .foregroundStyle(.secondary)
                Text(copy("integrity.quarantine.limit"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if scanningAgents { ProgressView(copy("integrity.loginItems.progress")) }
            if let launchAgentReport {
                Text(copy("integrity.loginItems.results"))
                    .font(.headline)
                if launchAgentReport.candidates.isEmpty && launchAgentReport.issues.isEmpty {
                    Text(copy("integrity.loginItems.empty")).foregroundStyle(.secondary)
                }
                ForEach(Array(launchAgentReport.candidates.enumerated()), id: \.offset) { item in
                    let candidate = item.element
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.label ?? copy("integrity.loginItems.unknownLabel")).font(.headline)
                        if let executablePath = candidate.executablePath {
                            LabeledContent(copy("integrity.loginItems.executable"), value: executablePath)
                                .font(.caption.monospaced())
                        }
                        LabeledContent(copy("integrity.loginItems.plist"), value: candidate.plistURL.path)
                            .font(.caption.monospaced())
                    }
                    .padding(.vertical, 4)
                }
                ForEach(Array(launchAgentReport.issues.enumerated()), id: \.offset) { item in
                    let issue = item.element
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loginAgentIssueText(issue.reason)).foregroundStyle(.secondary)
                        if let url = issue.plistURL {
                            Text(url.path).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $selectingApp, allowedContentTypes: [.applicationBundle], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let appURL = urls.first else { return }
            inspect(appURL)
        }
        .fileImporter(isPresented: $selectingAgentsFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let folder = urls.first else { return }
            inspectLaunchAgents(in: folder)
        }
    }

    private func inspectLaunchAgents(in folder: URL) {
        launchAgentReport = nil
        scanningAgents = true
        let acquiredScope = folder.startAccessingSecurityScopedResource()
        Task {
            defer {
                if acquiredScope { folder.stopAccessingSecurityScopedResource() }
                scanningAgents = false
            }
            launchAgentReport = await Task.detached(priority: .utility) {
                LaunchAgentInspector().inspect(in: folder)
            }.value
        }
    }

    private func inspect(_ url: URL) {
        report = nil; quarantine = nil; status = nil; inspecting = true; appName = url.deletingPathExtension().lastPathComponent
        let acquiredScope = url.startAccessingSecurityScopedResource()
        Task {
            defer {
                if acquiredScope { url.stopAccessingSecurityScopedResource() }
                inspecting = false
            }
            let inspector = MacOSCodeSignatureInspector()
            let results = await Task.detached(priority: .utility) {
                (inspector.inspect(at: url), MacOSQuarantineInspector().inspect(at: url))
            }.value
            report = results.0
            quarantine = results.1
        }
    }

    private func signatureText(_ state: CodeSignatureState) -> String {
        switch state {
        case .valid: copy("integrity.valid")
        case .invalid: copy("integrity.invalid")
        case .unavailable: copy("integrity.unavailable")
        }
    }
    private func signatureIcon(_ state: CodeSignatureState) -> String {
        switch state {
        case .valid: "checkmark.seal"
        case .invalid: "exclamationmark.seal"
        case .unavailable: "questionmark.circle"
        }
    }
    private func quarantineText(_ state: QuarantineState) -> String {
        switch state {
        case .present: copy("integrity.quarantine.present")
        case .absent: copy("integrity.quarantine.absent")
        case .unavailable: copy("integrity.quarantine.unavailable")
        }
    }
    private func loginAgentIssueText(_ reason: LaunchAgentIssueReason) -> String {
        switch reason {
        case .directoryUnreadable: copy("integrity.loginItems.issue.directory")
        case .plistUnreadable: copy("integrity.loginItems.issue.unreadable")
        case .malformedPlist: copy("integrity.loginItems.issue.malformed")
        case .plistTooLarge: copy("integrity.loginItems.issue.tooLarge")
        case .candidateLimitReached: copy("integrity.loginItems.issue.limit")
        }
    }
    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
