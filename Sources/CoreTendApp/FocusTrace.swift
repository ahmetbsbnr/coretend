// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppKit
import Persistence

/// Temporary, opt-in interaction diagnostics. Never changes event delivery.
@MainActor
enum FocusTrace {
    private static var monitor: Any?
    private static var output: URL?

    static func start() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["CORETEND_TRACE_FOCUS"] == "1",
              let directory = TestStoreOverride.resolve(environment: environment).directory else { return }
        output = directory.appendingPathComponent("focus.jsonl")
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { event in
            let label = event.type == .keyDown
                ? "key:\(event.keyCode):modifiers:\(event.modifierFlags.rawValue)"
                : "mouse:\(event.type.rawValue)"
            snapshot("before:\(label)")
            DispatchQueue.main.async { snapshot("after:\(label)") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { snapshot("settled:\(label)") }
            return event
        }
    }

    static func snapshot(_ reason: String) {
        guard let output else { return }
        func describe(_ responder: NSResponder?) -> String {
            guard let responder else { return "nil" }
            let identity = String(describing: Unmanaged.passUnretained(responder).toOpaque())
            let view = responder as? NSView
            return "\(type(of: responder))@\(identity)[\(view?.identifier?.rawValue ?? "")][\(view?.accessibilityIdentifier() ?? "")]"
        }
        let window = NSApp.keyWindow
        var chain: [String] = []
        var current = window?.firstResponder
        while let responder = current, chain.count < 30 {
            chain.append(describe(responder))
            current = responder.nextResponder
        }
        var loop: [String] = []
        var view = (window?.firstResponder as? NSView) ?? window?.contentView
        var seen: Set<ObjectIdentifier> = []
        while let item = view, seen.insert(ObjectIdentifier(item)).inserted, loop.count < 80 {
            loop.append(describe(item))
            view = item.nextValidKeyView
        }
        var candidates: [[String: Any]] = []
        func walk(_ view: NSView) {
            if view.acceptsFirstResponder {
                var entry: [String: Any] = ["view": describe(view), "frame": NSStringFromRect(view.convert(view.bounds, to: nil)),
                                           "hidden": view.isHiddenOrHasHiddenAncestor]
                if let table = view as? NSTableView {
                    entry["selectedRows"] = Array(table.selectedRowIndexes)
                    entry["rows"] = table.numberOfRows
                }
                candidates.append(entry)
            }
            view.subviews.forEach(walk)
        }
        if let content = window?.contentView { walk(content) }
        let record: [String: Any] = ["time": Date().timeIntervalSince1970, "reason": reason,
                                     "window": window?.windowNumber ?? -1, "title": window?.title ?? "",
                                     "firstResponder": describe(window?.firstResponder),
                                     "chain": chain, "keyLoop": loop, "candidates": candidates]
        guard var data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) else { return }
        data.append(10)
        if !FileManager.default.fileExists(atPath: output.path) { FileManager.default.createFile(atPath: output.path, contents: nil) }
        guard let file = try? FileHandle(forWritingTo: output) else { return }
        defer { try? file.close() }
        _ = try? file.seekToEnd()
        try? file.write(contentsOf: data)
    }
}
