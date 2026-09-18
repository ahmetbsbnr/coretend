// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI

/// Which kind of screen a view is, stated in the type system rather than left
/// to whether someone remembered a modifier.
///
/// The app has two kinds and they had no way to tell each other apart:
///
/// - A **module** is reachable from the sidebar, owns the window title, and is
///   one of the eleven `ModuleID` cases.
/// - A **sub-screen** is reached through a module's `ModuleSubNav` — Leftovers,
///   App Updates, Privacy Cleaner, Similar Images, Large & Old Files. It must
///   *not* set a window title, because its parent module already did and the
///   last writer would win.
///
/// Three sub-screens shipped with no title and nothing noticed, because the
/// only difference between "correctly has no title" and "forgot the title" was
/// intent, which the build cannot read. `ModuleScreenContractTests` can read
/// these declarations.
protocol ModuleScreen: View {
    /// The `ModuleID` this screen is the landing view for.
    static var module: ModuleID { get }
}

/// A screen reached from inside a module rather than from the sidebar.
///
/// Conforming is the declaration that having no `navigationTitle` is deliberate.
protocol ModuleSubScreen: View {
    /// The module this screen lives under — so a reader (and a test) can see
    /// which title is already on screen above it.
    static var parent: ModuleID { get }

    /// The localization key for this screen's own label, which its parent's
    /// `ModuleSubNav` renders. Stated here so the label and the screen cannot
    /// drift apart in separate files.
    static var labelKey: String { get }
}
