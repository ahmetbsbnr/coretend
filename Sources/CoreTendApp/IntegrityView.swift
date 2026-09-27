import SwiftUI
import UniformTypeIdentifiers
import Domain
import AppShell
import DesignSystem

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
    @State private var appURL: URL?
    @State private var launchAgentsFolder: URL?
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            signalCard(
                title: french ? "Signature du code" : "Code signature",
                symbol: "checkmark.seal",
                description: copy("integrity.limit")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Button { selectingApp = true } label: {
                        Label(copy("integrity.choose"), systemImage: "app.badge.checkmark")
                    }
                    .disabled(inspecting)
                    .accessibilityHint(copy("integrity.choose.hint"))
                    if let appURL {
                        Text(appURL.path).font(CoreTendTypography.secondary.monospaced())
                            .foregroundStyle(Palette.secondaryInk.color).textSelection(.enabled)
                    }
                    if inspecting { ProgressView(copy("integrity.progress")) }
                    if let report {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: signatureIcon(report.state))
                                .foregroundStyle(signatureColor(report.state)).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(signatureText(report.state)).font(CoreTendTypography.body.weight(.semibold))
                                    .foregroundStyle(Palette.ink.color)
                                if let appName { Text(appName).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color) }
                            }
                        }
                        if let identifier = report.identifier {
                            LabeledContent(copy("integrity.identifier"), value: identifier)
                                .font(CoreTendTypography.secondary).textSelection(.enabled)
                        }
                        if let team = report.teamIdentifier {
                            LabeledContent(copy("integrity.team"), value: team)
                                .font(CoreTendTypography.secondary).textSelection(.enabled)
                        }
                        if report.statusCode != 0 {
                            LabeledContent(copy("integrity.status"), value: String(report.statusCode))
                                .font(CoreTendTypography.secondary.monospacedDigit()).textSelection(.enabled)
                        }
                        if report.state == .unavailable {
                            nextStep(french
                                ? "Vérifiez que le bundle choisi est accessible, puis choisissez-le à nouveau."
                                : "Check that the chosen bundle is accessible, then choose it again.")
                        }
                    } else if !inspecting {
                        Text(french ? "Aucune signature examinée. Choisissez un bundle .app pour lancer une vérification locale." : "No signature inspected. Choose an .app bundle to run a local check.")
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    evidenceSource(french
                        ? "Source : validation de signature macOS pour le bundle choisi. Le résultat ne prouve ni l’identité de l’éditeur, ni l’absence de malware, ni la sûreté."
                        : "Source: macOS signature validation for the chosen bundle. Result does not prove publisher identity, absence of malware, or safety.")
                }
            }

            signalCard(
                title: french ? "Marqueur de quarantaine" : "Quarantine marker",
                symbol: "arrow.down.doc",
                description: copy("integrity.quarantine.limit")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    if let appURL {
                        Text(appURL.path).font(CoreTendTypography.secondary.monospaced())
                            .foregroundStyle(Palette.secondaryInk.color).textSelection(.enabled)
                    } else {
                        Text(french ? "Choisissez un bundle dans la section Signature du code pour examiner son marqueur." : "Choose a bundle in Code signature to inspect its marker.")
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let quarantine {
                        Label(quarantineText(quarantine.state), systemImage: quarantineIcon(quarantine.state))
                            .font(CoreTendTypography.body.weight(.semibold))
                            .foregroundStyle(quarantineColor(quarantine.state))
                        if quarantine.state == .unavailable {
                            nextStep(french
                                ? "Vérifiez que le bundle existe et que macOS autorise sa lecture, puis relancez l’examen."
                                : "Check that the bundle exists and macOS allows it to be read, then inspect it again.")
                        }
                        if let errorCode = quarantine.errorCode {
                            LabeledContent(french ? "Code système" : "System code", value: String(errorCode))
                                .font(CoreTendTypography.secondary.monospacedDigit()).textSelection(.enabled)
                        }
                    }
                    evidenceSource(french
                        ? "Source : attribut étendu com.apple.quarantine du bundle choisi, lu localement. Présence ou absence ne détermine pas l’origine ou la sûreté."
                        : "Source: com.apple.quarantine extended attribute on the chosen bundle, read locally. Presence or absence does not establish origin or safety.")
                }
            }

            signalCard(
                title: french ? "Éléments de connexion configurés" : "Configured login items",
                symbol: "person.crop.circle.badge.checkmark",
                description: copy("integrity.loginItems.limit")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Button { selectingAgentsFolder = true } label: {
                        Label(copy("integrity.loginItems.choose"), systemImage: "folder.badge.gearshape")
                    }
                    .disabled(scanningAgents)
                    .accessibilityHint(copy("integrity.loginItems.choose.hint"))
                    if let launchAgentsFolder {
                        Text(launchAgentsFolder.path).font(CoreTendTypography.secondary.monospaced())
                            .foregroundStyle(Palette.secondaryInk.color).textSelection(.enabled)
                    }
                    if scanningAgents { ProgressView(copy("integrity.loginItems.progress")) }
                    if let launchAgentReport {
                        Text(french
                             ? "\(launchAgentReport.candidates.count) candidats configurés · \(launchAgentReport.issues.count) problèmes de lecture"
                             : "\(launchAgentReport.candidates.count) configured candidates · \(launchAgentReport.issues.count) read issues")
                            .font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                        if launchAgentReport.candidates.isEmpty && launchAgentReport.issues.isEmpty {
                            Label(copy("integrity.loginItems.empty"), systemImage: "tray")
                                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                        }
                        ForEach(Array(launchAgentReport.candidates.enumerated()), id: \.offset) { _, candidate in
                            candidateRow(candidate)
                        }
                        ForEach(Array(launchAgentReport.issues.enumerated()), id: \.offset) { _, issue in
                            issueRow(issue)
                        }
                    } else if !scanningAgents {
                        Text(french ? "Aucun dossier examiné. Choisissez un dossier précis pour lire ses fichiers plist directs." : "No folder inspected. Choose a specific folder to read its direct-child plist files.")
                            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    evidenceSource(french
                        ? "Source : fichiers plist directement présents dans le dossier choisi. Les éléments ne sont pas vérifiés comme actifs ou chargés; aucune action n’est proposée."
                        : "Source: plist files directly inside the chosen folder. Items are not checked for enabled or loaded state; no action is offered.")
                }
            }
            if let status {
                Label(status, systemImage: "exclamationmark.circle")
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.caution.color)
            }
        }
        .motion(.standard, value: report)
        .motion(.standard, value: quarantine)
        .motion(.standard, value: launchAgentReport)
        .fileImporter(isPresented: $selectingApp, allowedContentTypes: [.applicationBundle], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let appURL = urls.first else { return }
            inspect(appURL)
        }
        .fileImporter(isPresented: $selectingAgentsFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let folder = urls.first else { return }
            inspectLaunchAgents(in: folder)
        }
    }

    private func signalCard<Content: View>(title: String, symbol: String, description: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Image(systemName: symbol).foregroundStyle(Palette.accent.color).accessibilityHidden(true)
                Text(title).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(description).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
            Palette.separator.color.frame(height: 1)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.separator.color.opacity(0.75), lineWidth: 1))
    }

    private func evidenceSource(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    private func nextStep(_ text: String) -> some View {
        Label(text, systemImage: "arrow.turn.down.right")
            .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func candidateRow(_ candidate: LaunchAgentCandidate) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(candidate.label ?? copy("integrity.loginItems.unknownLabel"), systemImage: "gearshape.2")
                .font(CoreTendTypography.body.weight(.medium)).foregroundStyle(Palette.ink.color)
            if let executablePath = candidate.executablePath {
                LabeledContent(copy("integrity.loginItems.executable"), value: executablePath)
                    .font(CoreTendTypography.secondary.monospaced()).textSelection(.enabled)
            }
            LabeledContent(copy("integrity.loginItems.plist"), value: candidate.plistURL.path)
                .font(CoreTendTypography.secondary.monospaced()).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.raisedSurface.color, in: RoundedRectangle(cornerRadius: 10))
    }

    private func issueRow(_ issue: LaunchAgentIssue) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(loginAgentIssueText(issue.reason), systemImage: "exclamationmark.circle")
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.caution.color)
            Text(loginAgentNextStep(issue.reason))
                .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
            if let url = issue.plistURL {
                Text(url.path).font(CoreTendTypography.secondary.monospaced())
                    .foregroundStyle(Palette.secondaryInk.color).textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.caution.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func inspectLaunchAgents(in folder: URL) {
        launchAgentReport = nil
        launchAgentsFolder = folder
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
        report = nil
        quarantine = nil
        status = nil
        inspecting = true
        appName = url.deletingPathExtension().lastPathComponent
        appURL = url
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
        case .invalid: "xmark.seal"
        case .unavailable: "questionmark.circle"
        }
    }

    private func signatureColor(_ state: CodeSignatureState) -> Color {
        switch state {
        case .valid: Palette.accent.color
        case .invalid: Palette.danger.color
        case .unavailable: Palette.caution.color
        }
    }

    private func quarantineText(_ state: QuarantineState) -> String {
        switch state {
        case .present: copy("integrity.quarantine.present")
        case .absent: copy("integrity.quarantine.absent")
        case .unavailable: copy("integrity.quarantine.unavailable")
        }
    }

    private func quarantineIcon(_ state: QuarantineState) -> String {
        switch state {
        case .present: "arrow.down.doc.fill"
        case .absent: "minus.circle"
        case .unavailable: "questionmark.circle"
        }
    }

    private func quarantineColor(_ state: QuarantineState) -> Color {
        switch state {
        case .present: Palette.accent.color
        case .absent: Palette.secondaryInk.color
        case .unavailable: Palette.caution.color
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

    private func loginAgentNextStep(_ reason: LaunchAgentIssueReason) -> String {
        switch reason {
        case .directoryUnreadable:
            french ? "Vérifiez l’accès au dossier, ou choisissez un dossier lisible." : "Check folder access, or choose a readable folder."
        case .plistUnreadable:
            french ? "Vérifiez que ce fichier reste présent et lisible." : "Check that this file is still present and readable."
        case .malformedPlist:
            french ? "Le fichier est ignoré; vérifiez son format plist avec son éditeur habituel." : "File was skipped; check its plist format with its usual editor."
        case .plistTooLarge:
            french ? "Ce fichier dépasse la limite de lecture et reste ignoré." : "File exceeds the read limit and remains uninspected."
        case .candidateLimitReached:
            french ? "Choisissez un dossier plus ciblé pour examiner moins de 500 fichiers." : "Choose a narrower folder to inspect fewer than 500 files."
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
