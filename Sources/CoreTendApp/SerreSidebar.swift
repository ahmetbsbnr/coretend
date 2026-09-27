import SwiftUI
import AppShell
import DesignSystem

/// Where each destination's row sits in the window, so the content can grow from the row that
/// was chosen (UI guide § 8, "changement de destination").
struct SidebarRowFrames: PreferenceKey {
    static let defaultValue: [Destination: CGRect] = [:]
    static func reduce(value: inout [Destination: CGRect], nextValue: () -> [Destination: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The Serre sidebar, drawn by CoreTend instead of the system list: the germinating logo, two
/// sections, and a leaf marker that glides to the chosen row whatever chose it (click, command
/// palette, ⌘1…⌘8, arrow keys, menu bar). A vine then draws from the marker to the content edge
/// and fades; nothing moves at rest.
struct SerreSidebar: View {
    @Binding var selection: Destination?
    let french: Bool
    let openSearch: () -> Void
    let openSettings: () -> Void

    @Namespace private var markerSpace
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vine = 0.0
    @State private var vineOpacity = 0.0

    private let sections: [(key: String, destinations: [Destination])] = [
        ("sidebar.yourMac", Array(Destination.sidebarOrder.prefix(4))),
        ("sidebar.understand", Array(Destination.sidebarOrder.suffix(4))),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            brand
            searchButton
            ForEach(sections, id: \.key) { section in
                Text(ProductCopy.value(for: section.key, french: french))
                    .font(CoreTendTypography.caption.weight(.semibold))
                    .foregroundStyle(Palette.tertiaryInk.color)
                    .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 4)
                ForEach(section.destinations) { destination in row(destination) }
            }
            Spacer(minLength: 12)
            Button(action: openSettings) {
                Label { Text(ProductCopy.value(for: "settings.title", french: french)) } icon: { SerreIcon(.settings) }
                    .font(CoreTendTypography.body)
                    .foregroundStyle(Palette.secondaryInk.color)
            }
            .buttonStyle(.serre(.row(selected: false)))
            .environment(\.serreFocusRing, false)
            .accessibilityLabel(ProductCopy.value(for: "settings.title", french: french))
        }
        .padding(.horizontal, 10).padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.sidebar.color.ignoresSafeArea())
        .overlayPreferenceValue(SidebarRowFrames.self) { frames in vineOverlay(frames) }
        .animation(reduceMotion ? nil : MotionCurve.sprout.animation(duration: 0.38), value: selection)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.downArrow) { move(1) }
        .onKeyPress(.upArrow) { move(-1) }
        .onChange(of: selection) { _, _ in growVine() }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            SerreLogo(size: 32, germinates: true)
            VStack(alignment: .leading, spacing: 0) {
                Text("CoreTend").font(.custom("IowanOldStyle-Bold", size: 20, relativeTo: .title3)).foregroundStyle(Palette.ink.color)
                Text(french ? "entretien local" : "local care").font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
            }
        }
        .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }

    /// The command palette opens from here (it will grow out of this button: batch 2.4b).
    private var searchButton: some View {
        Button(action: openSearch) {
            HStack(spacing: 9) {
                SerreIcon(.search, size: 16)
                Text(french ? "Rechercher" : "Search").font(CoreTendTypography.body)
                Spacer(minLength: 4)
                Text("⌘K").font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
            }
            .foregroundStyle(Palette.secondaryInk.color)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.serre(.secondary))
        .keyboardShortcut("k", modifiers: [.command])
        .environment(\.serreFocusRing, false)
        .help(french ? "Accéder à… (⌘K)" : "Go to or open… (⌘K)")
        .accessibilityLabel(ProductCopy.value(for: "command.palette.title", french: french))
        .padding(.horizontal, 2).padding(.bottom, 4)
    }

    private func row(_ destination: Destination) -> some View {
        let selected = selection == destination
        return Button {
            selection = destination
            focused = true
        } label: {
            Label {
                Text(ProductCopy.value(for: destination.titleKey, french: french))
            } icon: {
                SerreIcon(destination.glyph).foregroundStyle(selected ? Palette.accent.color : Palette.secondaryInk.color)
            }
            .font(CoreTendTypography.body.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? Palette.ink.color : Palette.secondaryInk.color)
        }
        .buttonStyle(.serre(.row(selected: false)))
        .environment(\.serreFocusRing, false)
        .background {
            if selected {
                LeafCorner.control.shape
                    .fill(Palette.accent.color.opacity(0.16))
                    // The selection is the sidebar's focus indicator when it has keyboard focus.
                    .overlay { if focused { LeafCorner.control.shape.inset(by: -3).stroke(Palette.focus.color, lineWidth: 2) } }
                    .overlay(alignment: .leading) {
                        Capsule().fill(Palette.accent.color).frame(width: 3).padding(.vertical, 8)
                    }
                    .matchedGeometryEffect(id: "leaf-marker", in: markerSpace)
            }
        }
        .background(GeometryReader { proxy in
            Color.clear.preference(key: SidebarRowFrames.self, value: [destination: proxy.frame(in: .global)])
        })
        .keyboardShortcut(KeyEquivalent(Character(String(destination.shortcutNumber))), modifiers: .command)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// A short vine from the marker to the sidebar's edge, towards the content that grows.
    @ViewBuilder
    private func vineOverlay(_ frames: [Destination: CGRect]) -> some View {
        GeometryReader { proxy in
            if let selection, let row = frames[selection], row != .zero {
                let local = proxy.frame(in: .global)
                let y = row.midY - local.minY
                let start = row.maxX - local.minX
                VeinLine(from: start, to: proxy.size.width, y: y, progress: vine)
                    .stroke(Palette.accent.color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .opacity(vineOpacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func growVine() {
        guard !reduceMotion else { return }
        vine = 0
        vineOpacity = 1
        withAnimation(MotionToken.quick.animation(reduceMotion: false)?.delay(0.2)) { vine = 1 }
        withAnimation(MotionToken.standard.animation(.retreat, reduceMotion: false)?.delay(0.7)) { vineOpacity = 0 }
    }

    private func move(_ offset: Int) -> KeyPress.Result {
        selection = (selection ?? .overview).step(offset)
        return .handled
    }
}

/// A horizontal vine with a slight curl at its end, drawn up to `progress`.
private struct VeinLine: Shape {
    let from: CGFloat
    let to: CGFloat
    let y: CGFloat
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: from, y: y))
        path.addCurve(to: CGPoint(x: to, y: y - 3), control1: CGPoint(x: from + (to - from) * 0.4, y: y + 3), control2: CGPoint(x: from + (to - from) * 0.7, y: y - 5))
        return path.trimmedPath(from: 0, to: progress)
    }
}
