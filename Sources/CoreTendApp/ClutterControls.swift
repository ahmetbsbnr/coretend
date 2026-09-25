// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// Small shared search field used by My Clutter's three sub-views. Filters
/// results in place — never triggers a re-scan.
struct MCSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: MCSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary).accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(MCFont.secondaryBody)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(L("common.clear"))
            }
        }
        .padding(.horizontal, MCSpacing.xs)
        .frame(width: 220, height: 26)
        .background(MCColor.elevatedBackground, in: RoundedRectangle(cornerRadius: MCRadius.control))
        .overlay(RoundedRectangle(cornerRadius: MCRadius.control).strokeBorder(MCColor.separator, lineWidth: 1))
        .accessibilityLabel(placeholder)
    }
}

/// Reveals current exclusions (from the same Store `Settings` uses) and lets
/// the user remove one. Adding is done per-row via `excludeButton(for:)`
/// below, right next to the file that's being excluded.
struct ExclusionsMenu: View {
    let controller: ClutterExclusionsController

    var body: some View {
        Menu {
            if controller.exclusions.isEmpty {
                Text(L("clutter.exclusions_empty")).foregroundStyle(.secondary)
            } else {
                ForEach(controller.exclusions, id: \.self) { path in
                    Button {
                        controller.remove(path)
                    } label: {
                        Label(path, systemImage: "minus.circle")
                    }
                }
                Divider()
                Text(L("clutter.exclusions_rescan_note")).foregroundStyle(.secondary)
            }
        } label: {
            Label(L("clutter.exclusions_count", controller.exclusions.count), systemImage: "eye.slash")
        }
        .task { await controller.load() }
    }
}

/// Per-row "exclude this file / exclude its folder" control, shared by
/// Large & Old, Duplicates, and Similar Images rows.
struct ExcludeButton: View {
    let url: URL
    let controller: ClutterExclusionsController

    var body: some View {
        if controller.isExcluded(url) {
            Image(systemName: "eye.slash.fill")
                .foregroundStyle(.secondary)
                .help(L("clutter.already_excluded"))
                .accessibilityLabel(L("clutter.already_excluded"))
        } else {
            Menu {
                Button(L("clutter.exclude_file")) { controller.exclude(url, asFolder: false) }
                Button(L("clutter.exclude_folder")) { controller.exclude(url, asFolder: true) }
            } label: {
                Image(systemName: "eye.slash")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
            .help(L("clutter.exclude_menu"))
            .accessibilityLabel(L("clutter.exclude_menu"))
        }
    }
}
