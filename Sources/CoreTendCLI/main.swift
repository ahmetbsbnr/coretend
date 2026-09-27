import Foundation
import Darwin
import Dispatch
import CLIContract

@main
enum CoreTendCLI {
    static func main() async {
        do {
            let command = try CLICommand.parse(Array(CommandLine.arguments.dropFirst()))
            let writer: @Sendable (String) -> Void = { line in print(line) }
            let status: Int32
            if case .scan = command {
                status = await runScanWithInterruptHandling(command, write: writer)
            } else {
                status = await CoreTendCLIRunner.run(command, write: writer)
            }
            exit(status)
        } catch CLIError.storePathRequired {
            fputs("Provide --store PATH. The CLI never guesses a user store location.\n", stderr)
            exit(2)
        } catch {
            fputs("Invalid or unsupported command. Run 'coretend help'.\n", stderr)
            exit(2)
        }
    }

    private static func runScanWithInterruptHandling(
        _ command: CLICommand,
        write: @escaping @Sendable (String) -> Void
    ) async -> Int32 {
        let previousHandler = Darwin.signal(SIGINT, SIG_IGN)
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global(qos: .userInitiated))
        let scanTask = Task { await CoreTendCLIRunner.run(command, write: write) }
        signalSource.setEventHandler { scanTask.cancel() }
        signalSource.resume()

        let status = await scanTask.value
        signalSource.cancel()
        _ = Darwin.signal(SIGINT, previousHandler)
        return status
    }
}
