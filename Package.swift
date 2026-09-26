// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreTend",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ProductContract", targets: ["ProductContract"]),
        .library(name: "SafetyCore", targets: ["SafetyCore"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "ScanCore", targets: ["ScanCore"]),
        .library(name: "AppShell", targets: ["AppShell"]),
        .library(name: "Domain", targets: ["Domain"]),
        .executable(name: "CoreTendApp", targets: ["CoreTendApp"]),
        .executable(name: "CoreTendCLI", targets: ["CoreTendCLI"])],
    targets: [
        .target(name: "ProductContract"),
        .target(name: "SafetyCore"),
        .target(name: "ScanCore", dependencies: ["ProductContract", "SafetyCore"]),
        .target(name: "AppShell"),
        .target(name: "Domain", dependencies: ["ProductContract", "SafetyCore", "Persistence"]),
        .executableTarget(name: "CoreTendApp", dependencies: ["AppShell", "ProductContract", "Persistence", "ScanCore", "Domain"]),
        .target(name: "CLIContract", dependencies: ["Persistence", "ScanCore", "Domain"]),
        .executableTarget(name: "CoreTendCLI", dependencies: ["CLIContract"]),
        .systemLibrary(name: "CSQLite", path: "Sources/CSQLite"),
        .target(name: "Persistence", dependencies: ["CSQLite"]),
        .testTarget(name: "ProductContractTests", dependencies: ["ProductContract"]),
        .testTarget(name: "SafetyCoreTests", dependencies: ["SafetyCore"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "CSQLite"]),
        .testTarget(name: "ScanCoreTests", dependencies: ["ScanCore"]),
        .testTarget(name: "AppShellTests", dependencies: ["AppShell"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain", "SafetyCore", "Persistence"]),
        .testTarget(name: "CLIContractTests", dependencies: ["CLIContract"])
    ]
)
