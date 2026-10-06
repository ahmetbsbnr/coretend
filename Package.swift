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
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .executable(name: "CoreTendApp", targets: ["CoreTendApp"]),
        .executable(name: "CoreTendCLI", targets: ["CoreTendCLI"])],
    // Sparkle: the one runtime dependency, for signed updates the person can turn off (decision 0005).
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")],
    targets: [
        .target(name: "ProductContract"),
        .target(name: "SafetyCore"),
        .target(name: "ScanCore", dependencies: ["ProductContract"]),
        .target(name: "AppShell"),
        .target(name: "DesignSystem"),
        .target(name: "Domain", dependencies: ["ProductContract", "SafetyCore", "Persistence"]),
        .executableTarget(name: "CoreTendApp", dependencies: ["AppShell", "DesignSystem", "ProductContract", "Persistence", "ScanCore", "Domain",
                                                              .product(name: "Sparkle", package: "Sparkle")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-reproducible", "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .target(name: "CLIContract", dependencies: ["Persistence", "ScanCore", "Domain", "SafetyCore"]),
        .executableTarget(name: "CoreTendCLI", dependencies: ["CLIContract"],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-reproducible"], .when(configuration: .release))]),
        .systemLibrary(name: "CSQLite", path: "Sources/CSQLite"),
        .target(name: "Persistence", dependencies: ["CSQLite"]),
        .testTarget(name: "ProductContractTests", dependencies: ["ProductContract"]),
        .testTarget(name: "SafetyCoreTests", dependencies: ["SafetyCore"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "CSQLite"]),
        .testTarget(name: "ScanCoreTests", dependencies: ["ScanCore"]),
        .testTarget(name: "AppShellTests", dependencies: ["AppShell"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain", "SafetyCore", "Persistence"]),
        .testTarget(name: "CLIContractTests", dependencies: ["CLIContract", "SafetyCore", "ScanCore"])
    ]
)
