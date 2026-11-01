// swift-tools-version:5.9
import PackageDescription

// 10's real screens, built for the Mac so Pin can show them live. The Ten folder is a link to the app's own code;
// only Shim/ is Pin's: the Mac stand-ins for iPhone-only calls, and made-up data in place of the strap and database.
let noop = "../../../noop2/Packages/"
let package = Package(
    name: "TenBoards",
    platforms: [.macOS(.v14)],
    products: [.library(name: "TenBoards", type: .dynamic, targets: ["TenBoards"])],
    dependencies: [
        .package(path: noop + "StrandAnalytics"),
        .package(path: noop + "StrandDesign"),
        .package(path: noop + "StrandImport"),
        .package(path: noop + "WhoopProtocol"),
        .package(path: noop + "WhoopStore"),
    ],
    targets: [
        .target(name: "TenBoards",
                dependencies: ["StrandAnalytics", "StrandDesign", "StrandImport", "WhoopProtocol", "WhoopStore"],
                exclude: ["Ten/Clips", "Ten/Sounds", "Ten/Shell/TenDebug.swift", "Ten/Plan/VideoCatalog.swift"]),
        .executableTarget(name: "TenProbe", dependencies: ["TenBoards"]),
    ]
)
