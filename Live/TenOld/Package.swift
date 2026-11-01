// swift-tools-version:5.9
import PackageDescription

// The old Ten's real screens as a library for Pin. App/, Design/ and Shared/ are links to phone-renew's own code. The few
// files that cannot be used as they are come out of sync.py into Generated/, freshly on each build. Shim/ is Pin's.
let package = Package(
    name: "TenOldBoards",
    platforms: [.macOS("26.0")],
    products: [.library(name: "TenOldBoards", type: .dynamic, targets: ["TenOldBoards"])],
    targets: [
        .target(name: "TenOldBoards",
                exclude: ["App/Info.plist", "App/Assets.xcassets", "App/Sounds", "App/TenApp.swift", "App/WeekView.swift",
                          "App/LibraryView.swift", "App/PlayerView.swift", "App/ProgressView.swift",
                          "Design/DemoClipView.swift", "Shared/VideoCatalog.swift"]),
    ]
)
