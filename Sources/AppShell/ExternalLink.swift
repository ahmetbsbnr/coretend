import Foundation

/// What a link from outside the app asks for: `coretend://open/<space>`, `coretend://scan?path=<folder>`
/// (widget, Finder menu, Shortcuts) or a folder dropped on the Dock icon. Opening only changes what
/// is shown; nothing is moved.
public enum ExternalLink: Equatable, Sendable {
    case open(Destination)
    case scan(URL)

    public static let scheme = "coretend"

    public init?(_ url: URL) {
        if url.isFileURL {
            self = .scan(url.standardizedFileURL)
            return
        }
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        switch url.host {
        case "open":
            self = .open(Destination.restored(from: url.pathComponents.dropFirst().first))
        case "scan":
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "path" }?.value
            guard let path, path.hasPrefix("/") else { return nil }
            self = .scan(URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL)
        default:
            return nil
        }
    }
}
