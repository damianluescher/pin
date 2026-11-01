import Foundation
import AppKit
import PinCore
import SwiftUI
import WebKit

/// Boards that are real running screens instead of pictures. An app opts in with a `live.json` beside its screens,
/// naming the library built from its code and which board is which screen.
@MainActor
enum LiveBoards {
    private static var libraries: [String: UnsafeMutableRawPointer] = [:]
    private static var views: [String: AnyView] = [:]

    private typealias Make = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer

    /// The screen's design size, or nil when this board is only a picture.
    static func size(app: String, screen: String, store: Store) -> CGSize? {
        guard let live = config(app, store), live.boards[screen] != nil || live.webBoard(screen) != nil else { return nil }
        return live.size(of: screen).cgSize
    }

    static func swiftBoard(app: String, screen: String, store: Store) -> Bool {
        config(app, store)?.boards[screen] != nil
    }

    static func web(app: String, screen: String, store: Store) -> WebBoard? {
        config(app, store)?.webBoard(screen)
    }

    static func hasWeb(app: String, store: Store) -> Bool {
        config(app, store)?.hasWeb ?? false
    }

    /// This is asked for every board on every frame, so the file is read at most every couple of seconds.
    private static func config(_ app: String, _ store: Store) -> LiveConfig? {
        let now = Date()
        if let known = configs[app], now.timeIntervalSince(known.read) < 2 { return known.config }
        let config = store.live(app: app)
        configs[app] = (now, config)
        return config
    }
    private static var configs: [String: (read: Date, config: LiveConfig?)] = [:]

    static func view(app: String, screen: String, store: Store) -> AnyView? {
        guard let live = config(app, store), let name = live.boards[screen] else { return nil }
        let key = "\(app)/\(screen)"
        if let known = views[key] { return known }
        guard let library = library(live.library), let symbol = dlsym(library, "pin_board") else { return nil }
        let make = unsafeBitCast(symbol, to: Make.self)
        let made = name.withCString { make($0) }.assumingMemoryBound(to: AnyView.self)
        let view = made.move()
        made.deallocate()
        views[key] = view
        return view
    }

    /// Whether a board on screen runs live at this width. Small boards keep their picture, so a zoomed-out page stays
    /// light. It switches on and off at different widths, so a board at the edge cannot flip back and forth.
    static func runs(_ key: String, shownAt width: CGFloat) -> Bool {
        let on = running.contains(key) ? width >= 270 : width >= 300
        if on { running.insert(key) } else { running.remove(key) }
        return on
    }
    private static var running: Set<String> = []

    // MARK: Boards on the canvas

    private final class Weak { weak var board: (NSView & PressableBoard)?; init(_ board: NSView & PressableBoard) { self.board = board } }
    private static var onCanvas: [String: Weak] = [:]

    static func register(_ board: NSView & PressableBoard, key: String) { onCanvas[key] = Weak(board) }

    /// The running board with this key, when it is in the window right now.
    static func running(_ key: String) -> (NSView & PressableBoard)? {
        guard let board = onCanvas[key]?.board, board.window != nil else { return nil }
        return board
    }

    /// The board a responder sits inside, if any.
    static func board(holding responder: NSResponder?) -> (NSView & PressableBoard)? {
        var view = responder as? NSView
        while let current = view {
            if let board = current as? (NSView & PressableBoard) { return board }
            view = current.superview
        }
        return nil
    }

    /// Screens he has pressed keep their own place (tab, pushed screen, scroll) after they leave the view.
    /// Ones he never touched are simply started again, so a long page holds nothing it does not need.
    static var keptScreens: [String: LiveHost.Container] = [:]

    private static func library(_ path: String) -> UnsafeMutableRawPointer? {
        if let open = libraries[path] { return open }
        guard let open = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
            NSLog("Pin: could not load live boards: %@", String(cString: dlerror()))
            return nil
        }
        libraries[path] = open
        return open
    }
}

private extension LiveConfig.Size {
    var cgSize: CGSize { CGSize(width: width, height: height) }
}

/// A board that can take input in press mode. Everywhere else it takes none.
@MainActor
protocol PressableBoard: AnyObject {
    /// The view inside the board at this window point, or nil if the board cannot take input yet.
    func pressTarget(inWindow spot: NSPoint) -> NSView?
    /// Whether keys typed now belong to this board instead of Pin's shortcuts.
    func isTyping(_ responder: NSResponder?) -> Bool
}

/// The zoom a live screen is drawn at. Only the small view below reads it, so a change does not rerun the screen.
final class BoardZoom: ObservableObject {
    @Published var value: CGFloat
    init(_ value: CGFloat) { self.value = value }
}

/// SwiftUI's own scale, because SwiftUI places clicks by its own transforms: scaling its host through view bounds
/// looks right but lands every click at the unscaled spot (measured 1 Nov 2026).
struct ScaledScreen: View {
    let screen: AnyView
    let design: CGSize
    @ObservedObject var zoom: BoardZoom

    var body: some View {
        screen
            .frame(width: design.width, height: design.height)
            .scaleEffect(zoom.value, anchor: .topLeading)
            .frame(width: design.width * zoom.value, height: design.height * zoom.value, alignment: .topLeading)
    }
}

/// A live screen on the canvas. It keeps laying out at its design size; the enlarging happens in ScaledScreen, and
/// every layer inside is told to draw at the zoom's sharpness, so nothing is a small bitmap blown up.
struct LiveHost: NSViewRepresentable {
    let key: String
    let view: AnyView
    let design: CGSize
    let zoom: CGFloat

    func makeNSView(context: Context) -> Container {
        if let kept = LiveBoards.keptScreens[key] {
            LiveBoards.register(kept, key: key)
            return kept
        }
        let scale = BoardZoom(zoom)
        let host = NSHostingView(rootView: ScaledScreen(screen: view, design: design, zoom: scale))
        host.sizingOptions = []
        // A board passing under the toolbar must not get pushed down by the window's safe area.
        host.safeAreaRegions = []
        host.autoresizingMask = [.width, .height]
        let box = Container()
        box.key = key
        box.scale = scale
        box.wantsLayer = true
        box.frame.size = CGSize(width: design.width * zoom, height: design.height * zoom)
        host.frame = box.bounds
        box.addSubview(host)
        box.host = host
        LiveBoards.register(box, key: key)
        // The screen fills in its numbers just after it starts: the picture under it shows until then, so no flicker.
        host.alphaValue = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak host] in host?.alphaValue = 1 }
        return box
    }

    func updateNSView(_ box: Container, context: Context) {
        guard box.design != design || box.zoom != zoom else { return }
        box.design = design
        box.zoom = zoom
        box.frame.size = CGSize(width: design.width * zoom, height: design.height * zoom)
        box.scale?.value = zoom
        box.sharpen(zoom: zoom)
    }

    final class Container: NSView, PressableBoard {
        weak var host: NSView?
        var key = ""
        var scale: BoardZoom?
        var design = CGSize.zero
        var zoom: CGFloat = 0
        private var drawn: CGFloat = 0
        private var pending: DispatchWorkItem?
        private var routing = false

        override var isFlipped: Bool { true }
        /// Takes no input unless the canvas's press tool asks for it.
        override func hitTest(_ point: NSPoint) -> NSView? { routing ? super.hitTest(point) : nil }

        func pressTarget(inWindow spot: NSPoint) -> NSView? {
            guard let superview else { return nil }
            routing = true
            defer { routing = false }
            let target = super.hitTest(superview.convert(spot, from: nil))
            if target != nil, let kind = NSApp.currentEvent?.type, [.leftMouseDown, .scrollWheel, .keyDown].contains(kind) {
                LiveBoards.keptScreens[key] = self
            }
            return target
        }

        func isTyping(_ responder: NSResponder?) -> Bool { responder is NSText }

        override func viewDidMoveToWindow() {
            // A kept screen comes back with its layers at the screen's sharpness, and new layers wait for this.
            if window != nil, zoom > 0 { sharpen(zoom: zoom) }
        }

        /// Redrawing is the slow part, so it waits until the zoom has settled for a moment.
        func sharpen(zoom: CGFloat) {
            let backing = (window?.backingScaleFactor ?? 2) * max(zoom, 1)
            pending?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.apply(backing) }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }

        private func apply(_ scale: CGFloat) {
            guard let root = host?.layer else { return }
            drawn = scale
            Self.walk(root, scale)
            // Zoomed in, a screen adds layers as its data arrives, so keep the new ones sharp too.
            guard scale > (window?.backingScaleFactor ?? 2) else { return }
            let again = DispatchWorkItem { [weak self] in
                guard let self, self.window != nil else { return }
                self.apply(self.drawn)
            }
            pending = again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: again)
        }

        private static func walk(_ layer: CALayer, _ scale: CGFloat) {
            // A photo's layer already holds its full picture, and asking it to redraw would leave it empty.
            let isPhoto = String(describing: type(of: layer)) == "ImageLayer"
            if !isPhoto, layer.contentsScale != scale {
                layer.contentsScale = scale
                layer.setNeedsDisplay()
            }
            layer.sublayers?.forEach { walk($0, scale) }
        }
    }
}

// MARK: Web boards

/// Which web pages run, and which pressed ones stay alive after leaving the view.
@MainActor
enum WebBoards {
    /// Pages are whole browsers: more than this at once and the canvas stops being smooth.
    static let runningCap = 6
    static let keptCap = 4
    private static var runningNow: Set<String> = []
    private static var kept: [(key: String, view: WebBoardView)] = []

    /// Ones already running stay, so boards do not trade places; the rest go by how much of them shows.
    static func choose(_ shown: [(key: String, area: CGFloat)]) -> Set<String> {
        let staying = shown.filter { runningNow.contains($0.key) }
        let rest = shown.filter { !runningNow.contains($0.key) }.sorted { $0.area > $1.area }
        runningNow = Set((staying + rest).prefix(runningCap).map(\.key))
        return runningNow
    }

    static func keptView(_ key: String) -> WebBoardView? { kept.first { $0.key == key }?.view }

    static func keep(_ view: WebBoardView, key: String) {
        kept.removeAll { $0.key == key }
        kept.append((key, view))
        if kept.count > keptCap { kept.removeFirst() }
    }
}

struct WebHost: NSViewRepresentable {
    let key: String
    let page: WebBoard
    let design: CGSize
    let zoom: CGFloat

    func makeNSView(context: Context) -> WebBoardView {
        let view = WebBoards.keptView(key) ?? WebBoardView(key: key, page: page, design: design, zoom: zoom)
        LiveBoards.register(view, key: key)
        return view
    }

    func updateNSView(_ view: WebBoardView, context: Context) { view.show(design: design, zoom: zoom) }
}

/// A web page at its design size. WebKit draws sharp only when it knows the zoom, so at rest the web view is the board's
/// full size with its page zoom set to match: the page keeps its layout width and draws every pixel. While the zoom is
/// still changing the old drawing is stretched through the bounds, since laying the page out on each step is too slow.
final class WebBoardView: NSView, PressableBoard, WKNavigationDelegate {
    private let key: String
    private let page: WebBoard
    private let web: WKWebView
    private var design: CGSize
    private var zoom: CGFloat
    private var settling: DispatchWorkItem?
    private var retry: DispatchWorkItem?
    private var routing = false
    private var editing = false
    private(set) var loaded = false

    /// WebKit holds its message handlers strongly, so this one holds the board weakly.
    private final class Focus: NSObject, WKScriptMessageHandler {
        weak var board: WebBoardView?
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            MainActor.assumeIsolated { board?.editing = message.body as? Bool ?? false }
        }
    }

    /// Tells Pin when the cursor is in a text field, because Pin cannot see inside the page.
    private static let focusScript = """
    (function () {
      const typing = (el) => !!el && (el.isContentEditable || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' ||
        (el.tagName === 'INPUT' && !['button', 'checkbox', 'radio', 'submit', 'reset', 'range', 'color', 'file'].includes(el.type)));
      const tell = (on) => window.webkit.messageHandlers.pinFocus.postMessage(on);
      document.addEventListener('focusin', (e) => tell(typing(e.target)), true);
      document.addEventListener('focusout', () => tell(false), true);
    })();
    """

    init(key: String, page: WebBoard, design: CGSize, zoom: CGFloat) {
        self.key = key
        self.page = page
        self.design = design
        self.zoom = zoom
        let config = WKWebViewConfiguration()
        config.websiteDataStore = page.persistent == true ? .default() : .nonPersistent()
        let focus = Focus()
        config.userContentController.add(focus, name: "pinFocus")
        config.userContentController.addUserScript(WKUserScript(source: Self.focusScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame: CGRect(x: 0, y: 0, width: design.width * zoom, height: design.height * zoom), configuration: config)
        super.init(frame: web.frame)
        focus.board = self
        wantsLayer = true
        web.navigationDelegate = self
        web.pageZoom = zoom
        // The picture under it shows until the page has really loaded, so an unreachable page simply stays a picture.
        web.alphaValue = 0
        addSubview(web)
        load()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { routing ? super.hitTest(point) : nil }

    func pressTarget(inWindow spot: NSPoint) -> NSView? {
        guard loaded, let superview else { return nil }
        routing = true
        defer { routing = false }
        let target = super.hitTest(superview.convert(spot, from: nil))
        if target != nil, let kind = NSApp.currentEvent?.type, [.leftMouseDown, .scrollWheel, .keyDown].contains(kind) {
            WebBoards.keep(self, key: key)
        }
        return target
    }

    func isTyping(_ responder: NSResponder?) -> Bool { editing }

    func show(design: CGSize, zoom: CGFloat) {
        guard design != self.design || zoom != self.zoom else { return }
        self.design = design
        self.zoom = zoom
        frame.size = CGSize(width: design.width * zoom, height: design.height * zoom)
        // Until the zoom settles, the web view keeps its size and the bounds stretch it to fit.
        setBoundsSize(web.frame.size)
        settling?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.setBoundsSize(self.frame.size)
            self.web.frame = self.bounds
            self.web.pageZoom = self.zoom
        }
        settling = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    override func viewDidMoveToWindow() {
        if window != nil, !loaded { load() }
        if window == nil { retry?.cancel() }
    }

    private func load() {
        retry?.cancel()
        guard let address = page.address else { return }
        if address.isFileURL {
            web.loadFileURL(address, allowingReadAccessTo: address.deletingLastPathComponent())
        } else {
            web.load(URLRequest(url: address))
        }
    }

    /// Back to the picture, and look again shortly: the server may just not be up yet. Stops once off screen.
    private func failed() {
        loaded = false
        web.alphaValue = 0
        retry?.cancel()
        guard window != nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.window != nil else { return }
            self.load()
        }
        retry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        web.alphaValue = 1
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed() }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failed() }

    /// The page may move around its own app, but a board never wanders off to the internet.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        let isPage = action.targetFrame?.isMainFrame ?? true
        decisionHandler(!isPage || action.request.url.map(WebBoard.allows) == true ? .allow : .cancel)
    }

    /// A server's error page is not the board: show the picture instead.
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        let bad = response.isForMainFrame && ((response.response as? HTTPURLResponse)?.statusCode ?? 200) >= 400
        decisionHandler(bad ? .cancel : .allow)
    }

    /// For the press check.
    func evaluate(_ script: String, _ done: @escaping @MainActor (Any?) -> Void) {
        web.evaluateJavaScript(script) { value, _ in MainActor.assumeIsolated { done(value) } }
    }
    var snapshotSource: WKWebView { web }
}
