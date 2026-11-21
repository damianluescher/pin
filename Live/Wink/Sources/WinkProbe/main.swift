import AppKit
import SwiftUI
import WinkBoards

// WinkProbe FOLDER: a fresh picture of every live Wink board in Pin, at its board size, for refresh-pictures.py
// (Pin shows a board's picture when zoomed out; stale pictures showed the old design).
let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let home = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/Pin/Wink")
let live = try! JSONSerialization.jsonObject(with: Data(contentsOf: home.appendingPathComponent("live.json"))) as! [String: Any]
let boards = live["boards"] as! [String: String]
let sizes = live["sizes"] as? [String: [String: Double]] ?? [:]
let only = Set(CommandLine.arguments.dropFirst(2))
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
MainActor.assumeIsolated {
    for (id, name) in boards.sorted(by: { $0.key < $1.key }) where only.isEmpty || only.contains(id) {
        let meta = (try? JSONSerialization.jsonObject(with: Data(contentsOf: home.appendingPathComponent("\(id)/screen.json")))) as? [String: Any]
        let phone = (meta?["kind"] as? String) == "iphone"
        let w = sizes[id]?["width"] ?? (phone ? 402 : 1280), h = sizes[id]?["height"] ?? (phone ? 874 : 820)
        let host = NSHostingView(rootView: WinkBoards.board(name).frame(width: w, height: h).environment(\.colorScheme, .dark))
        host.frame = NSRect(x: 0, y: 0, width: w, height: h)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { print("FAILED \(id)"); continue }
        host.cacheDisplay(in: host.bounds, to: rep)
        let png = rep.representation(using: .png, properties: [:])
        try? png?.write(to: out.appendingPathComponent("\(id).png"))
        print("ok \(id) \(Int(w))x\(Int(h))")
        window.contentView = nil
    }
}
