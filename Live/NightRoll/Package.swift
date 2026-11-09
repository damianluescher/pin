// swift-tools-version:5.9
import PackageDescription

// Night Roll's real screens, built for the Mac so Pin can show them live. Sources/NightRollBoards/UI is a link to the
// app's own App/UI (design worktree, read only); only Boards.swift is Pin's: which screen in which state, made-up data
// from App/UI/Samples.swift, taps that move between states. No engine, camera or lock is ever started here.
let package = Package(
    name: "NightRollBoards",
    platforms: [.macOS("15.0")],
    products: [.library(name: "NightRollBoards", type: .dynamic, targets: ["NightRollBoards"])],
    targets: [
        // The printed camera's pictures (App/UI/Art), found by NRArt through Bundle.module.
        .target(name: "NightRollBoards", resources: [.process("UI/Art")]),
        .executableTarget(name: "NightRollProbe", dependencies: ["NightRollBoards"]),
    ]
)
