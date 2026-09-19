// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// The actions available on a file row, declared once and offered two ways.
///
/// ## Why not just swipe actions
///
/// macOS 27 brought `swipeActions` to the Mac, and it is the right gesture for
/// a long list of files: a two-finger swipe reveals what you can do to a row
/// without three permanent icon buttons crowding every one of them.
///
/// But a swipe is a pointer gesture. Someone navigating by keyboard, using
/// VoiceOver, or driving the Mac with Switch Control cannot perform it, and an
/// action reachable only by swiping is an action those people do not have. So
/// every action here is also in a context menu, which the keyboard reaches with
/// the menu key and VoiceOver surfaces through its own rotor.
///
/// Declaring them once is the point. Two lists that must agree is a pair that
/// eventually disagrees, and the failure is silent: the swipe keeps working
/// while the context menu quietly lacks the action someone needed.
struct FileRowAction: Identifiable {
    enum Tone { case normal, destructive }

    let id: String
    let titleKey: String
    let systemImage: String
    let tone: Tone
    let perform: () -> Void

    init(id: String, titleKey: String, systemImage: String,
         tone: Tone = .normal, perform: @escaping () -> Void) {
        self.id = id
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.tone = tone
        self.perform = perform
    }

    /// Inspecting a file: look at it, or find it on disk.
    ///
    /// Excluding is deliberately *not* here. It carries state the row has to
    /// show — "already excluded" is a different control, not a disabled
    /// action — and it has two variants, this file or its whole folder. That
    /// belongs to `ExcludeButton`, which stays on the row.
    static func inspection(for url: URL,
                           preview: @escaping (URL) -> Void) -> [FileRowAction] {
        [
            FileRowAction(id: "quicklook", titleKey: "clutter.quick_look",
                          systemImage: "eye") { preview(url) },
            FileRowAction(id: "reveal", titleKey: "common.reveal_in_finder",
                          systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            },
        ]
    }
}

extension View {
    /// Attaches a row's actions as both a swipe and a context menu.
    func fileRowActions(_ actions: [FileRowAction]) -> some View {
        modifier(FileRowActionsModifier(actions: actions))
    }
}

private struct FileRowActionsModifier: ViewModifier {
    let actions: [FileRowAction]

    /// Space previews the row, the way it does in Finder.
    ///
    /// Quick Look was reachable by swipe and by context menu — a gesture and a
    /// right-click. Neither is available to someone driving the app from the
    /// keyboard, and the swipe is not available to Switch Control at all. The
    /// row is focusable and answers Space, which is the shortcut every Mac
    /// user already knows.
    private var quickLook: FileRowAction? {
        actions.first { $0.id == "quicklook" }
    }

    func body(content: Content) -> some View {
        applyingSwipe(to: content)
            .focusable(quickLook != nil)
            .onKeyPress(.space) {
                guard let quickLook else { return .ignored }
                quickLook.perform()
                return .handled
            }
            .contextMenu {
                ForEach(actions) { action in
                    Button(role: action.tone == .destructive ? .destructive : nil,
                           action: action.perform) {
                        Label(L(action.titleKey), systemImage: action.systemImage)
                    }
                }
            }
    }

    /// Swipe actions are macOS 27. Below that the context menu is the only
    /// affordance, which is what the app has always had — nothing is lost.
    @ViewBuilder
    private func applyingSwipe(to content: Content) -> some View {
        if #available(macOS 27.0, *) {
            content.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // Reversed: SwiftUI places the first button furthest from the
                // edge, so declaring them in menu order would put the
                // destructive one under the thumb.
                ForEach(actions.reversed()) { action in
                    Button(action: action.perform) {
                        Label(L(action.titleKey), systemImage: action.systemImage)
                    }
                    .tint(action.tone == .destructive ? MCColor.coral : MCColor.graphite)
                }
            }
        } else {
            content
        }
    }
}
