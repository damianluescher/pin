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
                        let env = ProcessInfo.processInfo.environment
                        // For checking: open a page and zoom first, e.g. PIN_PAGE=Screens PIN_ZOOM=8.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            if let app = env["PIN_APP"] { model.open(app) }
                            if let page = env["PIN_PAGE"] { model.choose(page: page) }
                            // For checking: PIN_RUN=1 opens the Run panel, PIN_RUN=<folder> runs that folder.
                            if let run = env["PIN_RUN"], let app = model.app {
                                model.run.open(app: app, store: model.store)
                                if run != "1" { model.run.choose(folder: run, store: model.store) }
                            }
                            // For checking: PIN_RUNLINK=<screen id> clicks that board's website open in the Run panel.
                            if let id = env["PIN_RUNLINK"], let screen = model.screens.first(where: { $0.id == id }) { model.openLink(screen) }
                            if let zoom = env["PIN_ZOOM"].flatMap(Double.init) {
                                model.zoom(by: zoom / model.scale, at: .zero)
                                // PIN_X and PIN_Y are measured from the first board's corner, in screen points.
                                let corner = model.placed.first?.rect.origin ?? .zero
                                model.look(scale: model.scale, origin: CGPoint(x: (env["PIN_X"].flatMap(Double.init) ?? 0) - corner.x * zoom,
                                                                               y: (env["PIN_Y"].flatMap(Double.init) ?? 0) - corner.y * zoom))
                            }
                        }
                        // For checking: PIN_FILM=FOLDER zooms in and out by small steps and saves a picture of each.
                        if let folder = env["PIN_FILM"] {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { Film(model: model, folder: folder).start() }
                        }
                        // For measuring: PIN_BENCH=1 moves the canvas for 5 seconds and writes how smooth it was.
                        if env["PIN_BENCH"] != nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { Bench.run(model) }
                        }
                        // For checking: PIN_PRESS=1 presses real boards with real window events. See PressCheck.
                        if env["PIN_PRESS"] != nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { PressCheck(model: model, folder: out).start() }
                        }
                        if env["PIN_PRESS"] == nil, env["PIN_FILM"] == nil { DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                            guard let frame = NSApp.windows.first(where: { $0.isVisible })?.contentView?.superview,
                                  let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { return }
                            frame.cacheDisplay(in: frame.bounds, to: rep)
                            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
                        } }
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
                Toggle("Show Flows", isOn: $model.showFlows)
            }
            CommandMenu("Tools") {
                Button("Comment (C)") { model.tool = .comment }
                Button("Cursor (A or Esc)") { model.tool = .move }
                Button("Press (P)") { model.tool = .press }
            }
        }
    }
}

/// The split is AppKit's on purpose. A screen pushing inside a live board would otherwise push into SwiftUI's
/// NavigationSplitView around it and replace the whole canvas (measured 1 Nov 2026).
struct RootSplit: NSViewControllerRepresentable {
    let sidebar: AnyView
    let detail: AnyView

    func makeNSViewController(context: Context) -> NSSplitViewController {
        let split = NSSplitViewController()
        let side = NSHostingController(rootView: sidebar), main = NSHostingController(rootView: detail)
        side.sizingOptions = []
        main.sizingOptions = []
        let item = NSSplitViewItem(sidebarWithViewController: side)
        item.minimumThickness = 230
        item.maximumThickness = 320
        split.addSplitViewItem(item)
        split.addSplitViewItem(NSSplitViewItem(viewController: main))
        return split
    }

    func updateNSViewController(_ split: NSSplitViewController, context: Context) {}
}

struct DetailColumn: View {
    @Environment(Model.self) private var model
    @AppStorage("showComments") private var showComments = true
    /// How wide he dragged the Run panel.
    @AppStorage("runWidth") private var runWidth: Double = 480

    var body: some View {
        if model.app == nil {
            ContentUnavailableView("No files yet", systemImage: "doc.on.doc", description: Text("Agents add screens with the pin command."))
        } else {
            HStack(spacing: 0) {
                Canvas()
                if model.run.isOpen {
                    RunEdge(width: $runWidth, range: 300...1600)
                    RunPanel(run: model.run).frame(width: runWidth)
                }
            }
                .onChange(of: model.app) { model.run.follow(app: model.app, store: model.store) }
                .inspector(isPresented: $showComments) {
                    CommentsPanel().inspectorColumnWidth(min: 260, ideal: 300, max: 400)
                }
        }
    }
}

struct RootView: View {
    @Environment(Model.self) private var model
    @AppStorage("showComments") private var showComments = true

    var body: some View {
        @Bindable var model = model
        RootSplit(sidebar: AnyView(SideList().environment(model).preferredColorScheme(.dark)),
                  detail: AnyView(DetailColumn().environment(model).preferredColorScheme(.dark)))
            .navigationTitle(model.app ?? "Pin")
            .navigationSubtitle(model.app == nil ? "" : model.page ?? "")
            .toolbar { tools }
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
        ToolbarItem(placement: .navigation) {
            Button { NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil) } label: {
                Label("Sidebar", systemImage: "sidebar.left")
            }
            .help("Sidebar")
        }
        if model.app != nil {
            ToolbarItem(placement: .principal) {
                Picker("Tool", selection: $model.tool) {
                    Label("Cursor", systemImage: "cursorarrow").tag(Tool.move).help("Cursor (A or Esc)")
                    Label("Comment", systemImage: "text.bubble").tag(Tool.comment).help("Comment (C)")
                    Label("Press", systemImage: "hand.point.up.left").tag(Tool.press).help("Press (P)")
                }
                .pickerStyle(.segmented).labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .primaryAction) {
                ZoomMenu()
            }
            ToolbarItem(placement: .primaryAction) {
                Button { if let app = model.app { model.run.toggle(app: app, store: model.store) } } label: {
                    Label("Run", systemImage: model.run.isOpen ? "stop.fill" : "play.fill")
                }
                .help("Run the real app or website beside the canvas")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showComments.toggle() } label: { Label("Comments", systemImage: "sidebar.right") }.help("Comments")
            }
        }
    }
}

/// Its own small view, so the toolbar around it is not redone as the zoom changes.
struct ZoomMenu: View {
    @Environment(Model.self) private var model

    var body: some View {
        @Bindable var model = model
        Menu("\(model.percent)%") {
            Button("Zoom In") { model.zoom(by: 1.25) }
            Button("Zoom Out") { model.zoom(by: 0.8) }
            Button("Actual Size") { model.actualSize() }
            Button("Fit Page") { model.fit() }
            Divider()
            Toggle("Show All Versions", isOn: $model.showAllVersions)
        }
        .monospacedDigit()
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
                        Button { model.reveal(screen); model.openLink(screen) } label: {
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

/// Moves the canvas once per screen frame, by the display's own clock, for 5 seconds at most. Reports the time between
/// frames, how many ran late, and what one camera step cost the main thread.
@MainActor
final class Bench: NSObject {
    private static var running: Bench?
    private let model: Model
    private let mode = ProcessInfo.processInfo.environment["PIN_BENCH"]
    private var gaps: [Double] = []
    private var costs: [Double] = []
    private var last = 0.0
    private var step = 0
    private var link: CADisplayLink?

    private init(_ model: Model) { self.model = model }

    static func run(_ model: Model) {
        let bench = Bench(model)
        running = bench
        guard let window = NSApp.windows.first(where: { $0.isVisible }), let view = window.contentView else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        let link = view.displayLink(target: bench, selector: #selector(frame))
        link.add(to: .main, forMode: .common)
        bench.link = link
    }

    @objc private func frame() {
        let now = CACurrentMediaTime()
        if last > 0 { gaps.append((now - last) * 1000) }
        last = now
        step += 1
        switch mode {
        case "zoom": model.zoom(by: step % 200 < 100 ? 1.02 : 0.98)
        // Across the page, so new live boards keep starting.
        case "sweep": model.pan(-16, 0)
        default: model.pan(sin(Double(step) / 20) * 6, 0)
        }
        CATransaction.flush()
        costs.append((CACurrentMediaTime() - now) * 1000)
        guard step >= 300 else { return }
        link?.invalidate()
        let sorted = gaps.sorted(), cost = costs.sorted()
        let typical = sorted[sorted.count / 2]
        let late = sorted.filter { $0 > typical * 1.5 }.count
        print("frames per second \(Int(Double(sorted.count) / sorted.reduce(0, +) * 1000)), typical \(String(format: "%.1f", typical)) ms, worst \(Int(sorted.last ?? 0)) ms, late \(late) of \(sorted.count); one step on the main thread: typical \(String(format: "%.2f", cost[cost.count / 2])) ms, worst \(String(format: "%.2f", cost.last ?? 0)) ms")
        fflush(stdout)
        exit(0)
    }
}

/// `PIN_SHOT=FOLDER PIN_PRESS=1 Pin`: goes through press mode once with real window events and prints what happened.
/// Pictures go to FOLDER. Needs PIN_HOME with app "10" and app "PressTest" (boards "page" and "gone", see the state card).
@MainActor
final class PressCheck {
    let model: Model
    let folder: String
    private var steps: [(Double, () -> Void)] = []

    init(model: Model, folder: String) {
        self.model = model
        self.folder = folder
    }

    private var window: NSWindow? { NSApp.windows.first { $0.isVisible && $0.contentView != nil } }

    private func say(_ text: String) { print("PRESS", text); fflush(stdout) }

    /// The window point of a spot on a board, given in the board's design units.
    private func spot(_ item: Placed, _ x: CGFloat, _ y: CGFloat) -> NSPoint? {
        guard let window, let canvas = eventView(in: window.contentView) else { return nil }
        let p = model.onScreen(CGPoint(x: item.rect.minX + x, y: item.rect.minY + y))
        return canvas.convert(p, to: nil)
    }

    private func eventView(in view: NSView?) -> NSView? {
        guard let view else { return nil }
        if view is CanvasEvents.EventView { return view }
        for child in view.subviews { if let found = eventView(in: child) { return found } }
        return nil
    }

    private func mouse(_ kind: NSEvent.EventType, _ at: NSPoint) {
        guard let window, let event = NSEvent.mouseEvent(with: kind, location: at, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1) else { return }
        NSApp.postEvent(event, atStart: false)
    }

    private func click(_ at: NSPoint?) {
        guard let at else { return say("no spot") }
        mouse(.leftMouseDown, at)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.mouse(.leftMouseUp, at) }
    }

    private func type(_ text: String) {
        guard let window else { return }
        for kind in [NSEvent.EventType.keyDown, .keyUp] {
            if let event = NSEvent.keyEvent(with: kind, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: text == "\u{1b}" ? 53 : 0) {
                NSApp.postEvent(event, atStart: false)
            }
        }
    }

    private func shoot(_ name: String) {
        guard let frame = window?.contentView?.superview, let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { return }
        frame.cacheDisplay(in: frame.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name + ".png"))
    }

    private func then(_ wait: Double = 0.8, _ work: @escaping () -> Void) { steps.append((wait, work)) }

    private func run() {
        guard !steps.isEmpty else { exit(0) }
        let (wait, work) = steps.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { MainActor.assumeIsolated { work(); self.run() } }
    }

    private func board(_ id: String) -> Placed? { model.placed.last { $0.screen.id == id } }
    private func page(_ id: String) -> WebBoardView? { LiveBoards.running("PressTest/\(id)-1") as? WebBoardView }

    func start() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        let env = ProcessInfo.processInfo.environment
        let swiftBoard = env["PIN_BOARD"] ?? "train", tabX = 322.0, tabY = 791.0
        // Today's Sleep, Train and Settings tabs in one real board, at a zoom that is not 100%.
        then(1) {
            guard let item = self.board(swiftBoard) else { return self.say("no board \(swiftBoard)") }
            self.model.reveal(item.screen)
            self.model.zoom(by: 0.83 / self.model.scale, at: .zero)
            self.model.tool = .press
            self.say("zoom \(self.model.scale) tool press, window key \(self.window?.isKeyWindow ?? false)")
        }
        then(2.5) { self.shoot("1-before") }
        then { if let item = self.board(swiftBoard) { self.click(self.spot(item, tabX, tabY)) } }
        then(1.2) { self.shoot("2-settings-tab") }
        then { if let item = self.board(swiftBoard) { self.click(self.spot(item, CGFloat(Double(env["PIN_ROW_X"] ?? "200") ?? 200), CGFloat(Double(env["PIN_ROW_Y"] ?? "230") ?? 230))) } }
        then(1.2) { self.shoot("3-pushed") }
        // Another tool: the same press must not reach the screen.
        then { self.model.tool = .move }
        then { if let item = self.board(swiftBoard) { self.click(self.spot(item, 72, tabY)) } }
        then(1.0) { self.shoot("4-cursor-no-press") }
        // Sharp at high zoom, and the press mapping does not care.
        then { self.model.zoom(by: 4 / self.model.scale, at: .zero); if let item = self.board(swiftBoard) { self.model.look(scale: 4, origin: CGPoint(x: 20 - item.rect.minX * 4, y: 20 - item.rect.minY * 4)) } }
        then(2) { self.shoot("4b-zoom4") }
        // Key: P comes back.
        then { self.type("p") }
        then { self.say("after P key tool press: \(self.model.tool == .press)") }
        // At high zoom a press must still land: the pushed screen's back arrow, then the look at what it did.
        then { self.say("back arrow at zoom 4"); if let item = self.board(swiftBoard) { self.click(self.spot(item, 38, 76)) } }
        then(1.2) { self.shoot("4c-back-at-zoom4") }
        // The comment tool places its dot at the exact spot, at any zoom.
        then {
            self.model.tool = .comment
            if let item = self.board(swiftBoard) { self.click(self.spot(item, 100, 50)) }
        }
        then {
            if let draft = self.model.draft { self.say("comment at \(draft.x * draft.placed.rect.width), \(draft.y * draft.placed.rect.height) (design spot 100,50)") } else { self.say("no comment dot") }
            self.model.draft = nil
            self.model.tool = .move
            // The cursor drags the board by 40 screen points, 10 canvas points at zoom 4.
            if let item = self.board(swiftBoard), let at = self.spot(item, 100, 50) {
                self.say("board at \(item.rect.origin)")
                self.mouse(.leftMouseDown, at)
                self.mouse(.leftMouseDragged, NSPoint(x: at.x + 20, y: at.y))
                self.mouse(.leftMouseDragged, NSPoint(x: at.x + 40, y: at.y))
                self.mouse(.leftMouseUp, NSPoint(x: at.x + 40, y: at.y))
            }
        }
        then {
            if let item = self.board(swiftBoard) { self.say("board dragged to \(item.rect.origin)") }
            self.model.tool = .press
        }
        // The web board.
        then { self.model.open("PressTest") }
        then(1) {
            guard let item = self.board("page") else { return self.say("no web board") }
            self.model.reveal(item.screen)
            self.model.zoom(by: 1.2 / self.model.scale, at: .zero)
        }
        then(2) {
            self.say("web loaded \(self.page("page")?.loaded ?? false), unreachable board loaded \(self.page("gone")?.loaded ?? false)")
            if let item = self.board("page") { self.click(self.spot(item, 150, 125)) }
        }
        then {
            self.page("page")?.evaluate("document.title") { self.say("web press: \($0 ?? "nil") (design spot 150,125)") }
            if let item = self.board("page") { self.click(self.spot(item, 120, 210)) }
        }
        then { self.say("first responder in board: \(LiveBoards.board(holding: self.window?.firstResponder) != nil)"); self.type("a") }
        then { self.type("c") }
        then {
            self.say("while typing tool still press: \(self.model.tool == .press)")
            self.page("page")?.evaluate("document.getElementById('i').value") { self.say("typed: \($0 ?? "nil")") }
            self.type("\u{1b}")
        }
        then {
            self.say("after synthetic Esc tool cursor: \(self.model.tool == .move)")
            self.model.tool = .move
            if let item = self.board("page") { self.click(self.spot(item, 150, 165)) }
        }
        then {
            self.page("page")?.evaluate("window.lower ? 'pressed' : 'not pressed'") { self.say("cursor tool, page button: \($0 ?? "nil")") }
            self.model.zoom(by: 6 / self.model.scale, at: .zero)
            if let item = self.board("page") { self.model.look(scale: 6, origin: CGPoint(x: 40 - item.rect.minX * 6, y: 40 - item.rect.minY * 6)) }
        }
        then(1.5) {
            self.page("page")?.evaluate("'zoom 6: dpr ' + devicePixelRatio + ' layout width ' + innerWidth") { self.say("\($0 ?? "nil")") }
            self.page("page")?.snapshotSource.takeSnapshot(with: nil) { image, _ in
                MainActor.assumeIsolated {
                    guard let data = image?.tiffRepresentation, let rep = NSBitmapImageRep(data: data) else { return self.say("no web picture") }
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: self.folder).appendingPathComponent("5-web-zoom6.png"))
                    self.say("web picture \(rep.pixelsWide)x\(rep.pixelsHigh)")
                }
            }
        }
        then(1) { self.say("done"); exit(0) }
        run()
    }
}
