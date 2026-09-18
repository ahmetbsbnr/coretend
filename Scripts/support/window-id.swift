import CoreGraphics
import Foundation
// Prints the CoreGraphics window id of the frontmost on-screen window whose
// owner is the named process. `screencapture -l` needs this; the accessibility
// API does not expose it.
let name = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "CoreTend"
guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { exit(1) }
for w in list {
    guard let owner = w[kCGWindowOwnerName as String] as? String, owner == name,
          let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
          let id = w[kCGWindowNumber as String] as? Int else { continue }
    let bounds = w[kCGWindowBounds as String] as? [String: Any]
    let h = (bounds?["Height"] as? Double) ?? 0
    if h < 200 { continue }   // skip panels and the menu-bar popover
    print(id); exit(0)
}
exit(2)
