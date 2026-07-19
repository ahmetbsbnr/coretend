import SwiftUI
import Persistence
import DesignSystem

@MainActor
@Observable
final class SettingsViewModel {
    var dryRunDefault = true
    var exclusions: [String] = []
    var loaded = false

    func load() async {
        guard let store = AppEnvironment.shared.store else { return }
        dryRunDefault = (try? await store.setting("dryRunDefault")) != "false"
        exclusions = (try? await store.exclusions()) ?? []
        loaded = true
    }

    func saveDryRun() {
        guard let store = AppEnvironment.shared.store else { return }
        let value = dryRunDefault ? "true" : "false"
        Task { try? await store.setSetting("dryRunDefault", value: value) }
    }

    func addExclusion(_ url: URL) {
        guard let store = AppEnvironment.shared.store else { return }
        Task {
            try? await store.addExclusion(path: url.path)
            exclusions = (try? await store.exclusions()) ?? exclusions
        }
    }

    func removeExclusion(_ path: String) {
        guard let store = AppEnvironment.shared.store else { return }
        Task {
            try? await store.removeExclusion(path: path)
            exclusions = (try? await store.exclusions()) ?? exclusions
        }
    }
}

struct MCSettingsView: View {
    @State private var model = SettingsViewModel()
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true

    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show MacCare in the menu bar", isOn: $menuBarEnabled)
                Text("The menu bar item samples system metrics only while its panel is open.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Cleaning") {
                Toggle("Dry run by default", isOn: $model.dryRunDefault)
                    .onChange(of: model.dryRunDefault) { model.saveDryRun() }
                Text("When enabled, cleanups simulate their result instead of moving files to the Trash.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Exclusions") {
                if model.exclusions.isEmpty {
                    Text("No excluded folders. Excluded locations are never scanned or cleaned.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.exclusions, id: \.self) { path in
                    HStack {
                        Text(path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(role: .destructive) {
                            model.removeExclusion(path)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add Folder…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        model.addExclusion(url)
                    }
                }
            }
            Section("Privacy") {
                Text("MacCare Local is fully offline. No telemetry, no accounts, no network calls. All data stays on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Deletion method", value: "System Trash (reversible)")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { await model.load() }
    }
}
