// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacCareLocal",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacCareLocal", targets: ["MacCareApp"]),
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
            name: "MacCareApp",
            dependencies: ["ScanCore", "SafetyCore", "FileRules", "DesignSystem", "Persistence", "SystemMetrics", "AppDiscovery", "MalwareEngine"]
        ),
        .target(name: "Persistence"),
        .target(name: "SystemMetrics"),
        .target(name: "AppDiscovery"),
        .target(name: "MalwareEngine"),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "MalwareEngineTests", dependencies: ["MalwareEngine"]),
        .testTarget(name: "AppDiscoveryTests", dependencies: ["AppDiscovery"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
        .testTarget(name: "SystemMetricsTests", dependencies: ["SystemMetrics"]),
        .target(name: "ScanCore", dependencies: ["SafetyCore"]),
        .target(name: "SafetyCore"),
        .target(name: "FileRules", dependencies: ["ScanCore", "SafetyCore"]),
        .target(name: "DesignSystem"),
        .testTarget(name: "ScanCoreTests", dependencies: ["ScanCore"]),
        .testTarget(name: "SafetyCoreTests", dependencies: ["SafetyCore"]),
        .testTarget(name: "FileRulesTests", dependencies: ["FileRules"]),
    ]
)
