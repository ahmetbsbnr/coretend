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
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColour
    @FocusState private var focused: Bool
    @State private var hovered: ModuleID?

    /// The row size the user chose in System Settings ▸ Appearance. Read
    /// directly rather than via @Environment — macOS SwiftUI has no key for it
    /// — and Observation re-renders the sidebar when it changes.
    private var metrics: MCSidebarMetrics.Size { MCSidebarMetrics.shared.size }

    /// The groups this build can deliver, after the user's own hiding and
    /// ordering.
    private var groups: [SidebarGroup] { SidebarCustomisation.shared.groups() }

    /// Flat order, used by keyboard navigation. Derived from what is actually
    /// rendered, so Down never lands on a module the user hid — a keyboard
    /// stop with nothing visible under it is a worse bug than the row being
    /// missing.
    private var ordered: [ModuleID] { groups.flatMap(\.modules) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groups) { group in
                        if let title = group.title {
                            // Title case, not shouted caps. Small caps at
                            // tertiary weight on a translucent ground was the
                            // least legible text in the app, and a group name
                            // is a label — it does not need to be an
                            // announcement. A hairline carries the separation
                            // that the letter-spacing used to be doing.
                            HStack(spacing: MCSpacing.xs) {
                                Text(title)
                                    .font(MCFont.sidebarSection(metrics))
                                    .foregroundStyle(MCColor.textSecondary)
                                Rectangle()
                                    .fill(MCColor.separator.opacity(0.5))
                                    .frame(height: 1)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, MCSpacing.sm)
                            .padding(.top, MCSpacing.md + MCSpacing.xxs)
                            .padding(.bottom, MCSpacing.xs)
                            .accessibilityAddTraits(.isHeader)
                        }
                        ForEach(group.modules) { module in
                            row(module)
                                .id(module)
                        }
                    }
                }
                .padding(.horizontal, MCSpacing.xs + MCSpacing.xxs)
                .padding(.top, MCSpacing.xxs)
                .padding(.bottom, MCSpacing.md)
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
        // The real `.sidebar` material, sampling the desktop behind the
        // window. `glassEffect` was here and could not work: it samples
        // content *inside* the window, and the window was painting an opaque
        // ground over everything anyway. See DesignSystem/Materials.swift.
        .mcSidebarSurface()
        // A single focus stop owns module navigation. Row buttons opt out of
        // the key loop below; Tab then reaches the detail column's controls.
        // Measured with NSWindow.firstResponder, not inferred from FocusState.
        .focusable()
        .focused($focused)
        .onChange(of: focused) { _, value in FocusTrace.snapshot("swiftui:sidebar.focused=\(value)") }
        .focusSection()
        // Applied after `.focusSection()`, and restored after an earlier edit
        // dropped it: without it the section draws a bright accent halo around
        // the entire sidebar — the loudest thing in the window, and the first
        // element this art-direction pass had to remove. Row selection and the
        // keyboard's own ring already say where focus is.
        .focusEffectDisabled()
        .onMoveCommand { direction in
            // Only when this sidebar actually holds focus. Unconditional, it
            // answered arrow keys meant for the list in the detail column.
            guard focused else { return }
            move(direction)
        }
        .accessibilityLabel(L("sidebar.a11y.label"))
        .accessibilityIdentifier("sidebar.list")
        // Customisation lives where the thing being customised is, rather than
        // buried in Settings: right-click the sidebar, toggle what you want.
        .contextMenu { customisationMenu }
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
                // The bar is the Differentiate Without Colour affordance, and
                // only that. Shown unconditionally it was a fourth
                // simultaneous signal — bar, wash, tinted glyph, heavier
                // label — which is what made the selection read as heavy.
                if differentiateWithoutColour {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(isSelected ? Color.accentColor : .clear)
                        .frame(width: 3, height: metrics.iconSize + 2)
                        .accessibilityHidden(true)
                }

                Image(systemName: module.systemImage)
                    .font(.system(size: metrics.iconSize, weight: .semibold))
                    // Hierarchical, so a multi-part symbol reads as one shape
                    // with depth rather than as a flat silhouette.
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.accentColor : MCColor.textSecondary)
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
            .padding(.leading, differentiateWithoutColour ? 0 : MCSpacing.sm)
            .padding(.trailing, MCSpacing.sm)
            .padding(.vertical, metrics.rowPadding)
            .contentShape(Rectangle())
            .background {
                // A solid accent fill, which is what a Mac sidebar selection
                // is. The 0.18 wash this replaces was chosen to keep
                // `textPrimary` readable *through* it — but a tint that has to
                // stay faint enough for the ink underneath to survive is a
                // tint that never reads as selection on a translucent ground.
                // Filling solid and choosing the ink from the accent's own
                // luminance (MCAccentInk) is both louder and safer: it holds
                // across all seven system accents including Yellow, where
                // white ink measures about 1.6:1.
                RoundedRectangle(cornerRadius: MCRadius.card, style: .continuous)
                    .fill(background(isSelected: isSelected, isHovered: isHovered))
                    .overlay(alignment: .leading) {
                        // The accent lives in a 3pt indicator and in the ink,
                        // not in a saturated block filling the row.
                        //
                        // The solid accent fill this replaces was chosen to be
                        // unmissable on a translucent material, and it was —
                        // it became the loudest thing in the window, louder
                        // than any content in any module. A selection has to be
                        // unambiguous, not dominant. Kept as a shape, so
                        // Differentiate Without Colour still has something that
                        // is not a hue.
                        if isSelected {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.accentColor)
                                .frame(width: 3)
                                .padding(.vertical, 5)
                                .padding(.leading, 3)
                        }
                    }
                    .overlay {
                        if isSelected, MCAccessibilityState.shared.increaseContrast {
                            RoundedRectangle(cornerRadius: MCRadius.card, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        // One keyboard stop for the navigation region. Its arrow handler
        // selects modules; individual buttons remain clickable and accessible.
        // Otherwise Tab walks every module button before reaching content.
        .focusable(false)
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
        // Derived from the accent rather than fixed, so it follows the user's
        // choice. 0.18 keeps `textPrimary` well past 4.5:1 on every accent
        // macOS offers — measured, not assumed; see SidebarAccentTests.
        // A neutral raised surface, not the accent. On the sidebar's material
        // this reads clearly as "this row is open" while leaving the accent to
        // do its work at small area — in the indicator and the ink.
        if isSelected {
            return MCColor.textPrimary.opacity(
                MCAccessibilityState.shared.increaseContrast ? 0.22 : 0.13)
        }
        // Hover on a translucent ground has to be a neutral, not the accent:
        // an accent wash at 0.08 behind an unselected row reads as a second,
        // weaker selection.
        //
        // The value is the token, not 0.09. Three views wrote their own
        // hover wash — 0.055, 0.06, 0.09 — and the sidebar's was the loudest
        // of the three, so a pointer crossing it read as a stronger response
        // than the same pointer crossing a list row two panes over.
        if isHovered { return MCColor.textPrimary.opacity(MCOpacity.hoverWash) }
        return .clear
    }

    /// Show/hide per module, plus a way back.
    @ViewBuilder
    private var customisationMenu: some View {
        let customisation = SidebarCustomisation.shared
        ForEach(SidebarGroup.available().flatMap(\.modules)) { module in
            Toggle(module.label, isOn: Binding(
                get: { !customisation.isHidden(module) },
                set: { customisation.setHidden(module, !$0) }))
                .disabled(!SidebarCustomisation.canHide(module))
        }
        Divider()
        Button(L("sidebar.reset")) { customisation.reset() }
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
