import DesignSystem
import SwiftUI
import AppShell

/// A space that holds two views, shown one at a time behind a two-way switch.
private struct SpaceSwitch<Tag: Hashable>: View {
    let options: [(Tag, String)]
    @Binding var selection: Tag

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { option in
                Button(option.1) { selection = option.0 }
                    .buttonStyle(.serre(selection == option.0 ? .primary : .secondary))
                    .accessibilityAddTraits(selection == option.0 ? .isSelected : [])
            }
        }
    }
}

/// The Space space: the map of a folder, or its duplicates.
struct SpaceView: View {
    enum Mode: Hashable { case map, duplicates }
    let french: Bool
    @Binding var recentFilesEnabled: Bool
    @State private var mode = Mode.map

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SpaceSwitch(options: [(.map, copy("space.map")), (.duplicates, copy("space.duplicates"))], selection: $mode)
            switch mode {
            case .map: ExploreScanView(french: french, recentFilesEnabled: $recentFilesEnabled)
            case .duplicates: DuplicateScanView(french: french)
            }
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}

/// The Apps space: installed apps and their complete removal, or what starts with the Mac and
/// what macOS knows about each app's signature.
struct AppsView: View {
    enum Mode: Hashable { case apps, startup }
    let french: Bool
    @State private var mode = Mode.apps

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SpaceSwitch(options: [(.apps, copy("apps.installed")), (.startup, copy("apps.startup"))], selection: $mode)
            switch mode {
            case .apps: ApplicationsView(french: french)
            case .startup: IntegrityView(french: french)
            }
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
