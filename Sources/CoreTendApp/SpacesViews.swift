import DesignSystem
import SwiftUI
import AppShell

/// A space that holds two views, shown one at a time behind a two-way switch.
private struct SpaceSwitch<Tag: Hashable>: View {
    let options: [(Tag, String)]
    @Binding var selection: Tag
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { option in
                let selected = selection == option.0
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78)) { selection = option.0 }
                } label: {
                    Text(option.1)
                        .font(CoreTendTypography.body.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Palette.onAccent.color : Palette.secondaryInk.color)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(LinearGradient(colors: [Palette.accent.color, Palette.accent.color.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                                    .shadow(color: Palette.accent.color.opacity(0.45), radius: 10, y: 3)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.serre(.bare))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
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
