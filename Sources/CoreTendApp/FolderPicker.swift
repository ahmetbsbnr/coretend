// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppKit
import Foundation

/// The one way CoreTend asks the user for a folder.
///
/// Four screens ran their own `NSOpenPanel` to pick a scan root. In the
/// sandboxed build, picking a folder in a panel grants access to it *for this
/// launch* — turning that into a lasting grant requires recording a
/// security-scoped bookmark at the moment of the pick, and nowhere else. A
/// panel that forgets is not broken today: it works for the whole session and
/// then quietly asks again after the next relaunch, which reads as the app
/// losing the user's settings.
///
/// So the panel and the grant are one call. A fifth screen that needs a folder
/// cannot forget the half it does not know about.
@MainActor
enum FolderPicker {
    /// Presents a folder chooser and records the grant.
    ///
    /// Returns nil when the user cancels — which is not an error and must not
    /// be reported as one.
    ///
    /// A failure to bookmark *is* surfaced, because in the sandboxed build it
    /// means the scan about to start will work once and never again, and
    /// silently degrading to that is worse than saying so.
    static func chooseFolder(
        message: String? = nil,
        startingAt directory: URL? = nil,
        access: FolderAccess = .shared
    ) -> Result<URL, FolderAccessError>? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if let message { panel.message = message }
        if let directory { panel.directoryURL = directory }

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            try access.grant(url)
            return .success(url)
        } catch let error as FolderAccessError {
            return .failure(error)
        } catch {
            return .failure(.couldNotBookmark(url.path))
        }
    }

    /// The common case: a chosen folder, or nil.
    ///
    /// Bookmark failures are swallowed here *and the folder is still returned*,
    /// because a scan that works for one session is better than no scan at all.
    /// Callers that want to tell the user use `chooseFolder` and read the
    /// Result.
    static func chooseFolderOrNil(message: String? = nil, startingAt directory: URL? = nil) -> URL? {
        switch chooseFolder(message: message, startingAt: directory) {
        case .success(let url): url
        case .failure(let error):
            switch error {
            case .couldNotBookmark(let path), .unresolvable(let path), .accessRefused(let path):
                URL(fileURLWithPath: path)
            }
        case nil: nil
        }
    }
}
