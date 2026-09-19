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
        HStack(spacing: MCSpacing.xxs) {
            Image(systemName: "magnifyingglass").foregroundStyle(MCColor.textSecondary).accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(MCColor.textSecondary)
                .accessibilityLabel(L("common.clear"))
            }
        }
        .padding(.horizontal, MCSpacing.xs).padding(.vertical, MCSpacing.xxs)
        .frame(width: 220)
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
                Text(L("clutter.exclusions_empty")).foregroundStyle(MCColor.textSecondary)
            } else {
                ForEach(controller.exclusions, id: \.self) { path in
                    Button {
                        controller.remove(path)
                    } label: {
                        Label(path, systemImage: "minus.circle")
                    }
                }
                Divider()
                Text(L("clutter.exclusions_rescan_note")).foregroundStyle(MCColor.textSecondary)
            }
        } label: {
            Label(L("clutter.exclusions_count", controller.exclusions.count), systemImage: "eye.slash")
        }
        // A plain Menu here drew the accent-filled pop-up button with its
        // disclosure arrow in a box of its own — a prominent control, in the
        // window's loudest colour, for an inert filter that is usually empty.
        // Bordered and neutral, it reads as what it is.
        .menuStyle(.borderlessButton)
        .buttonStyle(.bordered)
        // Without this the menu takes whatever width is going, which in a
        // filter bar is all of it.
        .fixedSize()
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
                .foregroundStyle(MCColor.textSecondary)
                .help(L("clutter.already_excluded"))
                .accessibilityLabel(L("clutter.already_excluded"))
        } else {
            Menu {
                Button(L("clutter.exclude_file")) { controller.exclude(url, asFolder: false) }
                Button(L("clutter.exclude_folder")) { controller.exclude(url, asFolder: true) }
            } label: {
                Image(systemName: "eye.slash")
                    .frame(width: 22, height: 20)
                    .contentShape(Rectangle())
            }
            // A borderless menu keeps room for a disclosure arrow it is not
            // drawing here; clamped to 20pt that room came out of the glyph,
            // which sat left of centre in a hit area a few points wide. The
            // indicator is hidden and the target is the whole square.
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(L("clutter.exclude_menu"))
            .accessibilityLabel(L("clutter.exclude_menu"))
        }
    }
}
