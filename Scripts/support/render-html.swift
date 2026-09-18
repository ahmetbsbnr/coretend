// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Renders a local HTML file to a PNG at a fixed viewport, so a design mockup
// can be compared as an image rather than described in prose. Used by
// Scripts/render-mockups.sh. Deliberately offline: file:// only, no network
// loads, so a captured mockup is a function of the repository alone.
//
// usage: swift render-html.swift <input.html> <output.png> <width> <height>

import AppKit
import WebKit

let args = CommandLine.arguments
guard args.count == 5,
      let width = Double(args[3]), let height = Double(args[4]) else {
    FileHandle.standardError.write("usage: render-html.swift <in.html> <out.png> <w> <h>\n".data(using: .utf8)!)
    exit(2)
}
let input = URL(fileURLWithPath: args[1]).standardizedFileURL
let output = URL(fileURLWithPath: args[2])

final class Renderer: NSObject, WKNavigationDelegate {
    let view: WKWebView
    let output: URL
    init(size: CGSize, output: URL) {
        let config = WKWebViewConfiguration()
        self.view = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: config)
        self.output = output
        super.init()
        view.navigationDelegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // One runloop turn after load so web fonts and the first layout pass
        // have settled; snapshotting immediately captures a blank frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.snapshot() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }

    private func fail(_ error: Error) {
        FileHandle.standardError.write("load failed: \(error)\n".data(using: .utf8)!)
        exit(1)
    }

    private func snapshot() {
        let config = WKSnapshotConfiguration()
        config.rect = view.bounds
        view.takeSnapshot(with: config) { image, error in
            guard let image, error == nil else { self.fail(error ?? URLError(.unknown)); return }
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                FileHandle.standardError.write("encode failed\n".data(using: .utf8)!)
                exit(1)
            }
            do { try png.write(to: self.output) } catch {
                FileHandle.standardError.write("write failed: \(error)\n".data(using: .utf8)!)
                exit(1)
            }
            print("\(self.output.path) \(rep.pixelsWide)x\(rep.pixelsHigh)")
            exit(0)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let renderer = Renderer(size: CGSize(width: width, height: height), output: output)
// Read access is granted to the containing directory so the shared stylesheet
// resolves; nothing above it is reachable.
renderer.view.loadFileURL(input, allowingReadAccessTo: input.deletingLastPathComponent())

DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
    FileHandle.standardError.write("timed out waiting for \(input.lastPathComponent)\n".data(using: .utf8)!)
    exit(1)
}
app.run()
