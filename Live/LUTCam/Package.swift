// swift-tools-version:5.9
import PackageDescription

// LUT Cam's real screens, built for the Mac so Pin can show them live. Sources/LUTCamBoards/UI links to
// ~/tools/lutcam/App/UI (read only); only Boards.swift is Pin's. No camera or engine is ever started here.
let package = Package(
    name: "LUTCamBoards",
    platforms: [.macOS("15.0")],
    products: [.library(name: "LUTCamBoards", type: .dynamic, targets: ["LUTCamBoards"])],
    targets: [
        .target(name: "LUTCamBoards", exclude: ["UI/Art/SOURCES.txt", "UI/Art/Samples/SOURCES.txt"], resources: [.process("UI/Art")]),
        .executableTarget(name: "LUTCamProbe", dependencies: ["LUTCamBoards"]),
    ]
)
