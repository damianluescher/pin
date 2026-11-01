import AppKit
import PinCore
import SwiftUI

@main
struct PinApp: App {
    @State private var model = Model()

    init() {
        if CommandLine.arguments.contains("--snapshot") { Snapshot.run(); exit(0) }
    }

    var body: some Scene {
        WindowGroup("Pin") {
            RootView()
                .environment(model)
                .frame(minWidth: 1000, minHeight: 640)
                .preferredColorScheme(.dark)
                .onAppear { model.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 920)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Zoom In") { model.zoom(by: 1.25) }.keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") { model.zoom(by: 0.8) }.keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { model.actualSize() }.keyboardShortcut("0", modifiers: .command)
                Button("Fit Page") { model.fit() }.keyboardShortcut("1", modifiers: .command)
                Divider()
                Toggle("Show Resolved Comments", isOn: $model.showResolved)
                Toggle("Show All Versions", isOn: $model.showAllVersions)
            }
            CommandMenu("Tools") {
                Button("Comment (C)") { model.tool = .comment }
                Button("Cursor (A or Esc)") { model.tool = .move }
                Divider()
                Button("All Files") { model.closeFile() }.keyboardShortcut("[", modifiers: .command).disabled(model.app == nil)
            }
        }
    }
}

struct RootView: View {
    @Environment(Model.self) private var model
    var body: some View {
        Group {
            if model.app == nil { FilesPage() } else { Workspace() }
        }
        .overlay(alignment: .bottom) {
            if let failure = model.failure {
                Text(failure).font(Style.body).foregroundStyle(Style.ink).padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.45, green: 0.12, blue: 0.12)))
                    .padding(Style.gap)
            }
        }
    }
}

/// `Pin --snapshot OUT.png [--app A] [--page P] [--select ID] [--click X Y] [--text T]` draws the real views off screen, for checking the look.
enum Snapshot {
    @MainActor static func run() {
        let args = CommandLine.arguments
        func value(_ flag: String, _ shift: Int = 1) -> String? { args.firstIndex(of: flag).flatMap { $0 + shift < args.count ? args[$0 + shift] : nil } }
        guard let out = value("--snapshot") else { return }
        let model = Model()
        model.viewport = CGSize(width: 1440 - 240 - 300, height: 920)
        model.reload()
        if let app = value("--app") { model.open(app) }
        if let page = value("--page") { model.choose(page: page) }
        if let id = value("--select"), let thread = model.allThreads.first(where: { $0.id == id }) { model.selected = thread.id }
        if let x = value("--click").flatMap(Double.init), let y = value("--click", 2).flatMap(Double.init) { model.click(at: CGPoint(x: x, y: y)) }
        let view = NSHostingView(rootView: RootView().environment(model).preferredColorScheme(.dark))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 920), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.7))
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
    }
}
