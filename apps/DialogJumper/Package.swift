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
            dependencies: ["DialogJumperCore"],
            // AppKit UI types are MainActor-isolated under Swift 6; this target is
            // intentionally not fully annotated @MainActor (timer + AX callbacks).
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "DialogJumperCoreTests",
            dependencies: ["DialogJumperCore"]
        ),
    ]
)
