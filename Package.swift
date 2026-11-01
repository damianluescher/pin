// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pin",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pin", targets: ["Pin"]),
        .executable(name: "pincli", targets: ["pincli"]),
    ],
    targets: [
        .target(name: "PinCore"),
        .executableTarget(name: "Pin", dependencies: ["PinCore"]),
        .executableTarget(name: "pincli", dependencies: ["PinCore"]),
        .testTarget(name: "PinCoreTests", dependencies: ["PinCore"]),
    ]
)
