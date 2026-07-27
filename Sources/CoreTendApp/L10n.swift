import Foundation

/// Looks up a localized string from the app's Localizable.strings (Base/fr) via Bundle.module.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
    if args.isEmpty { return format }
    return String(format: format, arguments: args)
}
