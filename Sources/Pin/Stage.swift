import AppKit
import ImageIO
import PinCore
import QuartzCore
import SwiftUI

/// What is on the open page. SwiftUI hands this over only when it changes; the camera is not part of it.
struct StageScene: Equatable {
    struct Pin: Equatable { let number: Int, chosen: Bool, faded: Bool, spot: CGPoint }
    struct Flow: Equatable { let from: CGPoint, to: CGPoint, label: String? }
    var app: String?
    var page: String?
    var boards: [Placed]
    var pins: [Pin]
    var flows: [Flow]

    init(app: String?, page: String?, boards: [Placed], pins: [Pin], flows: [(from: CGPoint, to: CGPoint, label: String?)]) {
        self.app = app
        self.page = page
        self.boards = boards
        self.pins = pins
        self.flows = flows.map { Flow(from: $0.from, to: $0.to, label: $0.label) }
    }
}

/// The canvas as real canvases do it (Cua's infinite canvas, tldraw's camera): all boards sit in one document view at fixed
/// coordinates at their design size, and zooming or panning changes one thing, the scroll view's magnification and origin,
/// which the compositor applies to the whole document. No board is touched while the camera moves. What must keep its
/// screen size (dots, flows, labels, comment dots) is moved in the same breath. About 0.2 s after the camera stops,
/// `settle` starts and stops live boards and sharpens the ones on screen.
final class Stage: NSView {
    let events = CanvasEvents.EventView()
    private let model: Model
    private let scroll = CameraScroll()
    private let world = StageWorld()
    private let dots = DotsLayer()
    private let marks = MarksLayer()
    private var boards: [String: BoardView] = [:]
    private var scene: StageScene?
    private var settleTimer: Timer?

    /// The document is far bigger than anything he can reach, with the canvas's zero in its middle.
    static let extent: CGFloat = 200_000
    static let middle = extent / 2

    init(model: Model) {
        self.model = model
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        layer?.addSublayer(dots)
        world.frame = CGRect(x: 0, y: 0, width: Self.extent, height: Self.extent)
        scroll.documentView = world
        scroll.frame = bounds
        scroll.autoresizingMask = [.width, .height]
        addSubview(scroll)
        events.frame = bounds
        events.autoresizingMask = [.width, .height]
        events.wantsLayer = true
        addSubview(events)
        events.layer?.addSublayer(marks)
        model.onCamera = { [weak self] in self?.cameraMoved() }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        // The real size of the canvas. Later, because SwiftUI is mid-layout here and `fit` changes what it reads.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.model.sized(size)
                self?.cameraMoved()
            }
        }
    }

    override func viewDidChangeBackingProperties() {
        marks.contentsScale = window?.backingScaleFactor ?? 2
    }

    /// One camera step. Costs the same however many boards there are, apart from the labels and dots on screen.
    private func cameraMoved() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scroll.look(scale: model.scale, origin: model.origin, viewport: bounds.size)
        dots.update(scale: model.scale, origin: model.origin, size: bounds.size)
        marks.update(scale: model.scale, origin: model.origin, size: bounds.size)
        CATransaction.commit()
        settleSoon()
    }

    private func settleSoon() {
        if let settleTimer {
            settleTimer.fireDate = Date().addingTimeInterval(Self.settleDelay)
        } else {
            settleTimer = Timer.scheduledTimer(withTimeInterval: Self.settleDelay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.settleTimer = nil
                    self?.settle()
                }
            }
        }
    }
    private static let settleDelay: TimeInterval = 0.2

    /// A change to what is on the page, from SwiftUI. Not called for camera changes.
    func show(_ next: StageScene) {
        guard next != scene else { return }
        let boardsChanged = next.boards != scene?.boards || next.app != scene?.app
        scene = next
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if boardsChanged { placeBoards(next) }
        marks.show(next)
        marks.update(scale: model.scale, origin: model.origin, size: bounds.size)
        CATransaction.commit()
        if boardsChanged { settleSoon() }
    }

    private func placeBoards(_ scene: StageScene) {
        guard let app = scene.app else {
            boards.values.forEach { $0.removeFromSuperview() }
            boards = [:]
            return
        }
        var next: [String: BoardView] = [:]
        var ordered: [NSView] = []
        for item in scene.boards {
            let key = "\(app)/\(item.id)"
            let board = boards[key] ?? BoardView(key: key)
            let spot = item.rect.offsetBy(dx: Self.middle, dy: Self.middle)
            if board.frame != spot { board.frame = spot }
            board.item = item
            board.showPicture(model.store.picture(app: app, screen: item.screen.id, version: item.version), full: false)
            next[key] = board
            ordered.append(board)
        }
        for (key, board) in boards where next[key] == nil { board.removeFromSuperview() }
        boards = next
        // Later boards lie on top, as clicks expect.
        if world.subviews != ordered { world.subviews = ordered }
    }

    /// The camera has stopped: decide what runs live and sharpen what is on screen, which may be slow.
    private func settle() {
        model.showPercent(now: true)
        guard let app = scene?.app, let items = scene?.boards else { return }
        let frame = CGRect(origin: .zero, size: bounds.size)
        let store = model.store
        var shown: [(key: String, area: CGFloat)] = []
        if LiveBoards.hasWeb(app: app, store: store) {
            for item in items {
                let rect = model.onScreen(item.rect), key = "\(app)/\(item.id)"
                // An older version of a board stays its picture: the page is only ever the current code.
                guard item.version.n == item.screen.latest?.n, LiveBoards.web(app: app, screen: item.screen.id, store: store) != nil,
                      rect.intersects(frame), LiveBoards.runs(key, shownAt: rect.width) else { continue }
                let seen = rect.intersection(frame)
                shown.append((key, seen.width * seen.height))
            }
        }
        let pages = shown.isEmpty ? [] : WebBoards.choose(shown)
        for item in items {
            let key = "\(app)/\(item.id)"
            guard let board = boards[key] else { continue }
            let rect = model.onScreen(item.rect)
            guard rect.insetBy(dx: -40, dy: -40).intersects(frame) else {
                board.setLive(nil)
                board.offScreen()
                continue
            }
            if LiveBoards.swiftBoard(app: app, screen: item.screen.id, store: store), LiveBoards.runs(key, shownAt: rect.width),
               let view = LiveBoards.view(app: app, screen: item.screen.id, store: store) {
                board.setLive(board.live as? SwiftBoardView ?? SwiftBoardView.make(key: key, view: view, design: item.rect.size))
            } else if pages.contains(key), let page = LiveBoards.web(app: app, screen: item.screen.id, store: store) {
                board.setLive(board.live as? WebBoardView ?? WebBoardView.make(key: key, page: page, design: item.rect.size))
            } else {
                board.setLive(nil)
            }
            let picture = store.picture(app: app, screen: item.screen.id, version: item.version)
            board.showPicture(picture, full: rect.width * (window?.backingScaleFactor ?? 2) > Pictures.lightPixels)
            let vector = board.live == nil && model.scale > 1 ? model.vectorFile(item.screen, item.version) : nil
            board.sharpen(zoom: model.scale, seen: rect.intersection(frame), rect: rect, frame: frame, vector: vector)
        }
    }

    /// When a board last swapped between picture and running code, for the film: the old picture may differ from the code.
    static var liveChanged: CFTimeInterval = 0
}

/// The scroll view used as a camera. Nothing of its own reacts to input: the canvas's event view takes every wheel and
/// pinch and moves the model, and the model's camera comes back here.
private final class CameraScroll: NSScrollView {
    private final class Clip: NSClipView {
        /// Focus or typing inside a board must not move the camera behind the model's back.
        var applying = false
        override func scroll(to point: NSPoint) { if applying { super.scroll(to: point) } }
        override func autoscroll(with event: NSEvent) -> Bool { false }
        override func constrainBoundsRect(_ rect: NSRect) -> NSRect { rect }
    }
    private let clip = Clip()

    override init(frame: NSRect) {
        super.init(frame: frame)
        contentView = clip
        wantsLayer = true
        hasHorizontalScroller = false
        hasVerticalScroller = false
        horizontalScrollElasticity = .none
        verticalScrollElasticity = .none
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsetsZero
        drawsBackground = false
        clip.drawsBackground = false
        allowsMagnification = false
        minMagnification = 0.05
        maxMagnification = 16
    }

    @available(*, unavailable) required init?(coder: NSCoder) { nil }

    func look(scale: CGFloat, origin: CGPoint, viewport: CGSize) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        if magnification != scale { magnification = scale }
        let corner = CGPoint(x: Stage.middle - origin.x / scale, y: Stage.middle - origin.y / scale)
        clip.applying = true
        clip.setBoundsOrigin(corner)
        clip.applying = false
    }

    // Reaches here only when a running board did not use a scroll: the canvas does not move for that.
    override func scrollWheel(with event: NSEvent) {}
    override func magnify(with event: NSEvent) {}
    override func smartMagnify(with event: NSEvent) {}
}

/// The document. Flipped, draws nothing, takes no input of its own.
private final class StageWorld: NSView {
    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// A view that only shows a picture, stretched to fit.
final class PictureView: NSView {
    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { true }
    override init(frame: NSRect = .zero) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contentsGravity = .resize
        layer?.minificationFilter = .trilinear
        layer?.magnificationFilter = .linear
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    func show(_ picture: Any) { layer?.contents = picture }
    func clear() { layer?.contents = nil }
}

/// One board on the canvas, at its design size: the picture, sharp vector detail over it, a running screen over that.
private final class BoardView: NSView {
    let key: String
    var item: Placed?
    private let picture = PictureView()
    private let detail = PictureView()
    private(set) var live: (NSView & PressableBoard)?
    private var pictureFile: URL?
    private var pictureIsFull = false
    private var vectorTask: Task<Void, Never>?
    private var detailZoom: CGFloat = 0
    private var detailRegion = CGRect.zero

    init(key: String) {
        self.key = key
        super.init(frame: .zero)
        wantsLayer = true
        // What shows for the moment before the picture has been read.
        layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        picture.autoresizingMask = [.width, .height]
        addSubview(picture)
        detail.isHidden = true
        addSubview(detail)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func setFrameSize(_ size: NSSize) {
        super.setFrameSize(size)
        picture.frame = bounds
        live?.frame = bounds
    }

    func setLive(_ next: (NSView & PressableBoard)?) {
        guard next !== live else { return }
        Stage.liveChanged = CACurrentMediaTime()
        live?.removeFromSuperview()
        live = next
        guard let next else { return }
        next.frame = bounds
        addSubview(next)
    }

    func showPicture(_ file: URL, full: Bool) {
        let want = full || (pictureIsFull && file == pictureFile)
        guard file != pictureFile || want != pictureIsFull else { return }
        let isNew = file != pictureFile
        pictureFile = file
        pictureIsFull = want
        if isNew { picture.clear() }
        Pictures.load(file, full: want) { [weak self] image in
            guard let self, self.pictureFile == file, self.pictureIsFull == want, let image else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.picture.show(image)
            CATransaction.commit()
        }
    }

    /// Out of view: back to the light picture, and no sharp detail kept.
    func offScreen() {
        vectorTask?.cancel()
        detail.isHidden = true
        detail.clear()
        detailZoom = 0
        guard pictureIsFull, let file = pictureFile else { return }
        pictureIsFull = false
        Pictures.load(file, full: false) { [weak self] image in
            guard let self, !self.pictureIsFull, let image else { return }
            self.picture.show(image)
        }
    }

    func sharpen(zoom: CGFloat, seen: CGRect, rect: CGRect, frame: CGRect, vector: URL?) {
        (live as? SwiftBoardView)?.sharpen(zoom: zoom)
        (live as? WebBoardView)?.sharpen(zoom: zoom)
        vectorTask?.cancel()
        guard let vector, !seen.isNull, let design = item?.rect.size else {
            detail.isHidden = true
            detail.clear()
            detailZoom = 0
            return
        }
        // The part in view in the board's own points, with spare around it so moving stays sharp.
        let visible = CGRect(x: (seen.minX - rect.minX) / zoom, y: (seen.minY - rect.minY) / zoom, width: seen.width / zoom, height: seen.height / zoom)
        if detailZoom == zoom, detailRegion.contains(visible) { return }
        let spare = visible.insetBy(dx: -frame.width / zoom / 2, dy: -frame.height / zoom / 2).intersection(CGRect(origin: .zero, size: design))
        let density = zoom * (window?.backingScaleFactor ?? 2)
        vectorTask = Task { [weak self] in
            let image = await Task.detached(priority: .userInitiated) { VectorBoard.draw(vector, design: design, region: spare, density: density) }.value
            guard !Task.isCancelled, let self, let image else { return }
            // The old drawing stays until this one is ready, then they swap in one go.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.detail.frame = spare
            self.detail.show(image)
            self.detail.isHidden = false
            CATransaction.commit()
            self.detailZoom = zoom
            self.detailRegion = spare
        }
    }
}

/// Board pictures, read off the main thread: a light copy for every board on the page, the full one for boards large on screen.
@MainActor
private enum Pictures {
    static let lightPixels: CGFloat = 900
    private final class Box { let image: CGImage; init(_ image: CGImage) { self.image = image } }
    /// About a gigabyte of decoded pictures at most; NSCache drops the oldest beyond that.
    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.totalCostLimit = 1 << 30
        return cache
    }()
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 4
        queue.qualityOfService = .userInitiated
        return queue
    }()

    static func load(_ url: URL, full: Bool, done: @escaping @MainActor (CGImage?) -> Void) {
        let key = "\(full ? "full" : "light"):\(url.path)" as NSString
        if let known = cache.object(forKey: key) { return done(known.image) }
        queue.addOperation {
            let image = read(url, full: full)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if let image { cache.setObject(Box(image), forKey: key, cost: image.bytesPerRow * image.height) }
                    done(image)
                }
            }
        }
    }

    private nonisolated static func read(_ url: URL, full: Bool) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        var options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceShouldCacheImmediately: true]
        if !full { options[kCGImageSourceThumbnailMaxPixelSize] = 900 }
        else if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int {
            options[kCGImageSourceThumbnailMaxPixelSize] = max(width, height)
        }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// The board's dots: moved by the compositor from one dot, however many show. Zoomed far out only every other row and column stays.
private final class DotsLayer: CALayer {
    private let columns = CAReplicatorLayer()
    private let rows = CAReplicatorLayer()
    private let dot = CALayer()
    private let radius: CGFloat = 1.1

    override init() {
        super.init()
        dot.backgroundColor = NSColor(white: 1, alpha: 0.17).cgColor
        dot.cornerRadius = radius
        dot.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        rows.addSublayer(dot)
        columns.addSublayer(rows)
        addSublayer(columns)
    }

    override init(layer: Any) { super.init(layer: layer) }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }

    func update(scale: CGFloat, origin: CGPoint, size: CGSize) {
        frame = CGRect(origin: .zero, size: size)
        var step: CGFloat = 40 * scale
        while step < 14 { step *= 2 }
        var x = origin.x.truncatingRemainder(dividingBy: step)
        if x < 0 { x += step }
        var y = origin.y.truncatingRemainder(dividingBy: step)
        if y < 0 { y += step }
        dot.position = CGPoint(x: x, y: contentsAreFlipped() ? y : size.height - y)
        let vertical = contentsAreFlipped() ? step : -step
        columns.instanceTransform = CATransform3DMakeTranslation(step, 0, 0)
        rows.instanceTransform = CATransform3DMakeTranslation(0, vertical, 0)
        columns.instanceCount = Int(((size.width - x) / step).rounded(.up)) + 1
        rows.instanceCount = Int(((size.height - y) / step).rounded(.up)) + 1
    }
}

/// Flows, board names and comment dots, over the boards. They keep their size on screen, so they move with the camera but
/// do not scale with it. Each is one light layer holding a ready picture, moved in the same transaction as the camera.
private final class MarksLayer: CALayer {
    private let flows = CAShapeLayer()
    private let ports = CAShapeLayer()
    private var labels: [(layer: CALayer, rect: CGRect)] = []
    private var flowLabels: [(layer: CALayer, flow: StageScene.Flow)] = []
    private var pins: [(layer: CALayer, spot: CGPoint)] = []
    private var flowLines: [StageScene.Flow] = []

    override init() {
        super.init()
        flows.fillColor = nil
        flows.strokeColor = NSColor(white: 1, alpha: 0.42).cgColor
        flows.lineWidth = 1.5
        ports.fillColor = NSColor(white: 0.75, alpha: 1).cgColor
        addSublayer(flows)
        addSublayer(ports)
    }

    override init(layer: Any) { super.init(layer: layer) }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }

    @MainActor func show(_ scene: StageScene) {
        labels.forEach { $0.layer.removeFromSuperlayer() }
        flowLabels.forEach { $0.layer.removeFromSuperlayer() }
        pins.forEach { $0.layer.removeFromSuperlayer() }
        labels = scene.boards.map { item in
            let name = item.screen.versions.count > 1 ? "\(item.screen.name) · v\(item.version.n)" : item.screen.name
            return (textLayer(name), item.rect)
        }
        flowLines = scene.flows
        flowLabels = scene.flows.compactMap { flow in flow.label.map { (textLayer($0), flow) } }
        pins = scene.pins.map { pin in
            let layer = CALayer()
            layer.contents = Self.pinPicture(number: pin.number, chosen: pin.chosen)
            layer.contentsScale = 2
            layer.bounds = CGRect(x: 0, y: 0, width: Self.pinSize, height: Self.pinSize)
            layer.opacity = pin.faded ? 0.55 : 1
            return (layer, pin.spot)
        }
        labels.forEach { addSublayer($0.layer) }
        flowLabels.forEach { addSublayer($0.layer) }
        pins.forEach { addSublayer($0.layer) }
    }

    func update(scale: CGFloat, origin: CGPoint, size: CGSize) {
        frame = CGRect(origin: .zero, size: size)
        let flip = !contentsAreFlipped()
        func y(_ value: CGFloat) -> CGFloat { flip ? size.height - value : value }
        func screen(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale) }
        let view = CGRect(origin: .zero, size: size).insetBy(dx: -60, dy: -60)
        for (layer, rect) in labels {
            let corner = screen(rect.origin), width = max(rect.width * scale, 40)
            let shown = CGRect(x: corner.x, y: corner.y - 20, width: width, height: 20).intersects(view)
            if layer.isHidden == shown { layer.isHidden = !shown }
            guard shown else { continue }
            let wide = min(width, Self.textWidth(layer))
            if layer.bounds.width != wide { layer.bounds.size.width = wide }
            layer.position = CGPoint(x: corner.x + wide / 2, y: y(corner.y - 11))
        }
        for (layer, spot) in pins {
            let p = screen(spot), shown = view.contains(p)
            if layer.isHidden == shown { layer.isHidden = !shown }
            if shown { layer.position = CGPoint(x: p.x, y: y(p.y)) }
        }
        guard !flowLines.isEmpty else {
            if flows.path != nil { flows.path = nil; ports.path = nil }
            return
        }
        let lines = CGMutablePath(), dots = CGMutablePath(), port: CGFloat = 4
        for flow in flowLines {
            let start = screen(flow.from), end = screen(flow.to)
            let pull = max(abs(end.x - start.x) * 0.5, 30) * (end.x >= start.x ? 1 : -1)
            lines.move(to: CGPoint(x: start.x, y: y(start.y)))
            lines.addCurve(to: CGPoint(x: end.x, y: y(end.y)), control1: CGPoint(x: start.x + pull, y: y(start.y)), control2: CGPoint(x: end.x - pull, y: y(end.y)))
            for p in [start, end] {
                dots.addEllipse(in: CGRect(x: p.x - port, y: y(p.y) - port, width: port * 2, height: port * 2))
            }
        }
        flows.path = lines
        ports.path = dots
        for (layer, flow) in flowLabels {
            let start = screen(flow.from), end = screen(flow.to), leftward = end.x < start.x
            let width = layer.bounds.width
            layer.position = CGPoint(x: end.x + (leftward ? 12 + width / 2 : -12 - width / 2), y: y(end.y - 13))
        }
    }

    // MARK: Ready pictures

    private static let pinSize: CGFloat = 40
    private static var pinCache: [String: CGImage] = [:]
    private static var textCache: [String: (image: CGImage, size: CGSize)] = [:]

    @MainActor private static func pinPicture(number: Int, chosen: Bool) -> CGImage? {
        let key = "\(number)-\(chosen)"
        if let known = pinCache[key] { return known }
        let renderer = ImageRenderer(content: PinDot(number: number, chosen: chosen).frame(width: pinSize, height: pinSize))
        renderer.scale = 2
        let image = renderer.cgImage
        pinCache[key] = image
        return image
    }

    private static func textWidth(_ layer: CALayer) -> CGFloat { (layer.value(forKey: "fullWidth") as? CGFloat) ?? layer.bounds.width }

    private func textLayer(_ text: String) -> CALayer {
        let made = Self.textPicture(text)
        let layer = CALayer()
        layer.contents = made?.image
        layer.contentsScale = 2
        // Only ever cut at the right, never squeezed, so a narrower board costs no redraw.
        layer.contentsGravity = contentsAreFlipped() ? .bottomLeft : .topLeft
        layer.masksToBounds = true
        layer.bounds = CGRect(origin: .zero, size: made?.size ?? .zero)
        layer.setValue(made?.size.width ?? 0, forKey: "fullWidth")
        return layer
    }

    private static func textPicture(_ text: String) -> (image: CGImage, size: CGSize)? {
        if let known = textCache[text] { return known }
        let string = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor(white: 0.93, alpha: 0.55)])
        let size = CGSize(width: ceil(string.size().width) + 1, height: max(ceil(string.size().height), 1))
        let context = CGContext(data: nil, width: Int(size.width * 2), height: Int(size.height * 2), bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context else { return nil }
        context.scaleBy(x: 2, y: 2)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        string.draw(at: .zero)
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage() else { return nil }
        let made = (image, size)
        textCache[text] = made
        return made
    }
}
