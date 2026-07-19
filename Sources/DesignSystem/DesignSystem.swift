import SwiftUI

/// MacCare Local design tokens. Original identity — calm teal/indigo palette,
/// generous spacing, native macOS materials.
public enum MCTheme {
    public static let accent = Color(red: 0.18, green: 0.62, blue: 0.58)
    public static let accentSecondary = Color(red: 0.35, green: 0.40, blue: 0.85)
    public static let warning = Color(red: 0.90, green: 0.60, blue: 0.15)
    public static let danger = Color(red: 0.85, green: 0.25, blue: 0.30)
    public static let success = Color(red: 0.20, green: 0.70, blue: 0.40)

    public static let cornerRadius: CGFloat = 12
    public static let cardPadding: CGFloat = 16
    public static let sidebarWidth: CGFloat = 220
}

/// Card container used across all module screens.
public struct MCCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(MCTheme.cardPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MCTheme.cornerRadius))
    }
}

/// Human-readable byte formatting shared by all views.
public func mcFormatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
