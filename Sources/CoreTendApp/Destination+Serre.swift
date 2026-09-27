import AppShell
import DesignSystem

extension Destination {
    /// The destination's icon in the Serre set (UI guide § 5).
    var glyph: SerreGlyph {
        switch self {
        case .overview: .overview
        case .explore: .explore
        case .cleanup: .cleanup
        case .duplicates: .duplicates
        case .applications: .applications
        case .integrity: .integrity
        case .performance: .performance
        case .record: .record
        }
    }
}
