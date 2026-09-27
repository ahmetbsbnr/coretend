import SwiftUI

/// The Serre "leaf corner" (Documentation/Design/UI-guide.md § 4): large radii top-leading and
/// bottom-trailing, small radii at the two tips.
public enum LeafCorner: Sendable {
    /// Buttons, sidebar selection, rows.
    case control
    /// Cards ("parcels").
    case parcel
    /// Sheets, search, popovers.
    case sheet

    public var radii: (large: CGFloat, small: CGFloat) {
        switch self {
        case .control: (16, 5)
        case .parcel: (20, 7)
        case .sheet: (22, 8)
        }
    }

    public var shape: UnevenRoundedRectangle {
        let radii = radii
        return UnevenRoundedRectangle(
            topLeadingRadius: radii.large, bottomLeadingRadius: radii.small,
            bottomTrailingRadius: radii.large, topTrailingRadius: radii.small, style: .continuous
        )
    }
}
