// Window lookup for Scripts/capture_screens.py.
//   preflight   exit 0 if this process may record the screen, 3 otherwise
//   window PID  print the window number of PID's largest on-screen normal window, exit 4 if none
import CoreGraphics
import Foundation

let arguments = CommandLine.arguments
switch arguments.count > 1 ? arguments[1] : "" {
case "preflight":
    exit(CGPreflightScreenCaptureAccess() ? 0 : 3)
case "window" where arguments.count == 3:
    guard let pid = Int32(arguments[2]),
          let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
    else { exit(64) }
    let candidates = windows.compactMap { window -> (number: Int, area: Double)? in
        guard window[kCGWindowOwnerPID as String] as? Int32 == pid,
              window[kCGWindowLayer as String] as? Int == 0,
              let number = window[kCGWindowNumber as String] as? Int,
              let bounds = window[kCGWindowBounds as String] as? [String: Double],
              let width = bounds["Width"], let height = bounds["Height"], width > 200, height > 200
        else { return nil }
        return (number, width * height)
    }
    guard let largest = candidates.max(by: { $0.area < $1.area }) else { exit(4) }
    print(largest.number)
default:
    FileHandle.standardError.write(Data("usage: capture_window_helper preflight | window PID\n".utf8))
    exit(64)
}
