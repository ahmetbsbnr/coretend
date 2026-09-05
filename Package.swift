// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreTend",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CoreTend", targets: ["CoreTend"]),
        .executable(name: "coretend-cli", targets: ["CoreTendCLI"]),
        .library(name: "ScanCore", targets: ["ScanCore"]),
        .library(name: "SafetyCore", targets: ["SafetyCore"]),
        .library(name: "FileRules", targets: ["FileRules"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "SystemMetrics", targets: ["SystemMetrics"]),
        .library(name: "AppDiscovery", targets: ["AppDiscovery"]),
        .library(name: "IntegrityCore", targets: ["IntegrityCore"]),
        // Exposed as a product so the Xcode shipping host can link the
        // existing app implementation instead of forking it. `swift build`
        // still builds the `CoreTend` executable from the same target.
        .library(name: "CoreTendApp", targets: ["CoreTendApp"]),
        // Tiny value+IO layer shared by the app (writer) and the WidgetKit
        // extension (reader). Foundation only — the widget target links this
        // and nothing that could scan or delete.
        .library(name: "WidgetShared", targets: ["WidgetShared"]),
        // Tiny value+classification+validation layer shared by the app
        // (handoff consumer) and the Finder Sync extension. Foundation only
        // — the Finder extension links this and nothing that could scan,
        // inspect file contents, or delete.
        .library(name: "FinderShared", targets: ["FinderShared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "CoreTend",
            dependencies: ["CoreTendApp"]
        ),
        .executableTarget(
            name: "CoreTendCLI",
            dependencies: ["FileRules"]
        ),
        .target(
            name: "CoreTendApp",
            dependencies: ["ScanCore", "SafetyCore", "FileRules", "DesignSystem", "Persistence", "SystemMetrics", "AppDiscovery", "IntegrityCore", "WidgetShared", "FinderShared"],
            resources: [.process("Resources")]
        ),
        .target(name: "WidgetShared", resources: [.process("Resources")]),
        .target(name: "FinderShared", resources: [.process("Resources")]),
        .target(name: "Persistence", dependencies: ["SafetyCore"]),
        .target(name: "SystemMetrics"),
        .target(name: "AppDiscovery"),
        .target(name: "IntegrityCore"),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "IntegrityCoreTests", dependencies: ["IntegrityCore", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "AppDiscoveryTests", dependencies: ["AppDiscovery", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "SafetyCore", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "SystemMetricsTests", dependencies: ["SystemMetrics", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "WidgetSharedTests", dependencies: ["WidgetShared", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "FinderSharedTests", dependencies: ["FinderShared", .product(name: "Testing", package: "swift-testing")]),
        .target(name: "ScanCore", dependencies: ["SafetyCore"]),
        .target(name: "SafetyCore"),
        .target(name: "FileRules", dependencies: ["ScanCore", "SafetyCore"]),
        .target(name: "DesignSystem"),
        .testTarget(name: "ScanCoreTests", dependencies: ["ScanCore", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "SafetyCoreTests", dependencies: ["SafetyCore", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "FileRulesTests", dependencies: ["FileRules", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "CoreTendAppTests", dependencies: ["CoreTendApp", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "CoreTendIntegrationTests", dependencies: ["CoreTendApp", "ScanCore", "SafetyCore", "Persistence", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "CoreTendUITests", dependencies: []),
        .testTarget(name: "CoreTendAccessibilityTests", dependencies: ["CoreTendApp", .product(name: "Testing", package: "swift-testing")]),
        .testTarget(name: "CoreTendPerformanceTests", dependencies: ["ScanCore", .product(name: "Testing", package: "swift-testing")]),
    ]
)
