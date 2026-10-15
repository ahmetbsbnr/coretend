import DesignSystem
import SwiftUI
import AppShell

/// A space that holds two views, shown one at a time behind a two-way switch.
private struct SpaceSwitch<Tag: Hashable>: View {
    let options: [(Tag, String)]
    @Binding var selection: Tag
    @Namespace private var marker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Decision 0009: one bed with a leaf marker that slides to the chosen view.
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { option in
                let selected = selection == option.0
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.72)) { selection = option.0 }
                } label: {
                    Text(option.1)
                        .font(CoreTendTypography.body.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Palette.onAccent.color : Palette.secondaryInk.color)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background {
                            if selected {
                                LeafCorner.control.shape.fill(Palette.accent.color)
                                    .matchedGeometryEffect(id: "marker", in: marker)
                            }
                        }
                        .contentShape(LeafCorner.control.shape)
                }
                .buttonStyle(.serre(.bare))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Palette.surface.color, in: LeafCorner.control.shape)
        .overlay(LeafCorner.control.shape.strokeBorder(Palette.separator.color, lineWidth: 1))
    }
}

/// The view under a switch arrives from the side it was chosen on.
private struct SwitchedContent<Content: View>: View {
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .offset(y: 22).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .opacity))
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
            case .map: SwitchedContent { ExploreScanView(french: french, recentFilesEnabled: $recentFilesEnabled) }
            case .duplicates: SwitchedContent { DuplicateScanView(french: french) }
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
            case .apps: SwitchedContent { ApplicationsView(french: french) }
            case .startup: SwitchedContent { IntegrityView(french: french) }
            }
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
