// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreTend",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CoreTend", targets: ["CoreTendApp"]),
        .library(name: "ScanCore", targets: ["ScanCore"]),
        .library(name: "SafetyCore", targets: ["SafetyCore"]),
        .library(name: "FileRules", targets: ["FileRules"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "SystemMetrics", targets: ["SystemMetrics"]),
        .library(name: "AppDiscovery", targets: ["AppDiscovery"]),
        .library(name: "MalwareEngine", targets: ["MalwareEngine"]),
    ],
    targets: [
        .executableTarget(
            name: "CoreTendApp",
            dependencies: ["ScanCore", "SafetyCore", "FileRules", "DesignSystem", "Persistence", "SystemMetrics", "AppDiscovery", "MalwareEngine"],
            resources: [.process("Resources")]
        ),
        .target(name: "Persistence", dependencies: ["SafetyCore"]),
        .target(name: "SystemMetrics"),
        .target(name: "AppDiscovery"),
        .target(name: "MalwareEngine"),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "MalwareEngineTests", dependencies: ["MalwareEngine"]),
        .testTarget(name: "AppDiscoveryTests", dependencies: ["AppDiscovery"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "SafetyCore"]),
        .testTarget(name: "SystemMetricsTests", dependencies: ["SystemMetrics"]),
        .target(name: "ScanCore", dependencies: ["SafetyCore"]),
        .target(name: "SafetyCore"),
        .target(name: "FileRules", dependencies: ["ScanCore", "SafetyCore"]),
        .target(name: "DesignSystem"),
        .testTarget(name: "ScanCoreTests", dependencies: ["ScanCore"]),
        .testTarget(name: "SafetyCoreTests", dependencies: ["SafetyCore"]),
        .testTarget(name: "FileRulesTests", dependencies: ["FileRules"]),
        .testTarget(name: "CoreTendAppTests", dependencies: ["CoreTendApp"]),
    ]
)
