// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation

/// Localized lookup for the Finder extension's handful of menu labels, from
/// this module's own tiny EN + FR table via `Bundle.module`. Same strategy
/// as `WidgetShared.WL` — the extension shows four phrases, so it does not
/// carry a copy of the app's ~1000-key catalog. Parity between the two
/// `.lproj` files is checked by `FinderSharedTests`.
public func FL(_ key: String) -> String {
    Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
}
