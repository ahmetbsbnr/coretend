// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors

import Foundation
import FileRules

/// Read-only command-line surface for automation and inspection.
/// Destructive operations remain in the reviewed SwiftUI flow.
@main
struct CoreTendCLI {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        switch arguments.first {
        case nil, "--help", "-h": printHelp()
        case "--list-rules": listRules()
        case "--paths": listPaths()
        default:
            fputs("Unknown option. Use --help.\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func printHelp() {
        print("""
        coretend-cli — read-only inspection

        Usage:
          coretend-cli --list-rules   List cleanup rules and risk levels
          coretend-cli --paths        Print user-scoped rule roots
          coretend-cli --help         Show this help

        No command deletes files or changes system state.
        """)
    }

    private static func listRules() {
        for rule in UserCleanupRules.all {
            print("\(rule.id)\t\(rule.name)\t\(rule.risk)")
        }
    }

    private static func listPaths() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        for root in UserCleanupRules.allowedRoots(home: home) {
            print(root.path)
        }
    }
}
