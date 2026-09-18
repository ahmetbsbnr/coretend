// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// What starts automatically when you log in, and whether it still can.
///
/// Lived on the Performance screen, where it was the one non-temporal thing
/// among live charts. A launch agent whose program has vanished is not a
/// performance fact; it is a trust fact — something claims to run at login
/// and nothing is there — which is why it sits beside code signing now.
struct StartupItemsView: View {
    @State private var agents: [LaunchAgentInfo] = []

    var body: some View {
        Group {
            if agents.isEmpty {
                MCEmptyState(icon: "power",
                             title: L("startup.empty_title"),
                             message: L("startup.empty_message"))
            } else {
                List(agents) { agent in
                    HStack(spacing: MCSpacing.sm) {
                        Image(systemName: agent.broken ? "exclamationmark.triangle.fill" : "checkmark.circle")
                            .foregroundStyle(agent.broken ? MCTheme.warning : MCTheme.success)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(agent.label).font(MCFont.rowTitle)
                            if let program = agent.programPath {
                                Text(agent.broken ? L("performance.launchagents.missing", program) : program)
                                    .font(MCFont.caption).foregroundStyle(MCColor.textSecondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: agent.id)])
                        } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(L("common.reveal_in_finder"))
                    }
                    .accessibilityElement(children: .combine)
                }
                .listStyle(.inset)
            }
        }
        .onAppear { agents = LaunchAgentInspector.userAgents() }
    }
}
