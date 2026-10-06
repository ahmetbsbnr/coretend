import Foundation

/// The person's home folder. `NSHomeDirectory()` follows `HOME`, so a fixture HOME set for tests and
/// captures is honoured.
enum HomeFolder {
    static var url: URL { URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true) }

    /// A path as people read it: inside the home folder it starts with "~".
    static func displayPath(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        let home = Self.url.standardizedFileURL.path
        if path == home { return "~" }
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}
