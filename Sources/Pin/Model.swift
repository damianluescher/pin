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
    var flows: [FlowEdge] = []
    var showFlows = true
    /// Boards he dragged somewhere; the rest keep the automatic layout.
    var positions: [String: CGPoint] = [:]
    /// The board being dragged with the cursor tool.
    private var dragging: String?
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
    private var lastFitted: [Screen] = []

    func start() {
        reload()
        // Opens where he left off, like any Mac app: there is no start page.
        if app == nil, let name = [UserDefaults.standard.string(forKey: "lastFile")].compactMap({ $0 }).first(where: apps.contains) ?? apps.first { open(name) }
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    func reload() {
        let found = store.apps()
        if found != apps { apps = found }
        guard let app else {
            if let first = found.first, timer != nil { open(first) }
            return
        }
        do {
            let list = try store.screens(app: app)
            if list != screens { screens = list }
            var next: [String: [PinThread]] = [:]
            for screen in list { next[screen.id] = try store.threads(app: app, screen: screen.id) }
            if next != threads { threads = next }
            let steps = try store.flows(app: app)
            let flowsChanged = steps != flows
            if flowsChanged { flows = steps }
            if dragging == nil {
                let saved = try store.positions(app: app).compactMapValues { $0.count == 2 ? CGPoint(x: $0[0], y: $0[1]) : nil }
                if saved != positions { positions = saved }
            }
            if page == nil || !pages.contains(page ?? "") { page = pages.first }
            if keepFitted, flowsChanged || list != lastFitted { lastFitted = list; fit() }
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    func open(_ name: String) {
        app = name
        UserDefaults.standard.set(name, forKey: "lastFile")
        page = nil
        selected = nil
        draft = nil
        reload()
        fit()
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

    /// Boards as a flow when the page has one: each step one column further right, branches stacked.
    /// Boards with no step, and pages with none, run left to right in rows. A board's previous version sits on its left.
    var placed: [Placed] {
        // A dragged board goes where he put it, its older version still on its left.
        autoPlaced.map { item in
            guard let spot = positions[item.screen.id],
                  let first = autoPlaced.first(where: { $0.screen.id == item.screen.id }) else { return item }
            return Placed(screen: item.screen, version: item.version,
                          rect: item.rect.offsetBy(dx: spot.x - first.rect.minX, dy: spot.y - first.rect.minY))
        }
    }

    private var autoPlaced: [Placed] {
        let screens = pageScreens
        let ids = Set(screens.map(\.id))
        let steps = flows.filter { ids.contains($0.from) && ids.contains($0.to) }
        let linked = Set(steps.flatMap { [$0.from, $0.to] })
        let gap: CGFloat = 80
        var out: [Placed] = []
        var x: CGFloat = 0
        if !steps.isEmpty {
            var depth: [String: Int] = [:]
            // Longest way from a start; the fixed number of rounds also ends any loop.
            for _ in screens {
                for step in steps { depth[step.to] = max(depth[step.to] ?? 0, (depth[step.from] ?? 0) + 1) }
            }
            // One row, so boards stay large; the arrows arc over the top.
            let order = screens.filter { linked.contains($0.id) }.enumerated()
                .sorted { (depth[$0.element.id] ?? 0, $0.offset) < (depth[$1.element.id] ?? 0, $1.offset) }.map(\.element)
            for screen in order {
                let (items, size) = block(screen, at: CGPoint(x: x, y: 0), gap: gap)
                out += items
                x += size.width + gap * 1.5
            }
        }
        let origin = x
        var y: CGFloat = 0, rowHeight: CGFloat = 0
        for screen in screens where !linked.contains(screen.id) {
            let width = block(screen, at: .zero, gap: gap).1.width
            if x > origin, x + width > origin + 3600 {
                x = origin
                y += rowHeight + gap * 1.5
                rowHeight = 0
            }
            let (items, size) = block(screen, at: CGPoint(x: x, y: y), gap: gap)
            out += items
            x += size.width + gap * 1.5
            rowHeight = max(rowHeight, size.height)
        }
        return out
    }

    private func block(_ screen: Screen, at corner: CGPoint, gap: CGFloat) -> ([Placed], CGSize) {
        var x = corner.x, height: CGFloat = 0
        var items: [Placed] = []
        for version in showAllVersions ? screen.versions : Array(screen.versions.suffix(2)) {
            let size = size(of: screen, version)
            items.append(Placed(screen: screen, version: version, rect: CGRect(origin: CGPoint(x: x, y: corner.y), size: size)))
            x += size.width + gap
            height = max(height, size.height)
        }
        return (items, CGSize(width: max(x - gap - corner.x, 0), height: height))
    }

    /// The picture's real size in points: iPhone pictures come at three times, the others at two.
    private func size(of screen: Screen, _ version: Version) -> CGSize {
        guard let app else { return CGSize(width: 400, height: 300) }
        let url = store.picture(app: app, screen: screen.id, version: version)
        if let known = Self.pixels[url.path] { return scaled(known, screen) }
        guard let pixels = Store.pictureSize(url) else { return CGSize(width: 400, height: 300) }
        Self.pixels[url.path] = pixels
        return scaled(pixels, screen)
    }

    private func scaled(_ pixels: CGSize, _ screen: Screen) -> CGSize {
        let factor: CGFloat = screen.kind == .iphone ? 3 : 2
        return CGSize(width: pixels.width / factor, height: pixels.height / factor)
    }

    /// The arrows of the open page in canvas units: from the top of one board up and over to the top of another.
    var flowLines: [(from: CGPoint, to: CGPoint, rise: CGFloat, label: String?)] {
        guard showFlows else { return [] }
        let boxes = placed
        let order = boxes.map(\.screen.id).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        var out: [(from: CGPoint, to: CGPoint, rise: CGFloat, label: String?)] = []
        for step in flows {
            guard let start = boxes.last(where: { $0.screen.id == step.from }),
                  let end = boxes.first(where: { $0.screen.id == step.to }),
                  let i = order.firstIndex(of: step.from), let j = order.firstIndex(of: step.to) else { continue }
            let leaving = flows.filter { $0.from == step.from && order.contains($0.to) }
            let place = CGFloat(leaving.firstIndex(of: step) ?? 0) - CGFloat(leaving.count - 1) / 2
            out.append((CGPoint(x: start.rect.midX + place * 36, y: start.rect.minY),
                        CGPoint(x: end.rect.midX, y: end.rect.minY), Self.arcRise * CGFloat(abs(j - i)), step.label))
        }
        return out
    }

    private static let arcRise: CGFloat = 110

    // MARK: Moving boards

    /// Starts moving the board under the point, if any. Only with the cursor tool: the comment tool clicks on boards.
    func beginMove(at point: CGPoint) -> Bool {
        guard tool == .move, let box = placed.last(where: { onScreen($0.rect).contains(point) }) else { return false }
        dragging = box.screen.id
        keepFitted = false
        return true
    }

    func move(_ dx: CGFloat, _ dy: CGFloat) {
        guard let id = dragging, let first = placed.first(where: { $0.screen.id == id }) else { return }
        positions[id] = CGPoint(x: first.rect.minX + dx / scale, y: first.rect.minY + dy / scale)
    }

    func endMove() {
        guard let id = dragging else { return }
        dragging = nil
        guard let app, let spot = positions[id] else { return }
        change { try $0.setPosition(app: app, screen: id, x: spot.x, y: spot.y) }
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
        var all = boxes.reduce(first) { $0.union($1) }
        // Room for the arrows over the boards.
        if let top = flowLines.map(\.rise).max() {
            all = all.union(CGRect(x: all.minX, y: all.minY - top - 60, width: 1, height: 1))
        }
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
    /// Reading a picture's size from disk on every frame of a drag is too slow.
    private static var pixels: [String: CGSize] = [:]
}
