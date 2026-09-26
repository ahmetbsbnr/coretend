import SwiftUI
import AppShell

struct CommandPaletteView: View {
    let french: Bool
    let select: (CommandTarget) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool
    @State private var query = ""

    private var commands: [ProductCommand] { CommandPaletteCatalog.search(query, french: french) }

    var body: some View {
        VStack(spacing: 0) {
            TextField(ProductCopy.value(for: "command.palette.search", french: french), text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(16)
                .focused($searchFocused)
                .onSubmit { if let command = commands.first { activate(command) } }
            Divider()
            if commands.isEmpty {
                ContentUnavailableView(ProductCopy.value(for: "command.palette.empty", french: french),
                                       systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(commands) { command in
                    Button { activate(command) } label: {
                        Label(command.title, systemImage: symbol(for: command.target))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isButton)
                }
                .listStyle(.plain)
            }
            Divider()
            HStack {
                Text(french ? "Saisissez pour filtrer · Retour ouvre le premier résultat · esc ferme" : "Type to filter · Return opens first result · esc closes")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("esc").font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 520, height: 480)
        .task { searchFocused = true }
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
