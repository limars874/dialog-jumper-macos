// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DialogJumper",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DialogJumper", targets: ["DialogJumper"]),
        .library(name: "DialogJumperCore", targets: ["DialogJumperCore"]),
    ],
    targets: [
        .target(name: "DialogJumperCore"),
        .executableTarget(
            name: "DialogJumper",
            dependencies: ["DialogJumperCore"]
        ),
        .testTarget(
            name: "DialogJumperCoreTests",
            dependencies: ["DialogJumperCore"]
        ),
    ]
)
