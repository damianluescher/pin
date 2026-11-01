import AppKit
import SwiftUI
import TenBoards

// A test window: python-free proof that the real screen draws, normal size and at 800%.
struct Probe: View {
    let scale: CGFloat
    let name: String
    var body: some View {
        TenBoards.board(name)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: 393, height: 852, alignment: .topLeading)
            .clipped()
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let args = CommandLine.arguments
let scale = args.count > 1 ? CGFloat(Double(args[1]) ?? 1) : 1
let name = args.count > 2 ? args[2] : "Today"
MainActor.assumeIsolated {
    let w = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 393, height: 852), styleMask: [.titled], backing: .buffered, defer: false)
    w.title = "TenProbe"
    w.contentView = NSHostingView(rootView: Probe(scale: scale, name: name))
    w.makeKeyAndOrderFront(nil)
    if let path = ProcessInfo.processInfo.environment["PROBE_SHOT"] {
        DispatchQueue.main.asyncAfter(deadline: .now() + (Double(ProcessInfo.processInfo.environment["PROBE_DELAY"] ?? "") ?? 2.5)) {
            let v = w.contentView!
            let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
            v.cacheDisplay(in: v.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            exit(0)
        }
    }
}
app.activate(ignoringOtherApps: true)
app.run()
