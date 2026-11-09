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
        // A rebuilt library shows by itself (Damian, 9 Nov 2026: "pin is not refreshing").
        if let path = config?.library, libraries[path] != nil, isNewBuild(path) {
            DispatchQueue.main.async { refreshSwiftBoards() }
        }
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

    /// Reloads every web board that is running or kept, for the toolbar's Refresh (Damian, 3 Nov: "refresh boards manually").
    static func refreshWebBoards() {
        var done = Set<ObjectIdentifier>()
        for weak in onCanvas.values { if let web = weak.board as? WebBoardView, done.insert(ObjectIdentifier(web)).inserted { web.reloadPage() } }
        for web in WebBoards.allKept() where done.insert(ObjectIdentifier(web)).inserted { web.reloadPage() }
    }

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
    static var keptScreens: [String: SwiftBoardView] = [:]

    private static func library(_ path: String) -> UnsafeMutableRawPointer? {
        if let open = libraries[path] { return open }
        guard let open = openCopy(path) else { return nil }
        libraries[path] = open
        return open
    }

    /// When each library was built, as loaded.
    private static var builds: [String: Date] = [:]

    private static func built(_ path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    /// A newer build than the one loaded, finished writing (a second old), so a half-written file is never opened.
    private static func isNewBuild(_ path: String) -> Bool {
        guard let date = built(path), date != builds[path] else { return false }
        return Date().timeIntervalSince(date) > 1
    }

    /// dlopen keeps the first image it opened for a path, so each build is opened from its own copy.
    private static func openCopy(_ path: String) -> UnsafeMutableRawPointer? {
        let date = built(path) ?? Date()
        // Beside the original, so the library still finds its resource bundle (Bundle.module looks next to itself).
        let folder = URL(fileURLWithPath: (path as NSString).deletingLastPathComponent, isDirectory: true)
        let name = (path as NSString).lastPathComponent
        let prefix = ".pin-copy-"
        let copy = folder.appendingPathComponent("\(prefix)\(Int(date.timeIntervalSince1970 * 1000))-\(name)")
        // Older copies of this library are not needed once a new one is made.
        for old in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        where old.hasPrefix(prefix) && old.hasSuffix(name) && old != copy.lastPathComponent {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(old))
        }
        if !FileManager.default.fileExists(atPath: copy.path) {
            do { try FileManager.default.copyItem(atPath: path, toPath: copy.path) } catch {
                NSLog("Pin: could not copy live boards: %@", error.localizedDescription)
                return nil
            }
        }
        guard let open = dlopen(copy.path, RTLD_NOW | RTLD_LOCAL) else {
            NSLog("Pin: could not load live boards: %@", String(cString: dlerror()))
            return nil
        }
        builds[path] = date
        return open
    }

    /// Opens rebuilt libraries and starts their boards again from the new code. Runs on Refresh and when a build lands.
    static func refreshSwiftBoards() {
        var changed = false
        for path in libraries.keys where isNewBuild(path) {
            guard let fresh = openCopy(path) else { continue }
            libraries[path] = fresh
            changed = true
        }
        guard changed else { return }
        views.removeAll()
        keptScreens.removeAll()
        for (key, weak) in onCanvas where weak.board is SwiftBoardView {
            (weak.board?.superview as? BoardView)?.setLive(nil)
            onCanvas[key] = nil
        }
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

/// SwiftUI places a click by its distance in the window from the host's corner, ignoring the camera's magnification, so a
/// click would land at the unzoomed spot (measured 1 Nov 2026). AppKit does know the zoom, so each mouse event is handed on
/// with the window location SwiftUI needs for the point AppKit found.
private final class CameraHost: NSHostingView<AnyView> {
    private func unzoomed(_ event: NSEvent) -> NSEvent {
        let point = convert(event.locationInWindow, from: nil)
        let corner = convert(bounds.origin, to: nil)
        let place = NSPoint(x: corner.x + point.x, y: corner.y - point.y)
        return NSEvent.mouseEvent(with: event.type, location: place, modifierFlags: event.modifierFlags, timestamp: event.timestamp,
                                  windowNumber: event.windowNumber, context: nil, eventNumber: event.eventNumber,
                                  clickCount: event.clickCount, pressure: event.pressure) ?? event
    }
    override func mouseDown(with event: NSEvent) { super.mouseDown(with: unzoomed(event)) }
    override func mouseDragged(with event: NSEvent) { super.mouseDragged(with: unzoomed(event)) }
    override func mouseUp(with event: NSEvent) { super.mouseUp(with: unzoomed(event)) }
    override func rightMouseDown(with event: NSEvent) { super.rightMouseDown(with: unzoomed(event)) }
    override func rightMouseUp(with event: NSEvent) { super.rightMouseUp(with: unzoomed(event)) }
}

/// A live screen on the canvas, at its design size for good. The camera does the enlarging; once the zoom has settled,
/// every layer inside is told to draw at the zoom's sharpness, so nothing stays a small bitmap blown up.
final class SwiftBoardView: NSView, PressableBoard {
    private weak var host: NSView?
    private let key: String
    private var drawn: CGFloat = 0
    private var again: DispatchWorkItem?
    private var routing = false

    /// A screen he pressed earlier keeps its place; otherwise a new one starts.
    static func make(key: String, view: AnyView, design: CGSize) -> SwiftBoardView {
        let board = LiveBoards.keptScreens[key] ?? SwiftBoardView(key: key, view: view, design: design)
        LiveBoards.register(board, key: key)
        return board
    }

    private init(key: String, view: AnyView, design: CGSize) {
        self.key = key
        super.init(frame: CGRect(origin: .zero, size: design))
        let host = CameraHost(rootView: AnyView(view.frame(width: design.width, height: design.height)))
        host.sizingOptions = []
        // A board passing under the toolbar must not get pushed down by the window's safe area.
        host.safeAreaRegions = []
        host.autoresizingMask = [.width, .height]
        host.frame = bounds
        wantsLayer = true
        addSubview(host)
        self.host = host
        // The screen fills in its numbers just after it starts: the picture under it shows until then, so no flicker.
        host.alphaValue = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak host] in
            // A fade, because the old picture can differ a little from what the code draws now.
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                host?.animator().alphaValue = 1
            }
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { nil }

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

    /// Only called once the zoom has stopped.
    func sharpen(zoom: CGFloat) {
        apply((window?.backingScaleFactor ?? 2) * max(zoom, 1))
    }

    private func apply(_ scale: CGFloat) {
        again?.cancel()
        guard let root = host?.layer else { return }
        drawn = scale
        Self.walk(root, scale)
        // Zoomed in, a screen adds layers as its data arrives, so keep the new ones sharp too.
        guard scale > (window?.backingScaleFactor ?? 2) else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.window != nil else { return }
            self.apply(self.drawn)
        }
        again = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private static func walk(_ layer: CALayer, _ scale: CGFloat) {
        // A photo's layer already holds its full picture, and asking it to redraw would leave it empty.
        // SwiftUI's Canvas/shape layers (RenderBox) go blank the same way when told to redraw from outside
        // (Damian, 9 Nov 2026: the LUT Cam ruler's ticks vanished on zoom); they only get the new scale.
        let kind = String(describing: type(of: layer))
        let isPhoto = kind == "ImageLayer"
        let isRenderBox = kind.hasPrefix("RB")
        if kind == "RBSurfaceContentsLayer" {
            // drawn by its parent; leave it alone
        } else if !isPhoto, layer.contentsScale != scale {
            layer.contentsScale = scale
            if !isRenderBox { layer.setNeedsDisplay() }
        }
        layer.sublayers?.forEach { walk($0, scale) }
    }
}

// MARK: Web boards

/// Which web pages run, and which pressed ones stay alive after leaving the view.
@MainActor
enum WebBoards {
    /// Pages are whole browsers: more than this at once and the canvas stops being smooth.
    static let runningCap = 6
    static let keptCap = 8
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
    static func allKept() -> [WebBoardView] { kept.map(\.view) }

    static func keep(_ view: WebBoardView, key: String) {
        kept.removeAll { $0.key == key }
        kept.append((key, view))
        if kept.count > keptCap { kept.removeFirst() }
    }
}

/// A web page, at its design size for good: the camera does the enlarging. WebKit draws sharp only when it knows the zoom,
/// and telling it means laying the page out again, which is slow and blanks it. So only after the zoom has stopped, and only
/// when the zoom needs a different drawing size (1x, 2x, 4x, 8x), a real snapshot of the page covers it, the page redraws
/// behind that, and the cover goes once the page has really drawn. Blank parts of a page show the picture underneath, never
/// white. WKWebView's own magnification does not work here: the page just lays out wider. Web pages draw only in a real app
/// bundle, so check this from a bundle, not the bare build.
final class WebBoardView: NSView, PressableBoard, WKNavigationDelegate {
    private let key: String
    private let page: WebBoard
    private let web: WKWebView
    /// Shows the page's drawing size in the board's own size.
    private let stretch = NSView()
    private let cover = PictureView()
    private let design: CGSize
    private var drawnAt: CGFloat = 1
    private var wanted: CGFloat = 1
    private var redrawing = false
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

    /// With a mouse attached the Mac reserves 16 points for a page's scrollbar. Each redraw makes a page overflow for a moment,
    /// a scrollbar appears, and centred content moves sideways by it until the next layout (measured: scrollWidth 1278 of
    /// 1280 at 8x). A board is a picture of a screen, so its page shows no scrollbar of its own; scrolling still works.
    private static let noBarScript = """
    (function () {
      const style = document.createElement('style');
      style.textContent = 'html::-webkit-scrollbar, body::-webkit-scrollbar { display: none; }';
      document.documentElement.appendChild(style);
    })();
    """

    /// The page he left keeps its place; otherwise a new one starts.
    static func make(key: String, page: WebBoard, design: CGSize) -> WebBoardView {
        let board = WebBoards.keptView(key) ?? WebBoardView(key: key, page: page, design: design)
        LiveBoards.register(board, key: key)
        return board
    }

    /// A fresh load from the server, skipping the cache; the picture underneath covers it until the page has drawn.
    func reloadPage() { web.reloadFromOrigin() }

    private init(key: String, page: WebBoard, design: CGSize) {
        self.key = key
        self.page = page
        self.design = design
        let config = WKWebViewConfiguration()
        config.websiteDataStore = page.persistent == true ? .default() : .nonPersistent()
        let focus = Focus()
        config.userContentController.add(focus, name: "pinFocus")
        config.userContentController.addUserScript(WKUserScript(source: Self.focusScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(source: Self.noBarScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame: CGRect(origin: .zero, size: design), configuration: config)
        super.init(frame: CGRect(origin: .zero, size: design))
        focus.board = self
        wantsLayer = true
        // Where a page has not drawn yet, the picture underneath shows instead of WebKit's white.
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = self
        // The picture under it shows until the page has really loaded, so an unreachable page simply stays a picture.
        web.alphaValue = 0
        stretch.frame = bounds
        stretch.addSubview(web)
        addSubview(stretch)
        cover.frame = bounds
        cover.isHidden = true
        addSubview(cover)
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

    private static func level(for zoom: CGFloat) -> CGFloat { [1, 2, 4, 8].first { $0 >= zoom } ?? 8 }

    /// Only called once the zoom has stopped, for pages on screen.
    func sharpen(zoom: CGFloat) {
        wanted = Self.level(for: zoom)
        guard loaded, !redrawing, wanted != drawnAt else { return }
        redrawing = true
        let shot = WKSnapshotConfiguration()
        shot.snapshotWidth = NSNumber(value: Double(min(web.frame.width, 2880)))
        web.takeSnapshot(with: shot) { [weak self] image, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // No picture of the old drawing means nothing safe to hide behind: stay soft rather than risk showing white.
                guard let image, let before = Likeness(image) else { self.redrawing = false; return }
                self.redraw(behind: image, before: before)
            }
        }
    }

    private func redraw(behind image: NSImage, before: Likeness) {
        cover.show(image)
        cover.isHidden = false
        CATransaction.flush()
        let level = wanted, size = CGSize(width: design.width * level, height: design.height * level)
        // Two changes, so the page lays out once in between. Always the narrower way: wider for a moment would shorten its
        // scrolling parts and throw away where they were scrolled to (measured on Foundable's chat, 1 Nov 2026).
        let growing = level > drawnAt
        if growing { web.pageZoom = level }
        web.frame = CGRect(origin: .zero, size: size)
        if !growing { web.pageZoom = level }
        stretch.setBoundsSize(size)
        drawnAt = level
        whenDrawn(like: before, tries: 15) { [weak self] in
            guard let self else { return }
            self.cover.isHidden = true
            self.cover.clear()
            self.redrawing = false
            // He may have zoomed on while this ran.
            if self.wanted != self.drawnAt { self.sharpen(zoom: self.wanted) }
        }
    }

    /// Waits until the page has painted two frames and a fresh picture of it looks like the old one, then once more for
    /// the screen to catch up. A page that really changed meanwhile ends the wait after a second and a half.
    private func whenDrawn(like before: Likeness, tries: Int, done: @escaping @MainActor () -> Void) {
        let finish = { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { MainActor.assumeIsolated { done() } } }
        web.callAsyncJavaScript("await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(() => r(1))))", in: nil, in: .page) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let small = WKSnapshotConfiguration()
                small.snapshotWidth = NSNumber(value: Likeness.width)
                self.web.takeSnapshot(with: small) { [weak self] image, _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        if let image, Likeness(image)?.matches(before) == true { return finish() }
                        guard tries > 0 else { return finish() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                            MainActor.assumeIsolated { self?.whenDrawn(like: before, tries: tries - 1, done: done) }
                        }
                    }
                }
            }
        }
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
        // Shown only once it has painted, so the page's first blank frame stays hidden.
        web.callAsyncJavaScript("await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(() => r(1))))", in: nil, in: .page) { [weak self] _ in
            MainActor.assumeIsolated { if self?.loaded == true { self?.web.alphaValue = 1 } }
        }
        // Coming back into view should not mean loading the page again.
        WebBoards.keep(self, key: key)
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

/// A tiny grey copy of a picture of a page, to tell whether two pictures show the same thing.
private struct Likeness {
    static let width = 64
    private let values: [UInt8]

    init?(_ image: NSImage) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil), cg.width > 0 else { return nil }
        let height = max(cg.height * Self.width / cg.width, 1)
        var pixels = [UInt8](repeating: 0, count: Self.width * height)
        let made: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: Self.width, height: height, bitsPerComponent: 8, bytesPerRow: Self.width,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(cg, in: CGRect(x: 0, y: 0, width: Self.width, height: height))
            return true
        }
        guard made else { return nil }
        values = pixels
    }

    func matches(_ other: Likeness) -> Bool {
        guard values.count == other.values.count else { return false }
        let total = zip(values, other.values).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return total / max(values.count, 1) < 6
    }
}
