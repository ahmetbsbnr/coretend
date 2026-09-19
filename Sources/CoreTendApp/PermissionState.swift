// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// What a module shows when macOS has not granted it what it needs.
///
/// Every scanning module could return nothing for the same reason — no Full
/// Disk Access — and each one said something different about it, or nothing at
/// all: an empty list that looks like a clean Mac. A refused permission is a
/// state with an explanation, a way to grant it, and a way to carry on
/// without, because a limited scan is still a scan.
///
/// See docs/DESIGN_SYSTEM.md § States.
struct MCPermissionState: View {
    let title: String
    let explanation: String
    /// What the module can still do without the grant. Omitted when it can do
    /// nothing, so "Continue anyway" is never offered for a screen that would
    /// then be empty.
    let limitation: String?
    let onContinue: (() -> Void)?

    init(title: String, explanation: String, limitation: String? = nil,
         onContinue: (() -> Void)? = nil) {
        self.title = title
        self.explanation = explanation
        self.limitation = limitation
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: MCSpacing.sm) {
            Image(systemName: "lock")
                .font(.system(size: MCIconSize.compactState, weight: .thin))
                .foregroundStyle(MCColor.textTertiary)
                .accessibilityHidden(true)
            Text(title).font(MCFont.cardTitle)
            Text(explanation)
                .font(MCFont.body).foregroundStyle(MCColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let limitation {
                Text(limitation)
                    .font(MCFont.caption).foregroundStyle(MCColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            HStack(spacing: MCSpacing.sm) {
                Button(L("settings.open_system_settings")) {
                    if let url = SystemAuthorization.fullDiskAccessSettingsURL {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                if let onContinue {
                    Button(L("permission.continue_without"), action: onContinue)
                        .buttonStyle(.bordered)
                }
            }
            .padding(.top, MCSpacing.xxs)
        }
        .padding(MCSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(explanation)")
    }
}
