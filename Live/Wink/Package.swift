// swift-tools-version:5.9
import PackageDescription

// Wink's real screens as a library for Pin. App/ and Engine/ are links to wink2's own code. The few files that cannot be
// used as they are (the engine connection, the app's entry point, keyboard and focus grabs) come out of sync.py into
// Generated/, freshly from wink2 on each build. Shim/ is Pin's: a made-up engine, made-up data, the board table.
let package = Package(
    name: "WinkBoards",
    platforms: [.macOS("26.0")],
    products: [.library(name: "WinkBoards", type: .dynamic, targets: ["WinkBoards"])],
    targets: [
        .target(name: "WinkBoards",
                exclude: ["App/Info.plist", "App/Assets.xcassets", "App/Model.swift", "App/Wink2.swift", "App/Design.swift",
                          "App/Composer.swift", "App/Review.swift", "App/Reply.swift"]),
    ]
)
