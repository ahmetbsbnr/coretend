// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// How a filesystem path is shown to a person.
///
/// Every list in the app printed absolute paths, so each row began with the
/// same forty characters of `/Users/<name>/Library/…` and the part that told
/// them apart started past the middle of the line. Finder, the Terminal and
/// every Mac app abbreviate the home directory; so does CoreTend.
///
/// This is display only. Nothing here is written to the audit trail — that
/// has its own redaction (`Store.redactPath`), for a different reason.
enum PathDisplay {
    /// `/Users/ada/Library/Caches` → `~/Library/Caches`.
    ///
    /// Takes the home directory as a parameter so it is testable without
    /// depending on who is running the tests.
    static func abbreviate(_ path: String, home: String = NSHomeDirectory()) -> String {
        guard !home.isEmpty, path == home || path.hasPrefix(home + "/") else { return path }
        return "~" + path.dropFirst(home.count)
    }

    static func abbreviate(_ url: URL, home: String = NSHomeDirectory()) -> String {
        abbreviate(url.path, home: home)
    }

    /// The folder a file sits in, abbreviated — what a row shows beside a name.
    static func folder(of url: URL, home: String = NSHomeDirectory()) -> String {
        abbreviate(url.deletingLastPathComponent(), home: home)
    }
}
