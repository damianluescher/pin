// swift-tools-version:5.9
import PackageDescription

// AutoBalance's real interface as a library for Pin. native/ is a link to the app's own code. Model.swift and
// ContentView.swift come out of sync.py into Generated/, so no worker can start. Shim/ is Pin's: made-up shots, the board table.
let package = Package(
    name: "AutoBalanceBoards",
    platforms: [.macOS("15.0")],
    products: [.library(name: "AutoBalanceBoards", type: .dynamic, targets: ["AutoBalanceBoards"])],
    targets: [
        .target(name: "AutoBalanceBoards",
                exclude: ["native/AutoBalance.swift", "native/Model.swift", "native/ContentView.swift"]),
    ]
)
