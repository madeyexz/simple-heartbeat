// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleHeartbeat",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SimpleHeartbeat",
            path: "Sources"
        )
    ]
)
