import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Domain
import AppShell
import DesignSystem

/// Integrity, "les étiquettes": what macOS records about one chosen app, as a plant label with one
/// tag per signal (signature, quarantine marker), each with its source and its limits; and the
/// login items configured in a LaunchAgents folder the person picks. Nothing here changes a file
/// and no signal is presented as a verdict on safety.
struct IntegrityView: View {
    let french: Bool
    @State private var selectingApp = false
    @State private var selectingAgentsFolder = false
    @State private var selectingSurveyFolder = false
    /// Folder the system panel opens on when a suggested folder is chosen in the App Sandbox.
    @State private var suggestedDirectory: URL?
    @State private var inspecting = false
    @State private var scanningAgents = false
    @State private var report: CodeSignatureReport?
    @State private var quarantine: QuarantineReport?
    @State private var launchAgentReport: LaunchAgentInspectionReport?
    @State private var appName: String?
    @State private var appURL: URL?
    @State private var launchAgentsFolder: URL?
    /// Changes per inspected app, so its tags swing into place once.
    @State private var labelSeed = UUID()
    /// Every app of a folder labelled in one pass.
    @State private var surveyRows: [(url: URL, signature: CodeSignatureState, quarantine: QuarantineState)] = []
    @State private var surveying = false
    @State private var surveyFolder: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let appURL {
                plantLabel(appURL)
            } else {
                SerreParcel {
                    SerreEmptyState(title: copy("integrity.initial.title"), message: copy("integrity.initial.message")) {
                        Button { selectingApp = true } label: {
                            Label { Text(copy("integrity.choose")) } icon: { SerreIcon(.integrity, size: 15) }
                        }
                        .buttonStyle(.serre(.primary))
                        .accessibilityHint(copy("integrity.choose.hint"))
                        .padding(.top, 6)
                    }
                }
            }
            survey
            loginItems
        }
        .fileImporter(isPresented: $selectingApp, allowedContentTypes: [.applicationBundle], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let appURL = urls.first else { return }
            inspect(appURL)
        }
        .fileImporter(isPresented: $selectingAgentsFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let folder = urls.first else { return }
            inspectLaunchAgents(in: folder)
        }
        .fileImporter(isPresented: $selectingSurveyFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let folder = urls.first else { return }
            runSurvey(folder)
        }
        .fileDialogDefaultDirectory(suggestedDirectory)
    }

    // MARK: - Plant label

    private func plantLabel(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SerreParcel {
                HStack(alignment: .center, spacing: 14) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable().interpolation(.high).frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy("integrity.label")).font(CoreTendTypography.caption.weight(.semibold)).foregroundStyle(Palette.secondaryInk.color)
                        Text(appName ?? url.lastPathComponent).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                        Text(url.path).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                            .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    }
                    Spacer(minLength: 8)
                    Button(copy("integrity.chooseOther")) { selectingApp = true }
                        .buttonStyle(.serre(.secondary))
                        .disabled(inspecting)
                        .accessibilityHint(copy("integrity.choose.hint"))
                }
            }
            if inspecting {
                Text(copy("integrity.progress")).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
            }
            if let report {
                SerreSignalTag(signatureTone(report.state), title: "\(copy("integrity.signature")) · \(signatureText(report.state))", order: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let identifier = report.identifier { fact(copy("integrity.identifier"), identifier) }
                        if let team = report.teamIdentifier { fact(copy("integrity.team"), team) }
                        if report.statusCode != 0 { fact(copy("integrity.status"), String(report.statusCode)) }
                        if report.state == .unavailable {
                            note(french ? "Vérifiez que le bundle choisi est accessible, puis choisissez-le à nouveau."
                                        : "Check that the chosen bundle is accessible, then choose it again.")
                        }
                        source(french
                            ? "Source : validation de signature macOS pour le bundle choisi. Le résultat ne prouve ni l’identité de l’éditeur, ni l’absence de malware, ni la sûreté."
                            : "Source: macOS signature validation for the chosen bundle. Result does not prove publisher identity, absence of malware, or safety.")
                    }
                }
                .id("signature.\(labelSeed)")
            }
            if let quarantine {
                SerreSignalTag(quarantineTone(quarantine.state), title: "\(copy("integrity.quarantine")) · \(quarantineText(quarantine.state))", order: 1) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let errorCode = quarantine.errorCode { fact(french ? "Code système" : "System code", String(errorCode)) }
                        if quarantine.state == .unavailable {
                            note(french ? "Vérifiez que le bundle existe et que macOS autorise sa lecture, puis relancez l’examen."
                                        : "Check that the bundle exists and macOS allows it to be read, then inspect it again.")
                        }
                        source(copy("integrity.quarantine.limit"))
                        source(french
                            ? "Source : attribut étendu com.apple.quarantine du bundle choisi, lu localement."
                            : "Source: com.apple.quarantine extended attribute on the chosen bundle, read locally.")
                    }
                }
                .id("quarantine.\(labelSeed)")
            }
            Text(copy("integrity.limit")).font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fact(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
            Text(value).font(CoreTendTypography.caption.weight(.semibold)).foregroundStyle(Palette.ink.color).textSelection(.enabled)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(CoreTendTypography.caption).foregroundStyle(Palette.ink.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func source(_ text: String) -> some View {
        Text(text).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Login items

    /// Labels every app at the top of a folder in one pass: signature and quarantine per app, and a
    /// count of what macOS refused or could not read. Signals only, never a verdict.
    private var survey: some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 12) {
                Text(french ? "Toute la pépinière" : "The whole nursery").font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                    .accessibilityAddTraits(.isHeader)
                Text(french ? "Étiquette toutes les apps d’un dossier en une passe : signature et marqueur de quarantaine, sans rien modifier."
                            : "Labels every app of a folder in one pass: signature and quarantine marker, changing nothing.")
                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ForEach(ApplicationFolders.candidates(home: SandboxAccess.userHome), id: \.path) { folder in
                        Button(folder.path == "/Applications" ? "Applications" : (french ? "Applications (les vôtres)" : "Applications (yours)")) {
                            if SandboxAccess.isSandboxed {
                                suggestedDirectory = folder
                                selectingSurveyFolder = true
                            } else {
                                runSurvey(folder)
                            }
                        }
                        .buttonStyle(.serre(surveyFolder == folder ? .primary : .secondary))
                        .disabled(surveying)
                    }
                    if surveying {
                        Text(french ? "Étiquetage de \(surveyRows.count) apps…" : "Labelling \(surveyRows.count) apps…")
                            .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    }
                }
                if !surveyRows.isEmpty {
                    let refused = surveyRows.filter { $0.signature == .invalid }.count
                    let unreadable = surveyRows.filter { $0.signature == .unavailable }.count
                    let marked = surveyRows.filter { $0.quarantine == .present }.count
                    HStack(spacing: 10) {
                        SerreRiskBadge(.low, label: french ? "\(surveyRows.count - refused - unreadable) validées" : "\(surveyRows.count - refused - unreadable) validated")
                        if refused > 0 { SerreRiskBadge(.high, label: french ? "\(refused) refusées" : "\(refused) refused") }
                        if unreadable > 0 { SerreRiskBadge(.medium, label: french ? "\(unreadable) illisibles" : "\(unreadable) unreadable") }
                        Text(french ? "· \(marked) avec marqueur de quarantaine" : "· \(marked) with a quarantine marker")
                            .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    }
                    VStack(spacing: 2) {
                        ForEach(Array(surveyRows.sorted { rank($0.signature) < rank($1.signature) }.enumerated()), id: \.element.url.path) { index, row in
                            HStack(spacing: 12) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: row.url.path))
                                    .resizable().frame(width: 22, height: 22).accessibilityHidden(true)
                                Text(row.url.deletingPathExtension().lastPathComponent)
                                    .font(CoreTendTypography.body).foregroundStyle(Palette.ink.color).lineLimit(1)
                                Spacer()
                                SerreRiskBadge(row.signature == .valid ? .low : (row.signature == .invalid ? .high : .medium),
                                               label: signatureText(row.signature))
                                Text(row.quarantine == .present ? (french ? "quarantaine" : "quarantine")
                                     : (row.quarantine == .absent ? "—" : (french ? "illisible" : "unreadable")))
                                    .font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                                    .frame(width: 80, alignment: .trailing)
                                    .help(quarantineText(row.quarantine))
                            }
                            .padding(.vertical, 4)
                            .serrePress(index)
                        }
                    }
                }
            }
        }
    }

    private func rank(_ state: CodeSignatureState) -> Int {
        switch state {
        case .invalid: 0
        case .unavailable: 1
        case .valid: 2
        }
    }

    private func runSurvey(_ folder: URL) {
        surveyFolder = folder
        surveyRows = []
        surveying = true
        let acquiredScope = folder.startAccessingSecurityScopedResource()
        Task {
            defer { if acquiredScope { folder.stopAccessingSecurityScopedResource() } }
            let apps = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension == "app" }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            for app in apps {
                let result = await Task.detached(priority: .utility) {
                    (MacOSCodeSignatureInspector().inspect(at: app).state, MacOSQuarantineInspector().inspect(at: app).state)
                }.value
                surveyRows.append((app, result.0, result.1))
            }
            surveying = false
        }
    }

    private var loginItems: some View {
        SerreParcel {
            VStack(alignment: .leading, spacing: 12) {
                Text(copy("integrity.loginItems")).font(CoreTendTypography.sectionTitle).foregroundStyle(Palette.ink.color)
                    .accessibilityAddTraits(.isHeader)
                Text(copy("integrity.loginItems.limit")).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    .fixedSize(horizontal: false, vertical: true)
                let found = LaunchAgentFolders.candidates(home: SandboxAccess.userHome)
                HStack(spacing: 10) {
                    // Detected folders are offered, never read: the click is the choice.
                    ForEach(found, id: \.path) { folder in
                        Button(folderName(folder)) {
                            if SandboxAccess.isSandboxed {
                                suggestedDirectory = folder
                                selectingAgentsFolder = true
                            } else {
                                inspectLaunchAgents(in: folder)
                            }
                        }
                            .buttonStyle(.serre(launchAgentsFolder == folder ? .primary : .secondary))
                            .help(folder.path)
                            .disabled(scanningAgents)
                    }
                    Button(found.isEmpty ? copy("integrity.loginItems.choose") : copy("integrity.loginItems.other")) { selectingAgentsFolder = true }
                        .buttonStyle(.serre(.secondary))
                        .disabled(scanningAgents)
                        .accessibilityHint(copy("integrity.loginItems.choose.hint"))
                }
                if !found.isEmpty {
                    Text(copy("integrity.loginItems.detected")).font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
                }
                if let launchAgentsFolder {
                    Text(launchAgentsFolder.path).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                        .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                }
                if scanningAgents {
                    Text(copy("integrity.loginItems.progress")).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                }
                if let launchAgentReport {
                    Palette.separator.color.frame(height: 1)
                    let candidates = launchAgentReport.candidates.count, problems = launchAgentReport.issues.count
                    let p = ProductFormat.frenchPlural
                    Text(french
                         ? "\(ProductFormat.count(candidates, french: true)) candidat\(p(candidates)) configuré\(p(candidates)) · \(ProductFormat.count(problems, french: true)) problème\(p(problems)) de lecture"
                         : "\(ProductFormat.count(candidates, french: false)) configured candidate\(candidates == 1 ? "" : "s") · \(ProductFormat.count(problems, french: false)) read issue\(problems == 1 ? "" : "s")")
                        .font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
                    if launchAgentReport.candidates.isEmpty && launchAgentReport.issues.isEmpty {
                        Text(copy("integrity.loginItems.empty")).font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                    }
                    ForEach(Array(launchAgentReport.candidates.enumerated()), id: \.offset) { index, candidate in
                        candidateRow(candidate).serreRise(index)
                    }
                    ForEach(Array(launchAgentReport.issues.enumerated()), id: \.offset) { _, issue in
                        SerreBanner(.partial, title: loginAgentIssueText(issue.reason),
                                    message: loginAgentNextStep(issue.reason) + (issue.plistURL.map { "\n" + $0.path } ?? ""))
                    }
                    source(french
                        ? "Source : fichiers plist directement présents dans le dossier choisi. Les éléments ne sont pas vérifiés comme actifs ou chargés ; aucune action n’est proposée."
                        : "Source: plist files directly inside the chosen folder. Items are not checked for enabled or loaded state; no action is offered.")
                }
            }
        }
        .motion(.standard, value: launchAgentReport)
    }

    private func folderName(_ folder: URL) -> String {
        folder.path == "/Library/LaunchAgents"
            ? (french ? "LaunchAgents partagés" : "Shared LaunchAgents")
            : (french ? "Vos LaunchAgents" : "Your LaunchAgents")
    }

    private func candidateRow(_ candidate: LaunchAgentCandidate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gearshape.2").foregroundStyle(Palette.accent.color).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.label ?? copy("integrity.loginItems.unknownLabel"))
                    .font(CoreTendTypography.body.weight(.medium)).foregroundStyle(Palette.ink.color)
                if let executablePath = candidate.executablePath {
                    fact(copy("integrity.loginItems.executable"), executablePath)
                }
                fact(copy("integrity.loginItems.plist"), candidate.plistURL.lastPathComponent)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raisedSurface.color, in: LeafCorner.control.shape)
        .accessibilityElement(children: .combine)
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
        inspecting = true
        labelSeed = UUID()
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

    private func signatureTone(_ state: CodeSignatureState) -> SerreSignalTone {
        switch state {
        case .valid: .good
        case .invalid: .bad
        case .unavailable: .caution
        }
    }

    private func quarantineText(_ state: QuarantineState) -> String {
        switch state {
        case .present: copy("integrity.quarantine.present")
        case .absent: copy("integrity.quarantine.absent")
        case .unavailable: copy("integrity.quarantine.unavailable")
        }
    }

    /// A marker is information, not a verdict: present or absent are both neutral.
    private func quarantineTone(_ state: QuarantineState) -> SerreSignalTone {
        switch state {
        case .present, .absent: .neutral
        case .unavailable: .caution
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
