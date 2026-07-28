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
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "6.3.2"),
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
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "MalwareEngineTests", dependencies: ["MalwareEngine", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "AppDiscoveryTests", dependencies: ["AppDiscovery", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "SafetyCore", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "SystemMetricsTests", dependencies: ["SystemMetrics", .product(name: "Testing", package: "swift-testing")]),
        .target(name: "ScanCore", dependencies: ["SafetyCore"]),
        .target(name: "SafetyCore"),
        .target(name: "FileRules", dependencies: ["ScanCore", "SafetyCore"]),
        .target(name: "DesignSystem"),
        .testTarget(name: "ScanCoreTests", dependencies: ["ScanCore", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "SafetyCoreTests", dependencies: ["SafetyCore", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "FileRulesTests", dependencies: ["FileRules", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "CoreTendAppTests", dependencies: ["CoreTendApp", .product(name: "Testing", package: "swift-testing")]),
    ]
)
