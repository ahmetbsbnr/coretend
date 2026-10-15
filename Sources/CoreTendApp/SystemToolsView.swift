import AppKit
import AppShell
import DesignSystem
import HelperProtocol
import SwiftUI

/// Settings › System: the optional helper (system caches and system services) and where to find
/// the Finder menu, the widget and the Shortcuts actions.
struct SystemToolsView<Section: View>: View {
    let french: Bool
    let section: (String, String?, AnyView) -> Section
    @State private var helper = SystemHelper()
    @State private var caches: [SystemCacheItem]?
    @State private var daemons: [LaunchDaemonItem]?
    @State private var working = false
    @State private var pending: SystemCacheItem?
    @State private var undo: (item: SystemCacheItem, trashPath: String)?
    @State private var message: String?
    @State private var snapshots: [String]?
    @State private var pendingSnapshot: String?
    @State private var confirmReindex = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let message { SerreBanner(.note, title: message) }
            section(ProductCopy.inline("Fonctions système", "System features", french: french),
                    ProductCopy.inline("Un petit assistant signé, installé seulement si vous l’activez, lit et range ce que macOS réserve à l’administrateur : les caches de /Library/Caches et les services qui démarrent avec le Mac. Tout part à la Corbeille ; rien n’est effacé. Le désactiver le retire.", "A small signed helper, installed only if you turn it on, reads and tidies what macOS keeps for the administrator: the caches in /Library/Caches and the services that start with the Mac. Everything goes to the Trash; nothing is erased. Turning it off removes it.", french: french),
                    AnyView(helperControls))
            if helper.state == .on {
                section(ProductCopy.inline("Caches système", "System caches", french: french),
                        ProductCopy.inline("Les caches des apps Apple restent hors liste. Une app recrée son cache au besoin.", "Apple's own caches are left out. An app rebuilds its cache when it needs it.", french: french),
                        AnyView(cacheList))
                section(ProductCopy.inline("Instantanés Time Machine locaux", "Local Time Machine snapshots", french: french),
                        ProductCopy.inline("macOS garde des instantanés locaux et les réduit seul quand la place manque. En supprimer un libère sa place tout de suite, mais c’est la seule action de CoreTend qui efface pour de bon. Vos sauvegardes sur disque externe ne sont pas touchées.", "macOS keeps local snapshots and thins them on its own when room is needed. Deleting one frees its space now, but it is the one CoreTend action that erases for good. Your backups on an external disk are not touched.", french: french),
                        AnyView(snapshotList))
                section(ProductCopy.inline("Spotlight", "Spotlight", french: french),
                        ProductCopy.inline("Si la recherche ne trouve plus vos fichiers, Spotlight peut reconstruire son index. Aucun fichier n’est touché ; la recherche reste incomplète le temps de l’indexation.", "If search no longer finds your files, Spotlight can rebuild its index. No file is touched; search stays incomplete while it indexes.", french: french),
                        AnyView(Button(ProductCopy.inline("Réindexer Spotlight…", "Reindex Spotlight…", french: french)) { confirmReindex = true }.disabled(working)))
                section(ProductCopy.inline("Services du système", "System services", french: french),
                        ProductCopy.inline("Désactiver un service l’empêche de démarrer au prochain démarrage du Mac ; son fichier reste en place et vous pouvez le réactiver ici.", "Turning a service off stops it from starting at the Mac's next startup; its file stays in place and you can turn it back on here.", french: french),
                        AnyView(daemonList))
            }
            section(ProductCopy.inline("Finder, widget et Raccourcis", "Finder, widget and Shortcuts", french: french), nil, AnyView(integrations))
        }
        .task { helper.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in helper.refresh() }
        .confirmationDialog(ProductCopy.inline("Supprimer cet instantané définitivement ?", "Delete this snapshot for good?", french: french),
                            isPresented: Binding(get: { pendingSnapshot != nil }, set: { if !$0 { pendingSnapshot = nil } }), titleVisibility: .visible) {
            Button(ProductCopy.inline("Supprimer définitivement", "Delete for good", french: french), role: .destructive) { if let date = pendingSnapshot { Task { await deleteSnapshot(date) } } }
            Button(ProductCopy.value(for: "common.cancel", french: french), role: .cancel) { pendingSnapshot = nil }.keyboardShortcut(.defaultAction)
        } message: {
            Text(pendingSnapshot.map { ProductCopy.inline("L’instantané du %1$@ sera effacé et ne pourra pas être remis en place. C’est la seule suppression définitive de CoreTend.", "The snapshot of %1$@ will be erased and cannot be put back. This is CoreTend's only permanent deletion.", french: french, "\(snapshotLabel($0))") } ?? "")
        }
        .confirmationDialog(ProductCopy.inline("Réindexer Spotlight ?", "Reindex Spotlight?", french: french), isPresented: $confirmReindex, titleVisibility: .visible) {
            Button(ProductCopy.inline("Réindexer", "Reindex", french: french)) { Task { await reindex() } }
            Button(ProductCopy.value(for: "common.cancel", french: french), role: .cancel) {}.keyboardShortcut(.defaultAction)
        } message: {
            Text(ProductCopy.inline("Spotlight efface son index du disque de démarrage et le reconstruit. Cela peut prendre de quelques minutes à quelques heures.", "Spotlight erases the startup disk's index and rebuilds it. It can take from a few minutes to a few hours.", french: french))
        }
        .confirmationDialog(ProductCopy.inline("Mettre ce cache à la Corbeille ?", "Move this cache to the Trash?", french: french),
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
            Button(ProductCopy.inline("Mettre à la Corbeille", "Move to Trash", french: french), role: .destructive) { if let item = pending { Task { await trash(item) } } }
            Button(ProductCopy.value(for: "common.cancel", french: french), role: .cancel) { pending = nil }.keyboardShortcut(.defaultAction)
        } message: {
            Text(pending.map { ProductCopy.inline("%1$@ (%2$@) ira dans votre Corbeille. Vider la Corbeille demandera le mot de passe administrateur.", "%1$@ (%2$@) goes to your Trash. Emptying the Trash will ask for an administrator password.", french: french, "\($0.path)", "\(bytes($0.bytes))") } ?? "")
        }
    }

    // MARK: - Helper

    @ViewBuilder private var helperControls: some View {
        switch helper.state {
        case .unavailable:
            note(ProductCopy.inline("Disponible dans la version publiée de CoreTend (signée et notarisée).", "Available in the released, signed and notarized CoreTend.", french: french))
        case .off:
            Button(ProductCopy.inline("Activer les fonctions système…", "Turn on system features…", french: french)) { turnOn() }.buttonStyle(.serre(.primary))
        case .needsApproval:
            note(ProductCopy.inline("macOS attend votre accord : Réglages Système › Général › Ouverture et extensions, autorisez « CoreTend ».", "macOS is waiting for you: System Settings › General › Login Items & Extensions, allow « CoreTend ».", french: french))
            HStack(spacing: 8) {
                Button(ProductCopy.inline("Ouvrir Réglages Système", "Open System Settings", french: french)) { helper.openApproval() }.buttonStyle(.serre(.primary))
                Button(ProductCopy.inline("Annuler l’installation", "Cancel installation", french: french)) { turnOff() }
            }
        case .on:
            SerreSignalTag(.good, title: ProductCopy.inline("Activées", "On", french: french))
            Button(ProductCopy.inline("Désactiver et retirer l’assistant", "Turn off and remove the helper", french: french)) { turnOff() }
        }
    }

    @ViewBuilder private var cacheList: some View {
        if let undo {
            SerreBanner(.note, title: ProductCopy.inline("%1$@ est dans la Corbeille.", "%1$@ is in the Trash.", french: french, "\(URL(fileURLWithPath: undo.item.path).lastPathComponent)")) {
                Button(ProductCopy.inline("Annuler", "Undo", french: french)) { Task { await restore() } }.disabled(working)
            }
        }
        if let caches {
            if caches.isEmpty { note(ProductCopy.inline("Aucun cache système à ranger.", "No system cache to tidy.", french: french)) }
            ForEach(caches) { item in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(URL(fileURLWithPath: item.path).lastPathComponent).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                        Text(bytes(item.bytes)).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    }
                    Spacer()
                    Button(ProductCopy.inline("Corbeille…", "Trash…", french: french)) { pending = item }.disabled(working)
                        .accessibilityLabel(ProductCopy.inline("Mettre %1$@ à la Corbeille", "Move %1$@ to the Trash", french: french, "\(item.path)"))
                }
            }
        }
        Button(caches == nil ? ProductCopy.inline("Lire les caches système", "Read system caches", french: french) : ProductCopy.inline("Relire", "Read again", french: french)) { Task { await loadCaches() } }
            .disabled(working)
    }

    @ViewBuilder private var daemonList: some View {
        if let daemons {
            if daemons.isEmpty { note(ProductCopy.inline("Aucun service tiers.", "No third-party service.", french: french)) }
            ForEach(daemons) { daemon in
                Toggle(isOn: Binding(get: { !daemon.disabled }, set: { value in Task { await setDaemon(daemon, enabled: value) } })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(daemon.label).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                        Text(daemon.program).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                .disabled(working)
                .accessibilityLabel(daemon.label)
                .accessibilityHint(daemon.program)
            }
        }
        Button(daemons == nil ? ProductCopy.inline("Lire les services", "Read services", french: french) : ProductCopy.inline("Relire", "Read again", french: french)) { Task { await loadDaemons() } }
            .disabled(working)
    }

    @ViewBuilder private var snapshotList: some View {
        if let snapshots {
            if snapshots.isEmpty { note(ProductCopy.inline("Aucun instantané local.", "No local snapshot.", french: french)) }
            ForEach(snapshots, id: \.self) { date in
                HStack(spacing: 10) {
                    Text(snapshotLabel(date)).font(CoreTendTypography.body.monospacedDigit()).foregroundStyle(Palette.ink.color)
                    Spacer()
                    Button(ProductCopy.inline("Supprimer…", "Delete…", french: french)) { pendingSnapshot = date }.disabled(working)
                        .accessibilityLabel(ProductCopy.inline("Supprimer l’instantané du %1$@", "Delete the snapshot of %1$@", french: french, "\(snapshotLabel(date))"))
                }
            }
        }
        Button(snapshots == nil ? ProductCopy.inline("Lire les instantanés", "Read snapshots", french: french) : ProductCopy.inline("Relire", "Read again", french: french)) { Task { await loadSnapshots() } }
            .disabled(working)
    }

    /// `2026-10-15-120000` as the person reads a date and time.
    private func snapshotLabel(_ date: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd-HHmmss"
        guard let value = parser.date(from: date) else { return date }
        return value.formatted(date: .abbreviated, time: .shortened)
    }

    private var integrations: some View {
        VStack(alignment: .leading, spacing: 8) {
            note(ProductCopy.inline("Finder : clic droit sur un dossier › « Analyser avec CoreTend ». À activer une fois dans Réglages Système › Général › Ouverture et extensions › Extensions du Finder.", "Finder: right-click a folder › « Analyze with CoreTend ». Turn it on once in System Settings › General › Login Items & Extensions › Finder extensions.", french: french))
            Button(ProductCopy.inline("Ouvrir les extensions", "Open extensions", french: french)) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") { NSWorkspace.shared.open(url) }
            }
            note(ProductCopy.inline("Widget : clic droit sur le bureau › « Modifier les widgets », puis CoreTend.", "Widget: right-click the desktop › « Edit Widgets », then CoreTend.", french: french))
            note(ProductCopy.inline("Raccourcis et Siri : « Obtenir l’espace libre », « Obtenir l’espace à libérer », « Ouvrir CoreTend ». Aucune action ne déplace de fichier.", "Shortcuts and Siri: « Get Free Space », « Get Space to Clear », « Open CoreTend ». No action moves a file.", french: french))
            note(ProductCopy.inline("Dock : déposez un dossier sur l’icône de CoreTend pour l’analyser.", "Dock: drop a folder on CoreTend's icon to map it.", french: french))
        }
    }

    // MARK: - Actions

    private func turnOn() {
        do { try helper.turnOn() } catch { message = ProductCopy.inline("macOS a refusé l’installation de l’assistant.", "macOS refused to install the helper.", french: french) }
    }

    private func turnOff() {
        Task {
            do { try await helper.turnOff(); caches = nil; daemons = nil; undo = nil; snapshots = nil }
            catch { message = ProductCopy.inline("macOS n’a pas retiré l’assistant.", "macOS did not remove the helper.", french: french) }
        }
    }

    private func loadCaches() async {
        working = true; defer { working = false }
        do { caches = try await helper.systemCaches() } catch { report(error) }
    }

    private func loadDaemons() async {
        working = true; defer { working = false }
        do { daemons = try await helper.launchDaemons() } catch { report(error) }
    }

    private func trash(_ item: SystemCacheItem) async {
        pending = nil
        working = true; defer { working = false }
        do {
            let moved = try await helper.trash(item)
            undo = (item, moved)
            caches?.removeAll { $0 == item }
        } catch { report(error) }
    }

    private func restore() async {
        guard let undo else { return }
        working = true; defer { working = false }
        do {
            try await helper.restore(trashPath: undo.trashPath, originalPath: undo.item.path)
            self.undo = nil
            await loadCaches()
        } catch { report(error) }
    }

    private func loadSnapshots() async {
        working = true; defer { working = false }
        do { snapshots = try await helper.localSnapshots() } catch { report(error) }
    }

    /// Deletes one snapshot and says the space it freed, measured before and after.
    private func deleteSnapshot(_ date: String) async {
        pendingSnapshot = nil
        working = true; defer { working = false }
        let before = Self.freeBytes()
        do {
            try await helper.deleteLocalSnapshot(date)
            snapshots = try await helper.localSnapshots()
            if let before, let after = Self.freeBytes(), after > before {
                message = ProductCopy.inline("Instantané supprimé ; %1$@ libérés (mesuré).", "Snapshot deleted; %1$@ freed (measured).", french: french, "\(bytes(after - before))")
            } else {
                message = ProductCopy.inline("Instantané supprimé.", "Snapshot deleted.", french: french)
            }
        } catch {
            message = ProductCopy.inline("L’assistant n’a pas supprimé l’instantané.", "The helper did not delete the snapshot.", french: french)
        }
    }

    private func reindex() async {
        working = true; defer { working = false }
        do {
            try await helper.reindexSpotlight()
            message = ProductCopy.inline("Spotlight reconstruit son index.", "Spotlight is rebuilding its index.", french: french)
        } catch { message = ProductCopy.inline("L’assistant n’a pas relancé l’indexation.", "The helper did not start indexing.", french: french) }
    }

    private static func freeBytes() -> Int64? {
        (try? FileManager.default.attributesOfFileSystem(forPath: "/")[.systemFreeSize] as? NSNumber)?.int64Value
    }

    private func setDaemon(_ daemon: LaunchDaemonItem, enabled: Bool) async {
        working = true; defer { working = false }
        do { try await helper.setLaunchDaemon(daemon.label, enabled: enabled); daemons = try await helper.launchDaemons() } catch { report(error) }
    }

    private func report(_ error: Error) {
        message = ProductCopy.inline("L’assistant n’a pas répondu ou a refusé. Rien n’a été déplacé.", "The helper did not answer or refused. Nothing was moved.", french: french)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color).fixedSize(horizontal: false, vertical: true)
    }

    private func bytes(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
    private func t(_ fr: String, _ en: String) -> String { ProductCopy.inline(fr, en, french: french) }
}
