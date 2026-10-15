import Foundation
import HelperProtocol

/// The programs the helper may run, at fixed paths (decisions 0006 and 0007).
enum SystemTool: String {
    case launchctl = "/bin/launchctl"
    case tmutil = "/usr/bin/tmutil"
    case mdutil = "/usr/bin/mdutil"
}

/// The one place the helper runs a program, with arguments it builds itself.
enum Launchctl {
    /// Runs one of `SystemTool` and returns its exit status and standard output.
    static func run(_ arguments: [String], tool: SystemTool = .launchctl) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool.rawValue)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// Labels `launchctl print-disabled system` reports as disabled.
    static func disabledSystemLabels() -> Set<String> {
        LaunchctlOutput.disabledLabels(run(["print-disabled", "system"]).output)
    }
}
