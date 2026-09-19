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

    /// The last few folders of a path, for a dense row.
    ///
    /// A row in Cleanup shows a file name and where it lives. `folder(of:)`
    /// returns the whole folder path, which on a real machine is long and on a
    /// capture read as
    /// `/private/var/folders/tc/9z4_b12n6k55sdbqqs6mpns40000gn/T/…` occupying
    /// most of the row — a string nobody can act on, set wider than the file
    /// name they can. The answer to "where is this" in a list is the nearest
    /// couple of folders; the full path belongs in the inspector and in Reveal
    /// in Finder.
    static func shortFolder(of url: URL, components: Int = 2,
                            home: String = NSHomeDirectory()) -> String {
        let full = folder(of: url, home: home)
        let parts = full.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count > components else { return full }
        return "…/" + parts.suffix(components).joined(separator: "/")
    }
}
