import ApplicationServices
import Foundation

struct Node {
    let element: AXUIElement
    let role: String
    let identifier: String
    let title: String
    let description: String
    let value: String
    let placeholder: String
    let enabled: Bool
    let children: [Node]

    var json: [String: Any] {
        ["role": role, "identifier": identifier, "title": title,
         "description": description, "value": value, "placeholder": placeholder, "enabled": enabled,
         "children": children.map(\.json)]
    }
}

func attribute(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
    return result as AnyObject?
}

func stringAttribute(_ element: AXUIElement, _ key: String) -> String {
    if let string = attribute(element, key) as? String { return string }
    if let number = attribute(element, key) as? NSNumber { return number.stringValue }
    return ""
}

func tree(_ element: AXUIElement, depth: Int = 0) -> Node {
    let role = stringAttribute(element, kAXRoleAttribute as String)
    let children: [Node]
    if depth < 18, let elements = attribute(element, kAXChildrenAttribute as String) as? [AXUIElement] {
        children = elements.map { tree($0, depth: depth + 1) }
    } else {
        children = []
    }
    return Node(element: element, role: role,
                identifier: stringAttribute(element, kAXIdentifierAttribute as String),
                title: stringAttribute(element, kAXTitleAttribute as String),
                description: stringAttribute(element, kAXDescriptionAttribute as String),
                value: stringAttribute(element, kAXValueAttribute as String),
                placeholder: stringAttribute(element, kAXPlaceholderValueAttribute as String),
                enabled: (attribute(element, kAXEnabledAttribute as String) as? NSNumber)?.boolValue ?? false,
                children: children)
}

func flatten(_ node: Node) -> [Node] { [node] + node.children.flatMap(flatten) }

func fail(_ message: String, _ status: Int32 = 1) -> Never {
    fputs(message + "\n", stderr)
    exit(status)
}

guard CommandLine.arguments.count >= 3, let rawPID = Int32(CommandLine.arguments[2]) else {
    fail("usage: NativeUITestDriver dump|press|set <pid> [exact-title] [index|value]")
}
let app = AXUIElementCreateApplication(pid_t(rawPID))
guard let windows = attribute(app, kAXWindowsAttribute as String) as? [AXUIElement],
      let window = windows.first else { fail("no accessible app window (AX trusted: \(AXIsProcessTrusted()))", 2) }
let root = tree(window)

switch CommandLine.arguments[1] {
case "dump":
    let data = try! JSONSerialization.data(withJSONObject: root.json, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
case "press", "set":
    guard CommandLine.arguments.count >= 4 else { fail("missing exact title") }
    let query = CommandLine.arguments[3]
    let matches = flatten(root).filter {
        $0.title == query || $0.identifier == query || $0.description == query || $0.placeholder == query
    }
    guard !matches.isEmpty else { fail("element not found: \(query)", 3) }
    let index = CommandLine.arguments.count > 4 ? (Int(CommandLine.arguments[4]) ?? 0) : 0
    guard matches.indices.contains(index) else { fail("element index out of range: \(query)", 3) }
    let element = matches[index].element
    let result: AXError
    if CommandLine.arguments[1] == "press" {
        guard matches[index].enabled else { fail("element is disabled: \(query)", 4) }
        result = AXUIElementPerformAction(element, kAXPressAction as CFString)
    } else {
        guard CommandLine.arguments.count > 4 else { fail("set requires a value") }
        result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, CommandLine.arguments[4] as CFString)
    }
    guard result == .success else {
        fail("AX action failed (\(result.rawValue)): \(query) [\(matches[index].role), \(matches[index].title), \(matches[index].description), \(matches[index].value), \(matches[index].placeholder)]", 5)
    }
    print("OK \(CommandLine.arguments[1]) \(query)")
default:
    fail("unknown command")
}
