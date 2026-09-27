import DesignSystem
import SwiftUI
import AppShell

struct CommandPaletteView: View {
    let french: Bool
    let select: (CommandTarget) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool
    @State private var query = ""
    @State private var selectedID: String?

    private var commands: [ProductCommand] { CommandPaletteCatalog.search(query, french: french) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                SerreIcon(.search, size: 16)
                    .foregroundStyle(Palette.secondaryInk.color)
                    .accessibilityHidden(true)
                TextField(ProductCopy.value(for: "command.palette.search", french: french), text: $query)
                    .textFieldStyle(.plain)
                    .font(CoreTendTypography.body)
                    .focused($searchFocused)
                    // The focused field editor consumes arrow keys, so `onMoveCommand` below never sees them.
                    .onKeyPress(.upArrow) { moveSelection(.up) }
                    .onKeyPress(.downArrow) { moveSelection(.down) }
                    .onSubmit {
                        if let command = commands.first(where: { $0.id == selectedID }) ?? commands.first { activate(command) }
                    }
            }
            .padding(12)
            .background(Palette.raisedSurface.color, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.focus.color, lineWidth: 1))
            .padding(16)
            Palette.separator.color.frame(height: 1)
            if commands.isEmpty {
                ContentUnavailableView(ProductCopy.value(for: "command.palette.empty", french: french),
                                       systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(commands) { command in
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
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .motion(.quick, value: selectedID)
                    .onChange(of: selectedID) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
            }
            Palette.separator.color.frame(height: 1)
            HStack {
                Text(french ? "↑ ↓ pour choisir · Retour ouvre · esc ferme" : "↑ ↓ to select · Return to open · esc to close")
                    .font(CoreTendTypography.secondary).foregroundStyle(Palette.secondaryInk.color)
                Spacer()
                Text("esc").font(CoreTendTypography.secondary.monospaced()).foregroundStyle(Palette.secondaryInk.color)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 520, height: 480)
        .background(Palette.surface.color)
        .task {
            selectedID = commands.first?.id
            searchFocused = true
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
        .onExitCommand { dismiss() }
    }

    private func moveSelection(_ direction: CommandMoveDirection) -> KeyPress.Result {
        selectedID = CommandPaletteNavigation.move(in: commands, selectedID: selectedID, direction: direction)
        return .handled
    }

    private func activate(_ command: ProductCommand) {
        select(command.target)
        if command.target != .settings { dismiss() }
    }

    private func glyph(for target: CommandTarget) -> SerreGlyph {
        switch target {
        case .destination(let destination): destination.glyph
        case .settings: .settings
        }
    }
}
