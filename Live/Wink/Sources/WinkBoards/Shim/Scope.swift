import SwiftUI
import AppKit

// A board's own picture settings. wink2 reads its WINK_* hooks from the process's environment, which would be one set
// for all boards and Pin's own besides. Inside this library ProcessInfo is this stand-in: each board answers for itself.
enum BoardEnv {
    @TaskLocal static var current: [String: String] = base
    /// A picture only looks: never asks for notifications, never marks a chat read.
    static let base = ["WINK_SNAPSHOT": "1"]
}

struct ProcessInfo {
    static let processInfo = ProcessInfo()
    var environment: [String: String] { BoardEnv.current }
}

/// Leaves Pin's keys and mouse alone: nothing watches them, the monitor simply is not made.
enum NoEvents {
    static func addLocalMonitorForEvents(matching mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) -> Any? { nil }
}

/// wink2's pictures live in its asset catalogue, which Pin's bundle does not have.
extension Image {
    init(_ name: String) {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("tools/wink2/App/Assets.xcassets/\(name).imageset")
        let file = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?.first { $0.pathExtension != "json" }
        self.init(nsImage: file.flatMap(NSImage.init(contentsOf:)) ?? NSImage())
    }
}

/// The board's own window content: its keyboard shortcuts stay out of Pin, it never takes the keyboard, and everything
/// SwiftUI works out for it happens with this board's settings.
struct BoardScene: NSViewRepresentable {
    let env: [String: String]
    let content: AnyView

    final class Host: NSHostingView<AnyView> {
        var env: [String: String] = BoardEnv.base
        override var acceptsFirstResponder: Bool { false }
        override func performKeyEquivalent(with event: NSEvent) -> Bool { false }
        override func layout() { BoardEnv.$current.withValue(env) { super.layout() } }
        override func updateConstraints() { BoardEnv.$current.withValue(env) { super.updateConstraints() } }
        override func viewWillDraw() { BoardEnv.$current.withValue(env) { super.viewWillDraw() } }
        override func viewDidMoveToWindow() { BoardEnv.$current.withValue(env) { super.viewDidMoveToWindow() } }
    }

    func makeNSView(context: Context) -> Host {
        let host = Host(rootView: AnyView(EmptyView()))
        host.env = env
        host.sizingOptions = []
        host.appearance = NSAppearance(named: .darkAqua)
        BoardEnv.$current.withValue(env) { host.rootView = content }
        return host
    }

    func updateNSView(_ host: Host, context: Context) {}
}

/// The window's three buttons belong to macOS, not to Wink, so they are drawn here. Unfocused grey, as on the boards.
struct WindowDots: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in Circle().fill(Color.white.opacity(0.22)).frame(width: 12, height: 12) }
        }
        .padding(.leading, 20).padding(.top, 20)
        .allowsHitTesting(false)
    }
}

struct PhoneStatusBar: View {
    var body: some View {
        HStack {
            Text("9:41").font(.system(size: 17, weight: .semibold)).frame(width: 90)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 15, weight: .semibold)).frame(width: 90)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 54)
        .overlay { Capsule().fill(.black).frame(width: 126, height: 37) }
        .allowsHitTesting(false)
    }
}

/// Settings a board can read but never save. Not Wink's own: this is Pin's process, so they stand at their defaults.
enum WinkPreferences {
    static let defaults: UserDefaults = ReadOnly()

    private final class ReadOnly: UserDefaults {
        override func set(_ value: Any?, forKey defaultName: String) {}
        override func set(_ value: Bool, forKey defaultName: String) {}
        override func removeObject(forKey defaultName: String) {}
    }
}
