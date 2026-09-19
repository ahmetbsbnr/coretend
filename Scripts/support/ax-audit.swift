// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Walks the accessibility tree of the running CoreTend and reports every
// interactive element a screen reader would announce as nothing.
//
// This is not a VoiceOver walk and does not claim to be one: VoiceOver reads
// an element's label, its role description, its value and its help, in an
// order that depends on the rotor and on what came before. What this proves
// is narrower and still worth proving — that no control is nameless.
import ApplicationServices
import AppKit

let interactive: Set<String> = [
    kAXButtonRole, kAXCheckBoxRole, kAXRadioButtonRole, kAXPopUpButtonRole,
    kAXTextFieldRole, kAXSliderRole, kAXMenuButtonRole, "AXLink",
]

func string(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? String
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
          let list = value as? [AXUIElement] else { return [] }
    return list
}

var nameless: [String] = []
var counted = 0

func walk(_ element: AXUIElement, path: String, depth: Int) {
    guard depth < 40 else { return }
    let role = string(element, kAXRoleAttribute) ?? "?"
    // The window's own close / minimise / zoom buttons are AppKit's, and two
    // of the three report no name at all. They are not CoreTend's controls
    // and naming them is not CoreTend's to do.
    let subrole = string(element, kAXSubroleAttribute) ?? ""
    let systemChrome: Set<String> = ["AXCloseButton", "AXMinimizeButton", "AXZoomButton", "AXFullScreenButton"]
    if interactive.contains(role) && !systemChrome.contains(subrole) {
        counted += 1
        // A placeholder counts. VoiceOver reads it for an empty text field —
        // "Search the Record, search text field" — so a search field whose
        // only name is its prompt is named, and reporting it was this audit
        // inventing a finding rather than finding one.
        let name = [string(element, kAXDescriptionAttribute),
                    string(element, kAXTitleAttribute),
                    string(element, kAXValueAttribute),
                    string(element, kAXPlaceholderValueAttribute),
                    string(element, kAXHelpAttribute)]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if name == nil {
            var position: CFTypeRef?
            var size: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
            AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
            var origin = CGPoint.zero, extent = CGSize.zero
            if let position { AXValueGetValue(position as! AXValue, .cgPoint, &origin) }
            if let size { AXValueGetValue(size as! AXValue, .cgSize, &extent) }
            let identifier = string(element, kAXIdentifierAttribute) ?? "no identifier"
            nameless.append("\(path) > \(role) [\(identifier)] at \(Int(origin.x)),\(Int(origin.y)) size \(Int(extent.width))x\(Int(extent.height))")
        }
    }
    let label = string(element, kAXTitleAttribute) ?? string(element, kAXDescriptionAttribute) ?? role
    for child in children(element) { walk(child, path: "\(path) > \(label)", depth: depth + 1) }
}

guard AXIsProcessTrusted() else {
    FileHandle.standardError.write(Data("ax-audit: this process is not trusted for accessibility — grant it in System Settings > Privacy & Security > Accessibility\n".utf8))
    exit(3)
}
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.coretend.app").first
        ?? NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "CoreTend" }) else {
    FileHandle.standardError.write(Data("ax-audit: CoreTend is not running\n".utf8))
    exit(1)
}
let root = AXUIElementCreateApplication(app.processIdentifier)
for window in children(root) {
    walk(window, path: string(window, kAXTitleAttribute) ?? "window", depth: 0)
}
print("interactive elements: \(counted)")
if nameless.isEmpty {
    print("all named")
    exit(0)
}
print("nameless: \(nameless.count)")
for entry in nameless { print("  \(entry)") }
exit(2)
