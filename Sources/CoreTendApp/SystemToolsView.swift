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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let message { SerreBanner(.note, title: message) }
            section(t("Fonctions système", "System features"),
                    t("Un petit assistant signé, installé seulement si vous l’activez, lit et range ce que macOS réserve à l’administrateur : les caches de /Library/Caches et les services qui démarrent avec le Mac. Tout part à la Corbeille ; rien n’est effacé. Le désactiver le retire.",
                      "A small signed helper, installed only if you turn it on, reads and tidies what macOS keeps for the administrator: the caches in /Library/Caches and the services that start with the Mac. Everything goes to the Trash; nothing is erased. Turning it off removes it."),
                    AnyView(helperControls))
            if helper.state == .on {
                section(t("Caches système", "System caches"),
                        t("Les caches des apps Apple restent hors liste. Une app recrée son cache au besoin.",
                          "Apple's own caches are left out. An app rebuilds its cache when it needs it."),
                        AnyView(cacheList))
                section(t("Services du système", "System services"),
                        t("Désactiver un service l’empêche de démarrer au prochain démarrage du Mac ; son fichier reste en place et vous pouvez le réactiver ici.",
                          "Turning a service off stops it from starting at the Mac's next startup; its file stays in place and you can turn it back on here."),
                        AnyView(daemonList))
            }
            section(t("Finder, widget et Raccourcis", "Finder, widget and Shortcuts"), nil, AnyView(integrations))
        }
        .task { helper.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in helper.refresh() }
        .confirmationDialog(t("Mettre ce cache à la Corbeille ?", "Move this cache to the Trash?"),
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
            Button(t("Mettre à la Corbeille", "Move to Trash"), role: .destructive) { if let item = pending { Task { await trash(item) } } }
            Button(ProductCopy.value(for: "common.cancel", french: french), role: .cancel) { pending = nil }.keyboardShortcut(.defaultAction)
        } message: {
            Text(pending.map { t("\($0.path) (\(bytes($0.bytes))) ira dans votre Corbeille. Vider la Corbeille demandera le mot de passe administrateur.",
                                 "\($0.path) (\(bytes($0.bytes))) goes to your Trash. Emptying the Trash will ask for an administrator password.") } ?? "")
        }
    }

    // MARK: - Helper

    @ViewBuilder private var helperControls: some View {
        switch helper.state {
        case .unavailable:
            note(t("Disponible dans la version publiée de CoreTend (signée et notarisée).", "Available in the released, signed and notarized CoreTend."))
        case .off:
            Button(t("Activer les fonctions système…", "Turn on system features…")) { turnOn() }.buttonStyle(.serre(.primary))
        case .needsApproval:
            note(t("macOS attend votre accord : Réglages Système › Général › Ouverture et extensions, autorisez « CoreTend ».",
                   "macOS is waiting for you: System Settings › General › Login Items & Extensions, allow « CoreTend »."))
            HStack(spacing: 8) {
                Button(t("Ouvrir Réglages Système", "Open System Settings")) { helper.openApproval() }.buttonStyle(.serre(.primary))
                Button(t("Annuler l’installation", "Cancel installation")) { turnOff() }
            }
        case .on:
            SerreSignalTag(.good, title: t("Activées", "On"))
            Button(t("Désactiver et retirer l’assistant", "Turn off and remove the helper")) { turnOff() }
        }
    }

    @ViewBuilder private var cacheList: some View {
        if let undo {
            SerreBanner(.note, title: t("\(URL(fileURLWithPath: undo.item.path).lastPathComponent) est dans la Corbeille.",
                                        "\(URL(fileURLWithPath: undo.item.path).lastPathComponent) is in the Trash.")) {
                Button(t("Annuler", "Undo")) { Task { await restore() } }.disabled(working)
            }
        }
        if let caches {
            if caches.isEmpty { note(t("Aucun cache système à ranger.", "No system cache to tidy.")) }
            ForEach(caches) { item in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(URL(fileURLWithPath: item.path).lastPathComponent).font(CoreTendTypography.body).foregroundStyle(Palette.ink.color)
                        Text(bytes(item.bytes)).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color)
                    }
                    Spacer()
                    Button(t("Corbeille…", "Trash…")) { pending = item }.disabled(working)
                        .accessibilityLabel(t("Mettre \(item.path) à la Corbeille", "Move \(item.path) to the Trash"))
                }
            }
        }
        Button(caches == nil ? t("Lire les caches système", "Read system caches") : t("Relire", "Read again")) { Task { await loadCaches() } }
            .disabled(working)
    }

    @ViewBuilder private var daemonList: some View {
        if let daemons {
            if daemons.isEmpty { note(t("Aucun service tiers.", "No third-party service.")) }
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
        Button(daemons == nil ? t("Lire les services", "Read services") : t("Relire", "Read again")) { Task { await loadDaemons() } }
            .disabled(working)
    }

    private var integrations: some View {
        VStack(alignment: .leading, spacing: 8) {
            note(t("Finder : clic droit sur un dossier › « Analyser avec CoreTend ». À activer une fois dans Réglages Système › Général › Ouverture et extensions › Extensions du Finder.",
                   "Finder: right-click a folder › « Analyze with CoreTend ». Turn it on once in System Settings › General › Login Items & Extensions › Finder extensions."))
            Button(t("Ouvrir les extensions", "Open extensions")) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") { NSWorkspace.shared.open(url) }
            }
            note(t("Widget : clic droit sur le bureau › « Modifier les widgets », puis CoreTend.",
                   "Widget: right-click the desktop › « Edit Widgets », then CoreTend."))
            note(t("Raccourcis et Siri : « Obtenir l’espace libre », « Obtenir l’espace à libérer », « Ouvrir CoreTend ». Aucune action ne déplace de fichier.",
                   "Shortcuts and Siri: « Get Free Space », « Get Space to Clear », « Open CoreTend ». No action moves a file."))
            note(t("Dock : déposez un dossier sur l’icône de CoreTend pour l’analyser.",
                   "Dock: drop a folder on CoreTend's icon to map it."))
        }
    }

    // MARK: - Actions

    private func turnOn() {
        do { try helper.turnOn() } catch { message = t("macOS a refusé l’installation de l’assistant.", "macOS refused to install the helper.") }
    }

    private func turnOff() {
        Task {
            do { try await helper.turnOff(); caches = nil; daemons = nil; undo = nil }
            catch { message = t("macOS n’a pas retiré l’assistant.", "macOS did not remove the helper.") }
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

    private func setDaemon(_ daemon: LaunchDaemonItem, enabled: Bool) async {
        working = true; defer { working = false }
        do { try await helper.setLaunchDaemon(daemon.label, enabled: enabled); daemons = try await helper.launchDaemons() } catch { report(error) }
    }

    private func report(_ error: Error) {
        message = t("L’assistant n’a pas répondu ou a refusé. Rien n’a été déplacé.", "The helper did not answer or refused. Nothing was moved.")
    }

    private func note(_ text: String) -> some View {
        Text(text).font(CoreTendTypography.caption).foregroundStyle(Palette.secondaryInk.color).fixedSize(horizontal: false, vertical: true)
    }

    private func bytes(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
    private func t(_ fr: String, _ en: String) -> String { french ? fr : en }
}
