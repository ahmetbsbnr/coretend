// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import SwiftUI
import AppKit
import DesignSystem

/// A file's or bundle's Finder icon, resolved once per path.
///
/// `NSWorkspace.icon(forFile:)` reads the bundle from disk. Called straight
/// from a `Table` cell it runs again for every row on every redraw — scrolling
/// a list of two hundred applications, or simply moving the pointer across it,
/// re-read every icon. The cache is bounded and keyed by path, which is what
/// the workspace itself keys on.
///
/// The size is set on the `NSImage` as well as on the frame: an icon asked
/// for at its natural 512pt and then scaled down in SwiftUI makes AppKit pick
/// the 512pt representation for a 20pt row.
@MainActor
enum FileIconCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 400
        return cache
    }()

    static func icon(for path: String, size: CGFloat) -> NSImage {
        let key = "\(path)@\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        // `copy()` then `size`, not a redraw into a new NSImage.
        //
        // The redraw version rendered every fixture bundle as a "prohibited"
        // glyph in a capture: a workspace icon is a multi-representation
        // image, and drawing it into a fresh bitmap picks one representation
        // out of context. Setting `size` on a copy leaves the representations
        // alone and simply tells AppKit which one to pick at draw time.
        let image = NSWorkspace.shared.icon(forFile: path)
        let sized = image.copy() as? NSImage ?? image
        sized.size = NSSize(width: size, height: size)
        cache.setObject(sized, forKey: key)
        return sized
    }

    /// Called when a path's contents change underneath us — an uninstall, a
    /// move to the Trash. Cheaper and more honest than keeping a stale icon
    /// for a bundle that is no longer there.
    static func invalidate() { cache.removeAllObjects() }
}

/// The icon for a path, at a size, decorative by default.
///
/// Always `accessibilityHidden`: in every place this is used the name sits
/// right beside it, and an icon announced as "Safari, image" after "Safari"
/// is one word of information and one of noise.
struct FileIcon: View {
    let path: String
    var size: CGFloat = MCIconSize.row

    var body: some View {
        Image(nsImage: FileIconCache.icon(for: path, size: size))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
