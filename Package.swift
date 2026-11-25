// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pin",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pin", targets: ["Pin"]),
        .library(name: "PinKit", targets: ["PinKit"]),
        .executable(name: "pincli", targets: ["pincli"]),
    ],
    targets: [
        .target(name: "PinCore"),
        .target(name: "PinKit", dependencies: ["PinCore"]),
        .executableTarget(name: "Pin", dependencies: ["PinKit"]),
        .executableTarget(name: "pincli", dependencies: ["PinCore"]),
        .testTarget(name: "PinCoreTests", dependencies: ["PinCore"]),
    ]
)
