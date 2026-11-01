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
                .onAppear {
                    model.start()
                                        if let out = ProcessInfo.processInfo.environment["PIN_SHOT"] {
                        // A picture of the whole real window with its toolbar, for checking the look.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            guard let frame = NSApp.windows.first(where: { $0.isVisible })?.contentView?.superview,
                                  let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { return }
                            frame.cacheDisplay(in: frame.bounds, to: rep)
                            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
                        }
                    }
                }
        }
        .windowToolbarStyle(.unified)
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
            }
        }
    }
}

struct RootView: View {
    @Environment(Model.self) private var model
    @AppStorage("showComments") private var showComments = true

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SideList().navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 320)
        } detail: {
            Group {
                if model.app == nil {
                    ContentUnavailableView("No files yet", systemImage: "doc.on.doc", description: Text("Agents add screens with the pin command."))
                } else {
                    Canvas()
                        .inspector(isPresented: $showComments) {
                            CommentsPanel().inspectorColumnWidth(min: 260, ideal: 300, max: 400)
                        }
                }
            }
            .navigationTitle(model.app ?? "Pin")
            .navigationSubtitle(model.app == nil ? "" : model.page ?? "")
            .toolbar { tools }
        }
        .overlay(alignment: .bottom) {
            if let failure = model.failure {
                Text(failure).font(Style.body).padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.45, green: 0.12, blue: 0.12)))
                    .padding(Style.gap)
            }
        }
    }

    @ToolbarContentBuilder private var tools: some ToolbarContent {
        @Bindable var model = model
        if model.app != nil {
            ToolbarItem(placement: .principal) {
                Picker("Tool", selection: $model.tool) {
                    Label("Cursor", systemImage: "cursorarrow").tag(Tool.move).help("Cursor (A or Esc)")
                    Label("Comment", systemImage: "text.bubble").tag(Tool.comment).help("Comment (C)")
                }
                .pickerStyle(.segmented).labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu("\(Int(model.scale * 100))%") {
                    Button("Zoom In") { model.zoom(by: 1.25) }
                    Button("Zoom Out") { model.zoom(by: 0.8) }
                    Button("Actual Size") { model.actualSize() }
                    Button("Fit Page") { model.fit() }
                    Divider()
                    Toggle("Show All Versions", isOn: $model.showAllVersions)
                }
                .monospacedDigit()
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showComments.toggle() } label: { Label("Comments", systemImage: "sidebar.right") }.help("Comments")
            }
        }
    }
}

/// The real Mac sidebar: files, or a file's pages and boards.
struct SideList: View {
    @Environment(Model.self) private var model

    var body: some View {
        List(selection: pageSelection) {
            Section("Files") {
                ForEach(model.apps, id: \.self) { name in
                    Button { model.open(name) } label: {
                        Label {
                            HStack {
                                Text(name).lineLimit(1).fontWeight(name == model.app ? .semibold : .regular)
                                Spacer(minLength: 0)
                                let open = model.openCount(app: name)
                                if open > 0 { Text("\(open)").font(.caption).foregroundStyle(.secondary) }
                            }
                        } icon: { Image(systemName: name == model.app ? "doc.fill" : "doc") }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([model.store.home.appendingPathComponent(name)])
                        }
                    }
                }
            }
            if model.app != nil {
                Section("Pages") {
                    ForEach(model.pages, id: \.self) { name in Label(name, systemImage: "rectangle.on.rectangle").tag(name) }
                }
                Section("Boards") {
                    ForEach(model.pageScreens) { screen in
                        Button { model.reveal(screen) } label: {
                            Label {
                                HStack {
                                    Text(screen.name).lineLimit(1)
                                    Spacer(minLength: 0)
                                    if let last = screen.latest, last.n > 1 { Text("v\(last.n)").font(.caption).foregroundStyle(.secondary) }
                                }
                            } icon: { Image(systemName: icon(screen.kind)) }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var pageSelection: Binding<String?> {
        Binding(get: { model.page }, set: { if let name = $0 { model.choose(page: name) } })
    }

    private func icon(_ kind: Kind) -> String {
        switch kind {
        case .iphone: "iphone"
        case .mac: "macwindow"
        case .web: "globe"
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
