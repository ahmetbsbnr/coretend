import SwiftUI

/// Semantic SF text styles. System text styles scale with the user's Dynamic Type setting.
public enum CoreTendTypography {
    public static let pageTitle: Font = .system(.largeTitle, design: .default, weight: .semibold)
    public static let sectionTitle: Font = .system(.title2, design: .default, weight: .semibold)
    public static let body: Font = .system(.body, design: .default)
    public static let secondary: Font = .system(.subheadline, design: .default)
    public static let measurement: Font = .system(.title2, design: .default, weight: .semibold).monospacedDigit()
}
