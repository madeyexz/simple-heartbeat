// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleHeartbeat",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SimpleHeartbeat",
            dependencies: ["HeartbeatCore"],
            path: "Sources/App"
        ),
        .target(
            name: "HeartbeatCore",
            path: "Sources/Core"
        ),
        .testTarget(
            name: "HeartbeatCoreTests",
            dependencies: ["HeartbeatCore"],
            path: "Tests"
        ),
    ]
)
