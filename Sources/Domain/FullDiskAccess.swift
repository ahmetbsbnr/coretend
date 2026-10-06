import Foundation

/// Whether macOS lets CoreTend read the places protected by privacy controls (Mail, Safari,
/// other apps' data). Measured by reading the first byte of a file only Full Disk Access opens.
public enum FullDiskAccessStatus: Equatable, Sendable {
    case granted
    case denied
    /// The probe file is missing, so nothing can be said.
    case unknown
}

public struct FullDiskAccessProbe: Sendable {
    private let probes: [URL]

    /// `home` is the person's home folder. Several places only Full Disk Access opens are tried in
    /// turn, because none exists on every Mac: the per-user privacy database (gone on recent
    /// macOS), the system one, Safari's bookmarks and the Mail folder.
    public init(home: URL) {
        probes = [
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db"),
            home.appendingPathComponent("Library/Safari/Bookmarks.plist"),
            home.appendingPathComponent("Library/Mail", isDirectory: true),
        ]
    }

    public init(probes: [URL]) { self.probes = probes }

    /// Granted when any existing probe can be read, denied when probes exist but none can,
    /// unknown when none exists.
    public func status() -> FullDiskAccessStatus {
        var anyExists = false
        for probe in probes {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: probe.path, isDirectory: &isDirectory) else { continue }
            anyExists = true
            if isDirectory.boolValue {
                if (try? FileManager.default.contentsOfDirectory(atPath: probe.path)) != nil { return .granted }
            } else if let handle = try? FileHandle(forReadingFrom: probe) {
                defer { try? handle.close() }
                if (try? handle.read(upToCount: 1)) != nil { return .granted }
            }
        }
        return anyExists ? .denied : .unknown
    }

    /// The pane of System Settings where Full Disk Access is granted.
    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
}
