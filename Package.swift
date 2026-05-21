// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CTTPulse",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "CTTPulse", targets: ["CTTPulseApp"]),
        .library(name: "CTTPulseCore", targets: ["CTTPulseCore"])
    ],
    targets: [
        .target(
            name: "CTTPulseCore",
            path: "Sources/CTTPulseCore"
        ),
        .executableTarget(
            name: "CTTPulseApp",
            dependencies: ["CTTPulseCore"],
            path: "Sources/CTTPulseApp"
        ),
        .testTarget(
            name: "CTTPulseCoreTests",
            dependencies: ["CTTPulseCore"],
            path: "Tests/CTTPulseCoreTests"
        )
    ]
)
