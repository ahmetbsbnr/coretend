import Foundation

/// Filename evidence only. A match does not establish ownership by an application.
public enum ApplicationAssociationMatcher {
    public static func matches(_ url: URL, bundleIdentifier: String) -> Bool {
        guard !bundleIdentifier.isEmpty, !bundleIdentifier.contains("/"), bundleIdentifier != ".", bundleIdentifier != ".." else { return false }
        return url.pathComponents.contains(bundleIdentifier)
            || url.deletingPathExtension().lastPathComponent == bundleIdentifier
    }
}
