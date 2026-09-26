import SwiftUI
import UniformTypeIdentifiers
import Domain
import AppShell
import ScanCore

struct ApplicationsView: View {
    let french: Bool
    @State private var selectingFolder = false
    @State private var scanning = false
    @State private var records: [ApplicationRecord] = []
    @State private var issues: [ApplicationDiscoveryIssue] = []
    @State private var status: String?
    @State private var task: Task<Void, Never>?
    @State private var selectingAssociationFolder = false
    @State private var associationApp: ApplicationRecord?
    @State private var associationResults: [URL] = []
    @State private var associationStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { selectingFolder = true } label: {
                Label(copy("apps.choose"), systemImage: "folder.badge.plus")
            }
            .disabled(scanning)
            .accessibilityHint(copy("apps.choose.hint"))
            Text(copy("apps.limits")).font(.callout).foregroundStyle(.secondary)
            if scanning { ProgressView(copy("scan.progress")) }
            if let status { Text(status).foregroundStyle(.secondary) }
            if !records.isEmpty {
                Text(copy("apps.count", count: records.count)).font(.headline)
                List(records) { app in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "app.dashed")
                            Text(app.displayName).font(.headline)
                            Spacer()
                            Text(app.version ?? copy("metrics.unknown")).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(app.bundleIdentifier).font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text(app.url.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                        Button(french ? "Rechercher des fichiers associés…" : "Review associated files…") {
                            associationApp = app
                            associationResults = []
                            associationStatus = nil
                            selectingAssociationFolder = true
                        }
                        .accessibilityHint(french ? "Choisir un dossier à analyser. Aucun fichier ne sera modifié." : "Choose a folder to scan. No files will be changed.")
                    }
                    .accessibilityElement(children: .combine)
                }
                .frame(minHeight: 260)
            } else if !scanning && status == nil {
                ContentUnavailableView(copy("apps.empty"), systemImage: "app.dashed")
            }
            if !issues.isEmpty { Text(copy("apps.partial", count: issues.count)).font(.caption).foregroundStyle(.secondary) }
            if let app = associationApp {
                GroupBox(french ? "Candidats possibles — \(app.displayName)" : "Possible candidates — \(app.displayName)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(french ? "Correspondance de nom seulement; appartenance non prouvée. Vérifiez avant toute action." : "Name match only; ownership is unverified. Inspect before taking any action.")
                            .font(.caption).foregroundStyle(.secondary)
                        if let associationStatus { Text(associationStatus).foregroundStyle(.secondary) }
                        ForEach(associationResults, id: \.path) { url in Text(url.path).font(.caption.monospaced()).textSelection(.enabled) }
                        if associationResults.isEmpty && associationStatus == nil { Text(french ? "Aucun candidat trouvé." : "No candidates found.").foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .fileImporter(isPresented: $selectingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let root = urls.first else { return }
            discover(root)
        }
        .fileImporter(isPresented: $selectingAssociationFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let root = urls.first, let app = associationApp else { return }
            reviewAssociations(for: app, in: root)
        }
        .onDisappear { task?.cancel() }
    }

    private func reviewAssociations(for app: ApplicationRecord, in root: URL) {
        task?.cancel()
        associationResults = []
        associationStatus = french ? "Analyse du dossier choisi…" : "Scanning chosen folder…"
        scanning = true
        let acquiredScope = root.startAccessingSecurityScopedResource()
        task = Task {
            defer {
                if acquiredScope { root.stopAccessingSecurityScopedResource() }
                scanning = false
            }
            do {
                var matches: [URL] = []
                let request = ScanRequest(roots: [.init(url: root, ruleID: .explore)])
                for try await event in LocalScanEngine().scan(request) {
                    try Task.checkCancellation()
                    if case .result(let item) = event {
                        if ApplicationAssociationMatcher.matches(item.url, bundleIdentifier: app.bundleIdentifier) {
                            matches.append(item.url)
                        }
                    }
                }
                associationResults = matches.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                associationStatus = matches.isEmpty
                    ? (french ? "Aucun nom correspondant dans le dossier choisi." : "No matching names in chosen folder.")
                    : (french ? "\(matches.count) candidats de nom; aucune attribution confirmée." : "\(matches.count) name candidates; none confirmed as app-owned.")
            } catch is CancellationError {
                associationStatus = french ? "Analyse annulée." : "Scan cancelled."
            } catch {
                associationStatus = french ? "Analyse impossible." : "Scan failed."
            }
        }
    }

    private func discover(_ root: URL) {
        records = []; issues = []; status = nil; scanning = true
        let acquiredScope = root.startAccessingSecurityScopedResource()
        task = Task {
            defer {
                if acquiredScope { root.stopAccessingSecurityScopedResource() }
                scanning = false
            }
            let service = ApplicationDiscoveryService()
            let report = await Task.detached(priority: .utility) { service.discover(in: root) }.value
            records = report.applications
            issues = report.issues
            if report.applications.isEmpty && report.issues.isEmpty { status = copy("apps.empty") }
            else if report.applications.isEmpty { status = copy("apps.failed") }
        }
    }

    private func copy(_ key: String, count: Int? = nil) -> String {
        if key == "apps.count", let count { return french ? "\(count) applications locales" : "\(count) local applications" }
        if key == "apps.partial", let count { return french ? "\(count) éléments ignorés" : "\(count) items skipped" }
        return ProductCopy.value(for: key, french: french)
    }
}
