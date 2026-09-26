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
            TextField(ProductCopy.value(for: "command.palette.search", french: french), text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(16)
                .focused($searchFocused)
            .onSubmit {
                if let command = commands.first(where: { $0.id == selectedID }) ?? commands.first { activate(command) }
            }
            Divider()
            if commands.isEmpty {
                ContentUnavailableView(ProductCopy.value(for: "command.palette.empty", french: french),
                                       systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(commands) { command in
                    Button {
                        selectedID = command.id
                        activate(command)
                    } label: {
                        Label(command.title, systemImage: symbol(for: command.target))
                            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.horizontal, 8)
                            .background(selectedID == command.id ? Color.accentColor.opacity(0.14) : .clear,
                                        in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(selectedID == command.id ? (french ? "Sélectionné" : "Selected") : "")
                }
                .listStyle(.plain)
            }
            Divider()
            HStack {
                Text(french ? "↑ ↓ pour choisir · Retour ouvre · esc ferme" : "↑ ↓ to select · Return to open · esc to close")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("esc").font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 520, height: 480)
        .task {
            selectedID = commands.first?.id
            searchFocused = true
        }
        .onChange(of: commands.map(\.id)) { _, ids in
            if selectedID.map(ids.contains) != true { selectedID = ids.first }
        }
        .onMoveCommand { direction in
            switch direction {
            case .up: selectedID = CommandPaletteNavigation.move(in: commands, selectedID: selectedID, direction: .up)
            case .down: selectedID = CommandPaletteNavigation.move(in: commands, selectedID: selectedID, direction: .down)
            default: break
            }
        }
        .onExitCommand { dismiss() }
    }

    private func activate(_ command: ProductCommand) {
        select(command.target)
        if command.target != .settings { dismiss() }
    }

    private func symbol(for target: CommandTarget) -> String {
        switch target {
        case .destination(let destination): destination.symbol
        case .settings: "gearshape"
        }
    }
}
