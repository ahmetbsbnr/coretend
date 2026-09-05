// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import FinderShared

/// Host side of the Finder Sync extension handoff.
///
/// The extension opens a `coretend://finder/<action>?path=<abs-path>` URL;
/// macOS delivers it here via SwiftUI's `onOpenURL`. Every value in that URL
/// is **untrusted** — even though Finder produced the selection, the scheme
/// is world-invokable and the filesystem can change between the selection
/// and this call. So `handle(_:)`:
///
///   1. parses the URL syntactically (`FinderHandoffURL.parse`);
///   2. re-validates the path against the LIVE filesystem for that specific
///      action (`SelectionValidator` — a purpose-built *read-only* validator,
///      not `SafetyCore.PathValidator`, which is for destructive selection);
///   3. routes to the existing CoreTend screen via `AppRouter`.
///
/// The only routes it can produce are Space Lens (a read-only folder size
/// scan), Privacy Lab (in-memory image-metadata inspection), and the
/// Integrity inspector (a code-signature read). None of them delete, trash,
/// clean, restore, or uninstall anything.
enum FinderHandoff {
    @MainActor
    static func handle(_ url: URL) {
        guard let (action, path) = FinderHandoffURL.parse(url) else { return }

        switch SelectionValidator.validate(path: path, for: action) {
        case .failure:
            // The target no longer matches, vanished, or is a system
            // location we won't scan. Bring the app forward so the click is
            // not silently lost, but inspect nothing.
            AppRouter.shared.route(to: .module(.smartCare))
            AppRouter.shared.finderSelectionRejected = true

        case let .success(fileURL):
            switch action {
            case .scanFolder:
                AppRouter.shared.route(to: .scanFolder(fileURL))
            case .inspectImage:
                AppRouter.shared.route(to: .inspectImage(fileURL))
            case .inspectApplication:
                AppRouter.shared.route(to: .inspectApplication(fileURL))
            }
        }
    }
}
