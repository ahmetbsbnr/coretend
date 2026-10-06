import AppShell
import DesignSystem

extension Destination {
    /// The space's icon in the Serre set (UI guide § 5).
    var glyph: SerreGlyph {
        switch self {
        case .home: .overview
        case .space: .explore
        case .clean: .cleanup
        case .apps: .applications
        case .record: .record
        }
    }
}
