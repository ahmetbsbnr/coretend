import DesignSystem
import SwiftUI
import AppShell

/// The command palette's content: field, results and hint. SearchLayer presents it over the
/// window; its keyboard logic (arrows, Return, Escape) is unchanged from the sheet it replaced.
struct CommandPaletteView: View {
    let french: Bool
    let select: (CommandTarget) -> Void
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool
    @State private var query = ""
    @State private var selectedID: String?
    /// Results sprout once, when the palette opens.
    @State private var sprouted = false

    private var commands: [ProductCommand] { CommandPaletteCatalog.search(query, french: french) }

    var body: some View {
        VStack(spacing: 0) {
            field
                .padding(16)
            Palette.separator.color.frame(height: 1)
            if commands.isEmpty {
                WiltedResult(french: french)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                                row(command)
                                    .id(command.id)
                                    .opacity(sprouted ? 1 : 0)
                                    .offset(y: sprouted ? 0 : 8)
                                    .animation(reduceMotion ? nil : MotionCurve.sprout.animation(duration: 0.32)
                                        .delay(Double(min(index, 8)) * 0.035), value: sprouted)
                            }
                        }
                        .padding(8)
                    }
                    .motion(.quick, value: selectedID)
                    .onChange(of: selectedID) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
            }
            Palette.separator.color.frame(height: 1)
            HStack {
                Text(french ? "↑ ↓ pour choisir · Retour ouvre · esc ou clic dehors ferme" : "↑ ↓ to select · Return to open · esc or click outside to close")
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 540, height: 460)
        .task {
            selectedID = commands.first?.id
            searchFocused = true
            sprouted = true
        }
        .onChange(of: commands.map(\.id)) { _, ids in
            if selectedID.map(ids.contains) != true { selectedID = ids.first }
        }
        .onMoveCommand { direction in
            switch direction {
            case .up: _ = moveSelection(.up)
            case .down: _ = moveSelection(.down)
            default: break
            }
        }
        .onExitCommand { close() }
    }

    private var field: some View {
        let shape = LeafCorner.control.shape
        return HStack(spacing: 10) {
            SerreIcon(.search, size: 16)
                .foregroundStyle(Palette.accent.color)
                .accessibilityHidden(true)
            TextField(ProductCopy.value(for: "command.palette.search", french: french), text: $query)
                .textFieldStyle(.plain)
                .font(CoreTendTypography.body)
                .focused($searchFocused)
                // The focused field editor consumes arrow keys, so `onMoveCommand` below never sees them.
                .onKeyPress(.upArrow) { moveSelection(.up) }
                .onKeyPress(.downArrow) { moveSelection(.down) }
                .onKeyPress(.escape) { close(); return .handled }
                .onSubmit {
                    if let command = commands.first(where: { $0.id == selectedID }) ?? commands.first { activate(command) }
                }
        }
        .padding(12)
        .background(Palette.surface.color, in: shape)
        .overlay(shape.strokeBorder(Palette.accent.color, lineWidth: 1))
        .overlay(alignment: .bottom) {
            // The root grows with what is typed.
            SearchRoot(progress: SearchRoot.progress(forQueryLength: query.count))
                .stroke(Palette.accent.color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(height: 12)
                .padding(.horizontal, 14)
                .offset(y: 9)
                .animation(reduceMotion ? nil : MotionCurve.sap.animation(duration: MotionToken.standard.duration), value: query.count)
                .accessibilityHidden(true)
        }
    }

    private func row(_ command: ProductCommand) -> some View {
        Button {
            selectedID = command.id
            activate(command)
        } label: {
            Label { Text(command.title) } icon: { SerreIcon(glyph(for: command.target)).foregroundStyle(Palette.accent.color) }
                .font(CoreTendTypography.body)
                .foregroundStyle(Palette.ink.color)
                .frame(minHeight: 22)
        }
        .buttonStyle(.serre(.row(selected: selectedID == command.id)))
        .accessibilityValue(selectedID == command.id ? (french ? "Sélectionné" : "Selected") : "")
    }

    private func moveSelection(_ direction: CommandMoveDirection) -> KeyPress.Result {
        selectedID = CommandPaletteNavigation.move(in: commands, selectedID: selectedID, direction: direction)
        return .handled
    }

    private func activate(_ command: ProductCommand) {
        close()
        select(command.target)
    }

    private func glyph(for target: CommandTarget) -> SerreGlyph {
        switch target {
        case .destination(let destination): destination.glyph
        case .settings: .settings
        }
    }
}

/// No result: a sprout that wilts once, with a plain sentence.
private struct WiltedResult: View {
    let french: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wilted = false

    var body: some View {
        VStack(spacing: 12) {
            SerreIcon(.overview, size: 44)
                .foregroundStyle(Palette.tertiaryInk.color)
                .rotationEffect(.degrees(wilted ? 14 : 0), anchor: .bottom)
                .opacity(wilted ? 0.7 : 1)
            Text(ProductCopy.value(for: "command.palette.empty", french: french))
                .font(CoreTendTypography.body).foregroundStyle(Palette.secondaryInk.color)
        }
        .onAppear {
            if reduceMotion { wilted = true } else {
                withAnimation(MotionCurve.retreat.animation(duration: 0.3)) { wilted = true }
            }
        }
    }
}

/// The palette over the whole window. It opens out of the sidebar's Search button (the box
/// starts at the button's frame and grows to its own); a click anywhere outside the box, Escape,
/// Cmd-K or choosing a result closes it. Under Reduce Motion it appears and leaves at once.
struct SearchLayer: View {
    let french: Bool
    let namespace: Namespace.ID
    let select: (CommandTarget) -> Void
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// While true, the box takes the Search button's frame.
    @State private var attached = true
    @State private var contentShown = false

    var body: some View {
        let shape = LeafCorner.sheet.shape
        ZStack(alignment: .top) {
            SerreScrim()
                .onTapGesture(perform: close)
                .accessibilityElement()
                .accessibilityLabel(french ? "Fermer la recherche" : "Close search")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { close() }
            CommandPaletteView(french: french, select: select, close: close)
                .opacity(contentShown ? 1 : 0)
                .background(Palette.raisedSurface.color, in: shape)
                .clipShape(shape)
                .overlay(shape.strokeBorder(Palette.separator.color, lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 30, y: 16)
                .matchedGeometryEffect(id: attached ? "search.button" : "search.open", in: namespace, properties: .frame, isSource: false)
                .padding(.top, 72)
        }
        .tint(Palette.accent.color)
        .buttonStyle(.serre(.secondary))
        .onAppear {
            guard !reduceMotion else { attached = false; contentShown = true; return }
            withAnimation(MotionCurve.sap.animation(duration: MotionToken.standard.duration)) { attached = false }
            withAnimation(MotionCurve.sap.animation(duration: 0.16).delay(0.14)) { contentShown = true }
        }
    }
}
