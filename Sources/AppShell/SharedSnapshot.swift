import Foundation

/// What the app tells its widget: the space the last Clean survey found. Written to the app
/// group's container, the one place both the app and the sandboxed widget can read. Holds a
/// number and a date, never a path.
public struct SharedSnapshot: Codable, Equatable, Sendable {
    public static let appGroup = "NSCUV5G738.com.ahmetbsbnr.coretend"

    public let reclaimableBytes: Int64
    public let surveyedAt: Date

    public init(reclaimableBytes: Int64, surveyedAt: Date) {
        self.reclaimableBytes = reclaimableBytes
        self.surveyedAt = surveyedAt
    }

    /// `container` is the app group's folder; nil (unsigned local builds) means there is none.
    public static func load(from container: URL? = defaultContainer) -> SharedSnapshot? {
        guard let file = container?.appendingPathComponent(fileName),
              let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(SharedSnapshot.self, from: data)
    }

    public func save(to container: URL? = SharedSnapshot.defaultContainer) {
        guard let container, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: container.appendingPathComponent(Self.fileName), options: .atomic)
    }

    public static var defaultContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static let fileName = "snapshot.json"
}
