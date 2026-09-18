// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import DesignSystem

/// Pause / Resume / Cancel for a running scan.
///
/// This cluster was written out by hand in seven views — Storage, Duplicates,
/// Space Lens, Large & Old Files, Similar Images, Cloud Cleanup, Privacy
/// Cleaner — each repeating the same two keyboard shortcuts, the same
/// swap-on-pause structure, and its own spelling of the accessibility hints.
/// Seven copies of a control cluster is seven places to fix anything about it,
/// and the copies had already drifted: some wired an accessibility hint to
/// Pause and Resume, some to neither.
///
/// One component now. The shortcuts, the styling and the hints live here, and
/// each screen supplies only what differs: its identifier prefix and its three
/// actions.
///
/// ## Why the button and its shortcut are bound together
///
/// `P` and `R` are bare keys with no modifier, so they are only safe while a
/// scan is actually running and no text field has focus. Keeping the shortcut
/// attached to the button that owns it means the binding disappears with the
/// button rather than lingering as a global.
struct MCScanControls: View {
    /// Prefix for accessibility identifiers — "storage", "duplicates", … so the
    /// UI harness can still address each screen's controls separately.
    let identifierPrefix: String
    let isPaused: Bool
    /// Localization keys for the hints, which are per-module because what
    /// pausing *means* differs: a Space Lens pause stops walking a tree, a
    /// Duplicates pause stops hashing.
    let pauseHintKey: String
    let resumeHintKey: String
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void

    init(identifierPrefix: String,
         isPaused: Bool,
         pauseHintKey: String = "cleanup.pause_hint",
         resumeHintKey: String = "cleanup.resume_hint",
         onPause: @escaping () -> Void,
         onResume: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.identifierPrefix = identifierPrefix
        self.isPaused = isPaused
        self.pauseHintKey = pauseHintKey
        self.resumeHintKey = resumeHintKey
        self.onPause = onPause
        self.onResume = onResume
        self.onCancel = onCancel
    }

    var body: some View {
        HStack(spacing: MCSpacing.sm) {
            if isPaused {
                Button(L("common.resume"), action: onResume)
                    .buttonStyle(.bordered)
                    .keyboardShortcut("r", modifiers: [])
                    .accessibilityHint(L(resumeHintKey))
                    .accessibilityIdentifier("\(identifierPrefix).scan.resume")
            } else {
                Button(L("common.pause"), action: onPause)
                    .buttonStyle(.bordered)
                    .keyboardShortcut("p", modifiers: [])
                    .accessibilityHint(L(pauseHintKey))
                    .accessibilityIdentifier("\(identifierPrefix).scan.pause")
            }

            // Cancel is secondary too, not destructive: it stops work, it does
            // not delete anything. Dressing it in coral would teach the user to
            // hesitate over the one control that is always safe to press.
            Button(L("common.cancel"), action: onCancel)
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("\(identifierPrefix).scan.cancel")
        }
    }
}
