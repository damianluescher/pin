import AppKit
import Observation
import PinCore

/// One picture placed on the canvas. Canvas units are points of the real screen.
struct Placed: Identifiable, Equatable {
    let screen: Screen
    let version: Version
    let rect: CGRect
    var id: String { "\(screen.id)-\(version.n)" }
}

enum Tool { case comment, move }

/// What a new comment points at until it has its text.
struct Draft: Equatable {
    let placed: Placed
    let x: Double
    let y: Double
}

/// The app's state. Rereads the files every two seconds, so what an agent writes shows up by itself.
@MainActor @Observable final class Model {
    let store = Store()
    var apps: [String] = []
    /// The open file; nil shows the files page.
    var app: String?
    var screens: [Screen] = []
    var threads: [String: [PinThread]] = [:]
    var failure: String?

    var page: String?
    var tool = Tool.comment
    var scale: CGFloat = 0.5
    var origin = CGPoint.zero
    var viewport = CGSize(width: 800, height: 600)
    var selected: String?
    var draft: Draft?
    var showResolved = false
    var showAllVersions = false

    /// Stays fitted while the window settles or resizes, until he moves or zooms himself.
    var keepFitted = true
    private var timer: Timer?

    func start() {
        reload()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    func reload() {
        let found = store.apps()
        if found != apps { apps = found }
        guard let app else { return }
        do {
            let list = try store.screens(app: app)
            if list != screens { screens = list }
            var next: [String: [PinThread]] = [:]
            for screen in list { next[screen.id] = try store.threads(app: app, screen: screen.id) }
            if next != threads { threads = next }
            if page == nil || !pages.contains(page ?? "") { page = pages.first }
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    func open(_ name: String) {
        app = name
        page = nil
        selected = nil
        draft = nil
        reload()
        fit()
    }

    func closeFile() {
        app = nil
        screens = []
        threads = [:]
        selected = nil
        draft = nil
    }

    func choose(page name: String) {
        page = name
        selected = nil
        draft = nil
        fit()
    }

    // MARK: Pages and places

    var pages: [String] {
        var seen: [String] = []
        for screen in screens where !seen.contains(screen.pageName) { seen.append(screen.pageName) }
        return seen
    }

    var pageScreens: [Screen] { screens.filter { $0.pageName == page } }

    /// Boards left to right in rows, each with the version before it on its left, as on a design canvas.
    var placed: [Placed] {
        var out: [Placed] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        let gap: CGFloat = 80, limit: CGFloat = 3600
        for screen in pageScreens {
            let versions = showAllVersions ? screen.versions : Array(screen.versions.suffix(2))
            var block: [(Version, CGSize)] = []
            for version in versions { block.append((version, size(of: screen, version))) }
            let width = block.map(\.1.width).reduce(0, +) + gap * CGFloat(max(block.count - 1, 0))
            if x > 0, x + width > limit {
                x = 0
                y += rowHeight + gap * 1.5
                rowHeight = 0
            }
            for (version, size) in block {
                out.append(Placed(screen: screen, version: version, rect: CGRect(origin: CGPoint(x: x, y: y), size: size)))
                x += size.width + gap
                rowHeight = max(rowHeight, size.height)
            }
            x += gap * 0.5
        }
        return out
    }

    /// The picture's real size in points: iPhone pictures come at three times, the others at two.
    private func size(of screen: Screen, _ version: Version) -> CGSize {
        guard let app, let pixels = Store.pictureSize(store.picture(app: app, screen: screen.id, version: version)) else {
            return CGSize(width: 400, height: 300)
        }
        let factor: CGFloat = screen.kind == .iphone ? 3 : 2
        return CGSize(width: pixels.width / factor, height: pixels.height / factor)
    }

    func threads(on placed: Placed) -> [PinThread] {
        (threads[placed.screen.id] ?? []).filter { $0.version == placed.version.n }
    }

    func number(of thread: PinThread) -> Int {
        ((threads[thread.screen] ?? []).filter { $0.version == thread.version }.firstIndex(of: thread) ?? 0) + 1
    }

    var allThreads: [PinThread] {
        let order = screens.map(\.id)
        return threads.values.flatMap { $0 }
            .sorted { ((order.firstIndex(of: $0.screen) ?? 0), $0.version, $0.created) < ((order.firstIndex(of: $1.screen) ?? 0), $1.version, $1.created) }
    }

    func openCount(app name: String) -> Int {
        (try? store.allThreads(app: name).filter { !$0.resolved }.count) ?? 0
    }

    // MARK: Canvas

    func onScreen(_ point: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
    }

    func onScreen(_ rect: CGRect) -> CGRect {
        let corner = onScreen(rect.origin)
        return CGRect(x: corner.x, y: corner.y, width: rect.width * scale, height: rect.height * scale)
    }

    func pinPoint(_ thread: PinThread) -> CGPoint? {
        guard let box = placed.first(where: { $0.screen.id == thread.screen && $0.version.n == thread.version }) else { return nil }
        return onScreen(CGPoint(x: box.rect.minX + box.rect.width * thread.x, y: box.rect.minY + box.rect.height * thread.y))
    }

    func zoom(by factor: CGFloat, at point: CGPoint? = nil) {
        keepFitted = false
        let anchor = point ?? CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        let next = min(max(scale * factor, 0.05), 8)
        let change = next / scale
        origin = CGPoint(x: anchor.x - (anchor.x - origin.x) * change, y: anchor.y - (anchor.y - origin.y) * change)
        scale = next
    }

    func actualSize() { zoom(by: 1 / scale) }

    func pan(_ x: CGFloat, _ y: CGFloat) {
        keepFitted = false
        origin.x += x
        origin.y += y
    }

    func sized(_ size: CGSize) {
        viewport = size
        if keepFitted { fit() }
    }

    func fit() {
        keepFitted = true
        guard viewport.width > 100, viewport.height > 100 else { return }
        let boxes = placed.map(\.rect)
        guard let first = boxes.first else { return }
        let all = boxes.reduce(first) { $0.union($1) }
        let room: CGFloat = 60
        let next = min((viewport.width - 2 * room) / all.width, (viewport.height - 2 * room) / all.height, 1)
        scale = max(next, 0.05)
        origin = CGPoint(x: (viewport.width - all.width * scale) / 2 - all.minX * scale,
                         y: (viewport.height - all.height * scale) / 2 - all.minY * scale)
    }

    /// Brings a comment into view and opens it, moving to its page when it sits on another one.
    func reveal(_ thread: PinThread) {
        if let name = screens.first(where: { $0.id == thread.screen })?.pageName, name != page { page = name; fit() }
        selected = thread.id
        draft = nil
        if !placed.contains(where: { $0.screen.id == thread.screen && $0.version.n == thread.version }) { showAllVersions = true }
        if let point = pinPoint(thread) {
            pan(viewport.width * 0.42 - point.x, viewport.height * 0.42 - point.y)
        }
    }

    func reveal(_ screen: Screen) {
        keepFitted = false
        guard let box = placed.last(where: { $0.screen.id == screen.id }) else { return }
        let next = min((viewport.width - 120) / box.rect.width, (viewport.height - 120) / box.rect.height, 1)
        scale = max(next, 0.05)
        origin = CGPoint(x: (viewport.width - box.rect.width * scale) / 2 - box.rect.minX * scale,
                         y: (viewport.height - box.rect.height * scale) / 2 - box.rect.minY * scale)
    }

    /// A click on the canvas: a pin opens, a board takes a new comment, empty space closes what is open.
    func click(at point: CGPoint) {
        let visible = allThreads.filter { !$0.resolved || showResolved || $0.id == selected }
        if let hit = visible.first(where: { thread in
            guard let pin = pinPoint(thread) else { return false }
            return hypot(pin.x - point.x, pin.y - point.y) <= 15
        }) {
            selected = hit.id
            draft = nil
            return
        }
        selected = nil
        guard tool == .comment, let box = placed.last(where: { onScreen($0.rect).contains(point) }) else {
            draft = nil
            return
        }
        let rect = onScreen(box.rect)
        draft = Draft(placed: box, x: (point.x - rect.minX) / rect.width, y: (point.y - rect.minY) / rect.height)
    }

    // MARK: Files

    func image(_ screen: Screen, _ version: Version, app name: String? = nil) -> NSImage? {
        guard let name = name ?? app else { return nil }
        let url = store.picture(app: name, screen: screen.id, version: version)
        let key = url.path as NSString
        if let cached = Self.cache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        Self.cache.setObject(image, forKey: key)
        return image
    }

    /// Runs a change to the files, shows what went wrong if it fails, and returns what it made.
    @discardableResult
    func change<T>(_ work: (Store) throws -> T) -> T? {
        do {
            let result = try work(store)
            failure = nil
            reload()
            return result
        } catch {
            failure = error.localizedDescription
            return nil
        }
    }

    private static let cache = NSCache<NSString, NSImage>()
}
