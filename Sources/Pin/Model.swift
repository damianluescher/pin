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

enum Tool { case comment, move, press }

/// What a new comment points at until it has its text.
struct Draft: Equatable {
    let placed: Placed
    let x: Double
    let y: Double
}

/// The app's state. Rereads the files every two seconds, so what an agent writes shows up by itself.
@MainActor @Observable final class Model {
    let store = Store()
    /// The file's real app or website beside the canvas (RunPanel.swift).
    let run = RunPanelModel()
    var apps: [String] = []
    /// The open file; nil shows the files page.
    var app: String?
    var screens: [Screen] = [] { didSet { sortedThreads = nil } }
    var threads: [String: [PinThread]] = [:] { didSet { sortedThreads = nil } }
    @ObservationIgnored private var sortedThreads: [PinThread]?
    private var openCounts: [String: Int] = [:]
    var flows: [FlowEdge] = []
    var showFlows = true
    /// Boards he dragged somewhere; the rest keep the automatic layout.
    var positions: [String: CGPoint] = [:]
    /// The board being dragged with the cursor tool.
    private var dragging: String?
    var failure: String?

    var page: String?
    var tool = Tool.comment
    /// The camera: one point and one zoom. Nothing in SwiftUI observes them, so a zoom step reruns no view; `look` hands
    /// them to the stage, which applies them once to the whole canvas.
    @ObservationIgnored private(set) var scale: CGFloat = 0.5
    @ObservationIgnored private(set) var origin = CGPoint.zero
    @ObservationIgnored var onCamera: (() -> Void)?
    /// The zoom shown in the toolbar, updated a few times a second at most.
    private(set) var percent = 50
    @ObservationIgnored private var percentShown = Date.distantPast
    /// Moves an open comment along with the camera; nothing reads it otherwise.
    private(set) var bubbleTick = 0
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
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    /// Everything read from disk in one go, so reading many boards never happens on the thread that draws.
    private struct Snapshot: Sendable {
        var apps: [String]
        var screens: [Screen] = []
        var threads: [String: [PinThread]] = [:]
        var flows: [FlowEdge] = []
        var positions: [String: [Double]] = [:]
        var openCounts: [String: Int]?
        var failure: String?
    }

    private nonisolated static func read(_ store: Store, app: String?, counts: Bool) -> Snapshot {
        var out = Snapshot(apps: store.apps())
        if counts {
            out.openCounts = Dictionary(uniqueKeysWithValues: out.apps.map { name in
                (name, (try? store.allThreads(app: name).filter { !$0.resolved }.count) ?? 0)
            })
        }
        guard let app else { return out }
        do {
            out.screens = try store.screens(app: app)
            for screen in out.screens { out.threads[screen.id] = try store.threads(app: app, screen: screen.id) }
            out.threads[Store.general] = try store.threads(app: app, screen: Store.general)
            out.flows = try store.flows(app: app)
            out.positions = try store.positions(app: app)
        } catch {
            out.failure = error.localizedDescription
        }
        return out
    }

    @ObservationIgnored private var glide: Timer?
    @ObservationIgnored private var glideGoal: CGFloat = 1
    @ObservationIgnored private var glideAnchor = CGPoint.zero
    private var reading = false
    private var ticks = 0

    private func tick() {
        guard !reading else { return }
        reading = true
        let counts = ticks % 5 == 0
        ticks += 1
        let store = store, wanted = app
        Task.detached(priority: .utility) { [weak self] in
            let found = Self.read(store, app: wanted, counts: counts)
            await MainActor.run {
                guard let self else { return }
                self.reading = false
                if self.app == wanted { self.apply(found) }
            }
        }
    }

    /// Right now, on this thread: for opening a file, where he should see it at once.
    func reload() {
        apply(Self.read(store, app: app, counts: openCounts.isEmpty))
    }

    private func apply(_ found: Snapshot) {
        if found.apps != apps { apps = found.apps }
        if let counts = found.openCounts, counts != openCounts { openCounts = counts }
        guard app != nil else {
            if let first = found.apps.first, timer != nil { open(first) }
            return
        }
        if let problem = found.failure { failure = problem; return }
        if found.screens != screens { screens = found.screens }
        if found.threads != threads { threads = found.threads }
        let flowsChanged = found.flows != flows
        if flowsChanged { flows = found.flows }
        if dragging == nil {
            let saved = found.positions.compactMapValues { $0.count == 2 ? CGPoint(x: $0[0], y: $0[1]) : nil }
            if saved != positions { positions = saved }
        }
        if page == nil || !pages.contains(page ?? "") { page = pages.first }
        if keepFitted, flowsChanged || found.screens != lastFitted { lastFitted = found.screens; fit() }
        failure = nil
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
    /// Asked for many times per frame, so the layout is kept until something it depends on changes.
    var placed: [Placed] {
        let key = PlacedKey(screens: screens, page: page, flows: flows, positions: positions, all: showAllVersions)
        if let known = placedMemo, known.key == key { return known.items }
        let items = computePlaced()
        placedMemo = (key, items)
        return items
    }

    private struct PlacedKey: Equatable {
        let screens: [Screen], page: String?, flows: [FlowEdge], positions: [String: CGPoint], all: Bool
    }
    @ObservationIgnored private var placedMemo: (key: PlacedKey, items: [Placed])?

    private func computePlaced() -> [Placed] {
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
            // Left to right, branches stacked and each column centred on the others, as in fal, n8n and Zapier.
            let columns = Set(linked.map { depth[$0] ?? 0 }).sorted().map { column in
                screens.filter { linked.contains($0.id) && (depth[$0.id] ?? 0) == column }
            }
            func height(_ column: [Screen]) -> CGFloat {
                column.map { block($0, at: .zero, gap: gap).1.height }.reduce(0, +) + gap * CGFloat(column.count - 1)
            }
            let tallest = columns.map(height).max() ?? 0
            for column in columns {
                var y = (tallest - height(column)) / 2, width: CGFloat = 0
                for screen in column {
                    let (items, size) = block(screen, at: CGPoint(x: x, y: y), gap: gap)
                    out += items
                    y += size.height + gap
                    width = max(width, size.width)
                }
                x += width + 420
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
        if let live = LiveBoards.size(app: app, screen: screen.id, store: store) { return live }
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

    /// The lines of the open page in canvas units: out of one board's side, into another's.
    var flowLines: [(from: CGPoint, to: CGPoint, label: String?)] {
        guard showFlows else { return [] }
        let boxes = placed
        return flows.compactMap { step in
            guard let start = boxes.last(where: { $0.screen.id == step.from }),
                  let end = boxes.first(where: { $0.screen.id == step.to }) else { return nil }
            // A board he dragged to the left of the other is joined on those sides instead.
            if end.rect.minX >= start.rect.maxX {
                return (CGPoint(x: start.rect.maxX, y: start.rect.midY), CGPoint(x: end.rect.minX, y: end.rect.midY), step.label)
            }
            return (CGPoint(x: start.rect.minX, y: start.rect.midY), CGPoint(x: end.rect.maxX, y: end.rect.midY), step.label)
        }
    }

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
        if let sortedThreads { return sortedThreads }
        let order = Dictionary(screens.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        let list = threads.values.flatMap { $0 }
            .sorted { ((order[$0.screen] ?? 0), $0.version, $0.created) < ((order[$1.screen] ?? 0), $1.version, $1.created) }
        sortedThreads = list
        return list
    }

    func openCount(app name: String) -> Int { openCounts[name] ?? 0 }

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
        let next = min(max(scale * factor, 0.05), 16)
        let change = next / scale
        look(scale: next, origin: CGPoint(x: anchor.x - (anchor.x - origin.x) * change, y: anchor.y - (anchor.y - origin.y) * change))
    }

    /// The one way the camera changes.
    func look(scale: CGFloat, origin: CGPoint) {
        self.scale = scale
        self.origin = origin
        onCamera?()
        if selected != nil || draft != nil { bubbleTick &+= 1 }
        showPercent()
    }

    func showPercent(now: Bool = false) {
        let date = Date()
        guard now || date.timeIntervalSince(percentShown) > 0.1 else { return }
        percentShown = date
        let value = Int(scale * 100)
        if value != percent { percent = value }
    }

    /// A wheel notch: heads for the new zoom over a few frames instead of snapping there. More notches just move the goal.
    func glideZoom(by factor: CGFloat, at point: CGPoint) {
        glideGoal = min(max((glide == nil ? scale : glideGoal) * factor, 0.05), 16)
        glideAnchor = point
        guard glide == nil else { return }
        glide = Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.glideStep() }
        }
    }

    private func glideStep() {
        let left = glideGoal / scale
        if abs(left - 1) < 0.002 {
            zoom(by: left, at: glideAnchor)
            glide?.invalidate()
            glide = nil
        } else {
            zoom(by: pow(left, 0.15), at: glideAnchor)
        }
    }

    func actualSize() { zoom(by: 1 / scale) }

    func pan(_ x: CGFloat, _ y: CGFloat) {
        keepFitted = false
        look(scale: scale, origin: CGPoint(x: origin.x + x, y: origin.y + y))
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
        let zoom = max(next, 0.05)
        look(scale: zoom, origin: CGPoint(x: (viewport.width - all.width * zoom) / 2 - all.minX * zoom,
                                          y: (viewport.height - all.height * zoom) / 2 - all.minY * zoom))
    }

    /// Brings a comment into view and opens it, moving to its page when it sits on another one.
    func reveal(_ thread: PinThread) {
        // A comment on the whole file sits on no board: it only opens.
        if thread.screen == Store.general { selected = selected == thread.id ? nil : thread.id; draft = nil; return }
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
        let zoom = max(next, 0.05)
        look(scale: zoom, origin: CGPoint(x: (viewport.width - box.rect.width * zoom) / 2 - box.rect.minX * zoom,
                                          y: (viewport.height - box.rect.height * zoom) / 2 - box.rect.minY * zoom))
    }

    /// The comment dot under the point, if one shows there.
    func pin(at point: CGPoint) -> PinThread? {
        allThreads.filter { !$0.resolved || showResolved || $0.id == selected }.first { thread in
            guard let pin = pinPoint(thread) else { return false }
            return hypot(pin.x - point.x, pin.y - point.y) <= 15
        }
    }

    /// With the press tool: the view inside the running board at this point, or nil when the top board here is a
    /// picture or there is no board, so the canvas takes it.
    func pressTarget(at point: CGPoint, inWindow spot: NSPoint) -> NSView? {
        guard tool == .press, let app, let box = placed.last(where: { onScreen($0.rect).contains(point) }) else { return nil }
        return LiveBoards.running("\(app)/\(box.id)")?.pressTarget(inWindow: spot)
    }

    /// A click on the canvas: a pin opens, a board takes a new comment, empty space closes what is open.
    func click(at point: CGPoint) {
        if let hit = pin(at: point) {
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

    /// The board's vector file, when it was copied from a design file. Remembered, since this is asked for every board each time the canvas settles.
    func vectorFile(_ screen: Screen, _ version: Version) -> URL? {
        guard let app else { return nil }
        let url = store.picture(app: app, screen: screen.id, version: version).deletingPathExtension().appendingPathExtension("pdf")
        let now = Date()
        if let known = vectorFiles[url], now.timeIntervalSince(known.checked) < 5 { return known.there ? url : nil }
        let there = FileManager.default.fileExists(atPath: url.path)
        vectorFiles[url] = (now, there)
        return there ? url : nil
    }
    @ObservationIgnored private var vectorFiles: [URL: (checked: Date, there: Bool)] = [:]

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

    /// Reading a picture's size from disk on every frame of a drag is too slow.
    private static var pixels: [String: CGSize] = [:]
}
