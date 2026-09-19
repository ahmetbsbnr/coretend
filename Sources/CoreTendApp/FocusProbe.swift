// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import AppKit
import Persistence

/// Development instrumentation: writes down where keyboard focus actually is.
///
/// Added because the keyboard-focus defect could not be diagnosed by reading
/// the view code. SwiftUI's `FocusState` says what *it* believes; the thing
/// that decides whether Tab reaches a list is AppKit's first responder and the
/// window's key-view loop, and neither is visible from a SwiftUI view.
///
/// Inert outside test mode: gated on the same validated two-key marker as the
/// store override, writes only inside the throwaway store directory, and is
/// never started on a normal launch.
@MainActor
enum FocusProbe {
    private static var timer: Timer?

    static func startIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard TestStoreOverride.isTestMarkerSet(environment: environment),
              let directory = TestStoreOverride.resolve(environment: environment).directory,
              environment["CORETEND_FOCUS_PROBE"] == "1"
        else { return }
        let url = directory.appendingPathComponent("focus.txt")
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            MainActor.assumeIsolated { Self.write(to: url) }
        }
    }

    private static func write(to url: URL) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return }
        var lines: [String] = []
        lines.append("window=\(window.title.isEmpty ? "<untitled>" : window.title)")
        let responder = window.firstResponder
        lines.append("firstResponder=\(responder.map { String(describing: type(of: $0)) } ?? "nil")")
        if let view = responder as? NSView {
            lines.append("responderIdentifier=\(view.identifier?.rawValue ?? "-")")
            lines.append("acceptsFirstResponder=\(view.acceptsFirstResponder)")
            lines.append("canBecomeKeyView=\(view.canBecomeKeyView)")
            lines.append("nextKeyView=\(view.nextKeyView.map { String(describing: type(of: $0)) } ?? "nil")")
            // Where in the window this responder sits, so a reader can tell the
            // sidebar from the detail column without guessing from a class name.
            let frame = view.convert(view.bounds, to: nil)
            lines.append("frame=\(Int(frame.minX)),\(Int(frame.minY)),\(Int(frame.width)),\(Int(frame.height))")
        }
        // The key-view loop as the window will actually walk it on Tab.
        var chain: [String] = []
        var cursor = window.initialFirstResponder ?? window.contentView?.nextValidKeyView
        var guardCount = 0
        while let view = cursor, guardCount < 24 {
            chain.append(String(describing: type(of: view)))
            cursor = view.nextValidKeyView
            if cursor === window.initialFirstResponder { break }
            guardCount += 1
        }
        lines.append("keyViewLoop=\(chain.joined(separator: " -> "))")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
