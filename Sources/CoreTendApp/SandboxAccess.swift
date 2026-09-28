import Darwin
import Foundation

/// Where the app runs. In the Mac App Store build the App Sandbox is on: `NSHomeDirectory()` is the
/// app's container, and a folder can be read only after the person picks it in the system panel.
/// Suggested folders (Applications, LaunchAgents, a cleanup rule's place) are then offered by
/// opening that panel on them — the click in the panel is the choice, as everywhere else.
enum SandboxAccess {
    static let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

    /// The person's real home folder. Outside the sandbox this is `NSHomeDirectory()`, so a fixture
    /// HOME set for tests and captures is honoured; inside it, the account's home from the user database.
    static var userHome: URL {
        if isSandboxed, let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    /// A path as people read it: inside the home folder it starts with "~".
    static func displayPath(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        let home = userHome.standardizedFileURL.path
        if path == home { return "~" }
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}
