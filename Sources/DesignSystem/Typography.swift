import SwiftUI

/// Serre typography (Documentation/Design/UI-guide.md § 3): Iowan Old Style for titles and hero
/// figures, Avenir Next for everything else. Both ship with macOS, so nothing is bundled. Every
/// style scales with Dynamic Type relative to the system style named beside it.
public enum CoreTendTypography {
    /// Iowan Old Style has no semibold; titles use its bold.
    public static let pageTitle: Font = .custom("IowanOldStyle-Bold", size: 44, relativeTo: .largeTitle)
    /// The main measurement of a view.
    public static let hero: Font = .custom("IowanOldStyle-Roman", size: 40, relativeTo: .largeTitle)
    /// The sentence under a page title.
    public static let lede: Font = .custom("AvenirNext-Regular", size: 16, relativeTo: .title3)
    public static let sectionTitle: Font = .custom("AvenirNext-DemiBold", size: 13, relativeTo: .headline)
    public static let body: Font = .custom("AvenirNext-Regular", size: 14, relativeTo: .body)
    public static let secondary: Font = .custom("AvenirNext-Regular", size: 13, relativeTo: .subheadline)
    /// Sources, measurement times, footnotes.
    public static let caption: Font = .custom("AvenirNext-Regular", size: 12, relativeTo: .caption)
    public static let measurement: Font = .custom("AvenirNext-Medium", size: 20, relativeTo: .title2).monospacedDigit()

    /// PostScript names the styles above depend on; DesignSystemTests checks they are installed.
    public static let requiredFontNames = [
        "IowanOldStyle-Bold", "IowanOldStyle-Roman", "AvenirNext-Regular", "AvenirNext-Medium", "AvenirNext-DemiBold",
    ]
}
