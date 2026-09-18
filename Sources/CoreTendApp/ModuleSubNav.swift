// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// The one and only way a module splits itself into sub-sections.
///
/// Before this existed, the same concept was rendered three different ways:
/// floating pills from a `TabView` (Applications), a segmented control pinned
/// under the title bar (Protection, My Clutter), and nothing at all everywhere
/// else. Users had to learn three grammars for one idea.
///
/// `TabView` is additionally unsafe here: as the detail of a
/// `NavigationSplitView` it can blank the split view's sidebar on macOS — the
/// defect reported against 1.0.1 and reproduced on the published build.
/// `ModuleSubNavContractTests` fails the build if a `TabView` reappears.
///
/// The pinned segmented control is the surviving idiom because it reads as part
/// of the window chrome rather than as content, and it does not disturb the
/// split view.
struct ModuleSubNav<Content: View>: View {
    /// One selectable section. `label` is already localized.
    struct Section: Identifiable {
        let id: Int
        let label: String

        init(_ id: Int, _ label: String) {
            self.id = id
            self.label = label
        }
    }

    let sections: [Section]
    @Binding var selection: Int
    @ViewBuilder let content: (Int) -> Content

    /// Matches the width the three call sites had converged on independently.
    private let controlWidth: CGFloat = 360

    // A VStack, not `.safeAreaInset(edge: .top)`. The inset variant is what the
    // two earlier hand-rolled sub-navs used, and it works only as long as the
    // content honours the safe area. `InstalledAppsView` is an `HSplitView`,
    // which does not: moving Applications onto an inset-based sub-nav hid its
    // search field behind the bar. Stacking is unconditional and cannot
    // overlap anything, at the cost of the bar not being translucent over
    // scrolled content — a trade worth making for a chrome element that is
    // pinned anyway.
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Picker("", selection: $selection) {
                    ForEach(sections) { section in
                        Text(section.label).tag(section.id)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: controlWidth)
                .padding(.vertical, MCSpacing.sm)
                Divider()
            }
            .frame(maxWidth: .infinity)
            // Navigation layer, so this is one of the two places Liquid Glass
            // belongs. A rectangle rather than a rounded shape: the bar meets
            // both window edges, and a floating pill here would be a second
            // floating element competing with the sidebar.
            .mcNavigationGlass(in: Rectangle(), fallback: MCColor.secondaryBackground)
            .accessibilityIdentifier("module.subnav")

            content(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
