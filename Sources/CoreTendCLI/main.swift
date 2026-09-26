import Foundation
import Darwin
import CLIContract

@main
enum CoreTendCLI {
    static func main() async {
        do {
            let command = try CLICommand.parse(Array(CommandLine.arguments.dropFirst()))
            let status = await CoreTendCLIRunner.run(command) { line in print(line) }
            exit(status)
        } catch CLIError.storePathRequired {
            fputs("Provide --store PATH. The CLI never guesses a user store location.\n", stderr)
            exit(2)
        } catch {
            fputs("Invalid or unsupported command. Run 'coretend help'.\n", stderr)
            exit(2)
        }
    }
}
