// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
// Small manual QA driver: reads AX, posts real keyboard/mouse events.
import AppKit
import ApplicationServices

guard CommandLine.arguments.count >= 3,
      let pid = Int32(CommandLine.arguments[1]), AXIsProcessTrusted() else {
    fputs("usage: interaction-probe PID dump|key CODE [FLAGS]|click X Y [FLAGS] [COUNT]|right X Y\nAccessibility permission required.\n", stderr)
    exit(2)
}
let args = CommandLine.arguments
let root = AXUIElementCreateApplication(pid)
func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}
func dump(_ element: AXUIElement, _ depth: Int = 0) {
    guard depth < 35 else { return }
    let names = ["AXRole", "AXIdentifier", "AXTitle", "AXDescription", "AXValue", "AXFocused", "AXSelected", "AXEnabled", "AXPosition", "AXSize"]
    print(String(repeating: " ", count: depth) + names.compactMap { name in
        attribute(element, name).map { "\(name)=\($0)" }
    }.joined(separator: " | "))
    for child in attribute(element, "AXChildren") as? [AXUIElement] ?? [] { dump(child, depth + 1) }
}
func flags(_ value: String) -> CGEventFlags {
    var result: CGEventFlags = []
    if value.contains("cmd") { result.insert(.maskCommand) }
    if value.contains("shift") { result.insert(.maskShift) }
    if value.contains("ctrl") { result.insert(.maskControl) }
    if value.contains("alt") { result.insert(.maskAlternate) }
    return result
}
switch args[2] {
case "dump": dump(root)
case "key":
    guard args.count > 3, let code = UInt16(args[3]) else { exit(2) }
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        event.flags = flags(args.count > 4 ? args[4] : "")
        event.postToPid(pid)
    }
case "click", "right":
    guard args.count > 4, let x = Double(args[3]), let y = Double(args[4]) else { exit(2) }
    NSRunningApplication(processIdentifier: pid)?.activate()
    usleep(150_000)
    let right = args[2] == "right"
    let count = args.count > 6 ? Int(args[6]) ?? 1 : 1
    for click in 1...count {
        for down in [true, false] {
            let event = CGEvent(mouseEventSource: nil,
                                mouseType: right ? (down ? .rightMouseDown : .rightMouseUp) : (down ? .leftMouseDown : .leftMouseUp),
                                mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: right ? .right : .left)!
            event.flags = flags(args.count > 5 ? args[5] : "")
            event.setIntegerValueField(.mouseEventClickState, value: Int64(click))
            event.post(tap: .cghidEventTap)
        }
        usleep(70_000)
    }
default: exit(2)
}
