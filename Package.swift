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
    ],
    targets: [
        .executableTarget(
            name: "MacCareApp",
            dependencies: ["ScanCore", "SafetyCore", "FileRules", "DesignSystem", "Persistence"]
        ),
        .target(name: "Persistence"),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
        .target(name: "ScanCore", dependencies: ["SafetyCore"]),
        .target(name: "SafetyCore"),
        .target(name: "FileRules", dependencies: ["ScanCore", "SafetyCore"]),
        .target(name: "DesignSystem"),
        .testTarget(name: "ScanCoreTests", dependencies: ["ScanCore"]),
        .testTarget(name: "SafetyCoreTests", dependencies: ["SafetyCore"]),
        .testTarget(name: "FileRulesTests", dependencies: ["FileRules"]),
    ]
)
