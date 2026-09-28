import Foundation

/// Filename evidence only. A match does not establish ownership by an application.
public enum ApplicationAssociationMatcher {
    public static func matches(_ url: URL, bundleIdentifier: String) -> Bool {
        guard !bundleIdentifier.isEmpty, !bundleIdentifier.contains("/"), bundleIdentifier != ".", bundleIdentifier != ".." else { return false }
        return url.pathComponents.contains(bundleIdentifier)
            || url.deletingPathExtension().lastPathComponent == bundleIdentifier
    }
}

/// What a candidate file's name has in common with an app. Neither proves the file belongs to it.
public enum AssociationEvidence: Equatable, Sendable {
    /// A path component or the file name is the app's bundle identifier.
    case identifier
    /// A folder or file in the path is named exactly like the app (for example "Google Chrome").
    case name
}

public extension ApplicationAssociationMatcher {
    /// Names too common to say anything about an app.
    static let genericNames: Set<String> = ["app", "apps", "data", "cache", "caches", "library", "support",
                                           "documents", "settings", "preferences", "logs", "config"]

    /// The evidence linking `url` to the app, strongest first, or nil.
    static func evidence(_ url: URL, bundleIdentifier: String, displayName: String) -> AssociationEvidence? {
        if matches(url, bundleIdentifier: bundleIdentifier) { return .identifier }
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard name.count >= 4, !genericNames.contains(name.lowercased()), !name.contains("/") else { return nil }
        let components = url.pathComponents + [url.deletingPathExtension().lastPathComponent]
        return components.contains { $0.compare(name, options: [.caseInsensitive]) == .orderedSame } ? .name : nil
    }
}
