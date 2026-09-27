import Foundation
import Darwin
import Dispatch
import CLIContract

@main
enum CoreTendCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let language = CLILanguage.bestEffort(from: arguments)
        do {
            let invocation = try CLIInvocation.parse(arguments)
            let command = invocation.command
            let writer: @Sendable (String) -> Void = { line in print(line) }
            let status: Int32
            if case .scan = command {
                status = await runScanWithInterruptHandling(command, language: invocation.language, write: writer)
            } else {
                status = await CoreTendCLIRunner.run(command, language: invocation.language, write: writer)
            }
            exit(status)
        } catch CLIError.storePathRequired {
            fputs(CLIError.storePathRequired.message(in: language) + "\n", stderr)
            exit(2)
        } catch let error as CLIError {
            fputs(error.message(in: language) + "\n", stderr)
            exit(2)
        } catch {
            fputs(CLIError.unsupportedCommand.message(in: language) + "\n", stderr)
            exit(2)
        }
    }

    private static func runScanWithInterruptHandling(
        _ command: CLICommand,
        language: CLILanguage,
        write: @escaping @Sendable (String) -> Void
    ) async -> Int32 {
        let previousHandler = Darwin.signal(SIGINT, SIG_IGN)
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global(qos: .userInitiated))
        let scanTask = Task { await CoreTendCLIRunner.run(command, language: language, write: write) }
        signalSource.setEventHandler { scanTask.cancel() }
        signalSource.resume()

        let status = await scanTask.value
        signalSource.cancel()
        _ = Darwin.signal(SIGINT, previousHandler)
        return status
    }
}
