// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DisplaySwitch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "displayctl", targets: ["displayctl"]),
        .executable(name: "DisplaySwitch", targets: ["DisplaySwitch"]),
    ],
    targets: [
        .target(name: "DisplayCore"),
        .executableTarget(name: "displayctl", dependencies: ["DisplayCore"]),
        .executableTarget(name: "DisplaySwitch", dependencies: ["DisplayCore"]),
        .testTarget(name: "DisplayCoreTests", dependencies: ["DisplayCore"]),
    ],
    swiftLanguageModes: [.v5]
)
