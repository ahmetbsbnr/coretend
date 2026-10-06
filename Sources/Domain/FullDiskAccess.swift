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
    private let probe: URL

    /// `home` is the person's home folder; the probe is the user's own privacy database, present on
    /// every Mac and readable only with Full Disk Access.
    public init(home: URL) {
        probe = home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
    }

    public init(probe: URL) { self.probe = probe }

    public func status() -> FullDiskAccessStatus {
        guard FileManager.default.fileExists(atPath: probe.path) else { return .unknown }
        do {
            let handle = try FileHandle(forReadingFrom: probe)
            defer { try? handle.close() }
            _ = try handle.read(upToCount: 1)
            return .granted
        } catch {
            return .denied
        }
    }

    /// The pane of System Settings where Full Disk Access is granted.
    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
}
