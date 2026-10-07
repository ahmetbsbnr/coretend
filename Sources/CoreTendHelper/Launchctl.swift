import Foundation
import HelperProtocol

/// The one program the helper runs, with arguments it builds itself.
enum Launchctl {
    /// Runs `/bin/launchctl` and returns its exit status and standard output.
    static func run(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
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
