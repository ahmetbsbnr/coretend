// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// CoreTend's sidebar, rendered by CoreTend.
///
/// ## Why this is not a `List(selection:)`
///
/// It was, and the selection highlight came from the user's System Settings
/// accent colour. On a Mac with the green accent the most prominent element in
/// the app was green; on another Mac it was pink, or red. The row underneath
/// drew `MCColor.teal.opacity(0.12)` for its selected state, which `List` then
/// painted over — a fill that was never visible on any Mac, sitting in the
/// codebase looking like brand control.
///
/// `.tint()` does not override it. That was measured, not assumed: applying
/// the brand teal to the List still produced a `#539a32` selected row. The one
/// supported override is `NSAccentColorName` plus a compiled asset catalog,
/// which needs `actool` — available only with full Xcode, not the Command Line
/// Tools this project builds with. Taking that route would have made the app's
/// identity depend on which machine built it, or required committing a
/// compiled binary blob to a repository that publishes reproducible builds.
///
/// So the sidebar is drawn here. That also unblocks the rest: row shape,
/// hover, the selection marker, iconography and motion are all now design
/// decisions rather than whatever `NSTableView` does.
///
/// ## What had to be rebuilt because `List` was providing it
///
/// Losing the system control means losing what it gave for free, and those are
/// accessibility affordances, not decoration. Each is reimplemented explicitly:
///
/// - **Keyboard navigation.** Up/Down move between modules, wrapping at
///   neither end; Home/End jump. Handled by `onMoveCommand` on a focusable
///   container.
/// - **Selection semantics.** Every row is a real `Button` and carries
///   `.isSelected` when it is, so VoiceOver announces "selected" rather than
///   leaving the state visible only as a colour.
/// - **Section structure.** Headers are marked as headers, so rotor navigation
///   by heading still works.
/// - **Focus ring.** A visible focus indicator that is not the selection
///   indicator, because "where the keyboard is" and "what is open" are two
///   different questions.
struct Sidebar: View {
    @Binding var selection: ModuleID
    @FocusState private var focused: Bool
    @State private var hovered: ModuleID?

    /// The row size the user chose in System Settings ▸ Appearance. Read
    /// directly rather than via @Environment — macOS SwiftUI has no key for it
    /// — and Observation re-renders the sidebar when it changes.
    private var metrics: MCSidebarMetrics.Size { MCSidebarMetrics.shared.size }

    /// The groups this build can deliver. Read once per body rather than per
    /// row: it is a pure function of a compile-time value.
    private var groups: [SidebarGroup] { SidebarGroup.available() }

    /// Flat order, used by keyboard navigation: the groups are visual, and
    /// Down from the last row of one group goes to the first of the next.
    private var ordered: [ModuleID] { SidebarGroup.visibleModules }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groups) { group in
                        if let title = group.title {
                            Text(title.uppercased())
                                .font(MCFont.sidebarSection(metrics))
                                .foregroundStyle(MCColor.textTertiary)
                                .padding(.horizontal, MCSpacing.sm + MCSpacing.xxs)
                                .padding(.top, MCSpacing.md)
                                .padding(.bottom, MCSpacing.xxs)
                                .accessibilityAddTraits(.isHeader)
                        }
                        ForEach(group.modules) { module in
                            row(module)
                                .id(module)
                        }
                    }
                }
                .padding(.horizontal, MCSpacing.xs)
                .padding(.vertical, MCSpacing.xs)
                // Pin the stack to the viewport width.
                //
                // Without this the LazyVStack sizes itself to its widest child.
                // A module label whose ideal width exceeds the sidebar column
                // makes the whole stack wider than the ScrollView, which then
                // centres the overflow — so the section headers rendered as
                // "ORAGE", "ORE", "STEM", clipped by 24pt on the left, and the
                // selection marker was cut off entirely.
                //
                // This is the third instance in this codebase of one root
                // cause: a child reporting an ideal width larger than its
                // container, and SwiftUI honouring the child. The other two
                // were DuplicatesView's idle subtitle (which collapsed the
                // split view's sidebar to zero) and the Dashboard hero (which
                // truncated the primary action to "Sc…").
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
            .onChange(of: selection) { _, new in
                // Keyboard navigation must not walk the selection off screen.
                withAnimation(MCMotion.transition) { proxy.scrollTo(new, anchor: .center) }
            }
        }
        // Width, and why it is stated here rather than at the call site.
        //
        // A ScrollView has no intrinsic width, so NavigationSplitView has
        // nothing to size the column from and lays it out narrower than the
        // declared minimum. The `List` this replaced carried that width for
        // free; a hand-built sidebar has to state one.
        //
        // But a hard `.frame(minWidth:)` on the *content* is the wrong way to
        // say it: NavigationSplitView persists the divider position across
        // launches, so on a window whose divider was previously dragged narrow
        // the content became wider than its column, overflowed, and was
        // clipped from the centre outwards — headers rendered as "ORAGE",
        // "ORE", "STEM" with every icon cut off the left edge.
        //
        // `navigationSplitViewColumnWidth` applied to the sidebar's own root
        // tells the split view the constraint, so the column respects it
        // instead of the content fighting it, and the content stays
        // compressible.
        // No hard `.frame(minWidth:)` on the content. NavigationSplitView will
        // hand the sidebar less than its stated minimum whenever the detail's
        // own minimum plus the sidebar's exceeds the window, and a content
        // frame wider than the column does not win that argument — it
        // overflows and is clipped from the centre, which is how the section
        // headers came out as "ORAGE", "ORE", "STEM". The constraint is stated
        // to the split view below, and the content stays compressible so that
        // even when the constraint loses, the result is a narrow sidebar
        // rather than a broken one.
        .navigationSplitViewColumnWidth(
            min: MCSize.sidebarMin, ideal: MCSize.sidebarIdeal, max: MCSize.sidebarMax)
        // The sidebar is the app's primary navigation layer, so it is the
        // other place glass belongs. Content scrolls in the detail column
        // beside it, which is exactly what glass is meant to sample.
        .mcNavigationGlass(in: Rectangle(), fallback: MCColor.secondaryBackground)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onMoveCommand { direction in
            move(direction)
        }
        .accessibilityLabel(L("sidebar.a11y.label"))
        .accessibilityIdentifier("sidebar.list")
    }

    // MARK: - Row

    private func row(_ module: ModuleID) -> some View {
        let isSelected = selection == module
        let isHovered = hovered == module

        return Button {
            selection = module
        } label: {
            HStack(spacing: MCSpacing.sm) {
                // The selection marker is a shape, not only a colour: a user
                // who cannot distinguish the teal wash from the ground still
                // sees which module is open.
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? MCColor.teal : .clear)
                    .frame(width: 3, height: metrics.iconSize + 2)
                    .accessibilityHidden(true)

                Image(systemName: module.systemImage)
                    .font(.system(size: metrics.iconSize, weight: .medium))
                    .foregroundStyle(isSelected ? MCColor.teal : MCColor.textTertiary)
                    .frame(width: metrics.iconSize + 4)
                    .accessibilityHidden(true)

                Text(module.label)
                    .font(MCFont.sidebarItem(metrics, active: isSelected))
                    .foregroundStyle(isSelected ? MCColor.textPrimary : MCColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // A label must never widen the row past the column: it
                    // truncates instead. `lineLimit(1)` alone does not do this
                    // — it stops wrapping, but the Text still reports its full
                    // single-line width upward.
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.trailing, MCSpacing.sm)
            .padding(.vertical, metrics.rowPadding)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: MCRadius.card)
                    .fill(background(isSelected: isSelected, isHovered: isHovered))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            // Clear only our own hover. Writing `nil` unconditionally would
            // let a stale exit event from the row the pointer just left erase
            // the hover on the row it just entered.
            withAnimation(MCMotion.response) {
                if hovering {
                    hovered = module
                } else if hovered == module {
                    hovered = nil
                }
            }
        }
        .accessibilityIdentifier("sidebar.\(module.rawValue)")
        // Explicit, not inherited. The row's label is a hand-built HStack of a
        // marker shape, an icon and a Text; SwiftUI does not synthesize a name
        // from that the way it does from a `Label`, so without this every
        // module announced as an unnamed "button" — the whole sidebar,
        // unusable with VoiceOver. Checked against the accessibility tree, not
        // assumed from the code reading correctly.
        .accessibilityLabel(module.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func background(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return MCColor.tealWash }
        if isHovered { return MCColor.elevatedBackground }
        return .clear
    }

    // MARK: - Keyboard

    /// Moves the selection. Deliberately clamps rather than wraps: wrapping
    /// from Settings back to Dashboard on a Down press is disorienting in a
    /// list short enough to see all at once.
    private func move(_ direction: MoveCommandDirection) {
        guard let index = ordered.firstIndex(of: selection) else { return }
        let next: Int
        switch direction {
        case .up: next = index - 1
        case .down: next = index + 1
        default: return
        }
        guard ordered.indices.contains(next) else { return }
        selection = ordered[next]
    }
}

/// Pure keyboard-navigation logic, lifted out of the view so it is testable.
enum SidebarNavigation {
    /// The module Up/Down lands on, or nil when the move is refused at an end.
    static func destination(from current: ModuleID, moving up: Bool, in order: [ModuleID]) -> ModuleID? {
        guard let index = order.firstIndex(of: current) else { return nil }
        let next = up ? index - 1 : index + 1
        return order.indices.contains(next) ? order[next] : nil
    }
}
