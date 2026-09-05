// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// The custom URL scheme CoreTend registers so its Finder Sync extension — a
/// sandboxed process that must **not** link the app or any destructive
/// module — can hand a single selected path to the host with one
/// `NSWorkspace.open`.
///
///     coretend://finder/<action>?path=<percent-encoded-absolute-path>
///
/// A custom URL carries both action and path without linking host intent
/// types or writing an App Group payload. The extension explicitly targets
/// its containing app using NSWorkspace.open(_:withApplicationAt:configuration:)
/// so another app's scheme registration cannot receive the selected path.
/// The scheme remains externally invokable: the host validates syntax and
/// live filesystem kind at receipt and again when consuming the route.
/// No custom IPC, background polling, or persistent payload is needed.
public enum FinderHandoffURL {
    public static let scheme = "coretend"
    public static let host = "finder"
    /// A generous ceiling. A real absolute path is a few hundred bytes; this
    /// is the syntactic guard against a pathological payload.
    public static let maxPathLength = 1024

    /// Build a handoff URL, or `nil` if `path` is not a plausible absolute
    /// POSIX path.
    public static func make(action: FinderAction, path: String) -> URL? {
        guard isPlausibleAbsolutePath(path) else { return nil }
        var c = URLComponents()
        c.scheme = scheme
        c.host = host
        c.path = "/" + action.rawValue
        c.queryItems = [URLQueryItem(name: "path", value: path)]
        return c.url
    }

    /// Parse a `coretend://finder/…` URL back to `(action, path)`. Returns
    /// `nil` for anything malformed — wrong scheme/host, unknown action,
    /// missing/relative/oversized path, embedded NUL, or a `..` component.
    /// This is a **syntactic** gate only; the host still runs
    /// `SelectionValidator` against the real filesystem before it acts.
    public static func parse(_ url: URL) -> (action: FinderAction, path: String)? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.user == nil, comps.password == nil, comps.port == nil,
              comps.fragment == nil
        else { return nil }

        let slug = String(comps.path.dropFirst())
        guard let action = FinderAction(rawValue: slug) else { return nil }

        // `queryItems` are already percent-decoded by URLComponents.
        guard let items = comps.queryItems, items.count == 1, items[0].name == "path",
              let path = items[0].value,
              isPlausibleAbsolutePath(path)
        else { return nil }

        return (action, path)
    }

    static func isPlausibleAbsolutePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              path.count <= maxPathLength,
              path.hasPrefix("/"),
              !path.hasPrefix("//"),
              path.rangeOfCharacter(from: .controlCharacters) == nil,
              !path.split(separator: "/", omittingEmptySubsequences: true).contains("..")
        else { return false }
        return true
    }
}
