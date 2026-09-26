import SwiftUI
import UniformTypeIdentifiers
import Domain
import AppShell

struct IntegrityView: View {
    let french: Bool
    @State private var selectingApp = false
    @State private var inspecting = false
    @State private var report: CodeSignatureReport?
    @State private var appName: String?
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button { selectingApp = true } label: {
                Label(copy("integrity.choose"), systemImage: "app.badge.checkmark")
            }
            .disabled(inspecting)
            .accessibilityHint(copy("integrity.choose.hint"))
            Text(copy("integrity.limit")).font(.callout).foregroundStyle(.secondary)
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
        }
        .fileImporter(isPresented: $selectingApp, allowedContentTypes: [.applicationBundle], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let appURL = urls.first else { return }
            inspect(appURL)
        }
    }

    private func inspect(_ url: URL) {
        report = nil; status = nil; inspecting = true; appName = url.deletingPathExtension().lastPathComponent
        let acquiredScope = url.startAccessingSecurityScopedResource()
        Task {
            defer {
                if acquiredScope { url.stopAccessingSecurityScopedResource() }
                inspecting = false
            }
            let inspector = MacOSCodeSignatureInspector()
            report = await Task.detached(priority: .utility) { inspector.inspect(at: url) }.value
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
    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
