import Foundation
import AppKit
import PinCore
import SwiftUI

/// Boards that are real running screens instead of pictures. An app opts in with a `live.json` beside its screens,
/// naming the library built from its code and which board is which screen.
@MainActor
enum LiveBoards {
    private static var libraries: [String: UnsafeMutableRawPointer] = [:]
    private static var views: [String: AnyView] = [:]

    private typealias Make = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer

    /// The screen's design size, or nil when this board is only a picture.
    static func size(app: String, screen: String, store: Store) -> CGSize? {
        guard let live = config(app, store), live.boards[screen] != nil else { return nil }
        return live.size.cgSize
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

/// A live screen on the canvas. It keeps laying out at its design size; the enlarging happens here, and every layer
/// inside is told to draw at the zoom's sharpness, so nothing is a small bitmap blown up.
struct LiveHost: NSViewRepresentable {
    let view: AnyView
    let design: CGSize
    let zoom: CGFloat

    func makeNSView(context: Context) -> Container {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: design)
        let box = Container()
        box.wantsLayer = true
        box.addSubview(host)
        box.host = host
        return box
    }

    func updateNSView(_ box: Container, context: Context) {
        guard box.design != design || box.zoom != zoom else { return }
        box.design = design
        box.zoom = zoom
        box.frame.size = CGSize(width: design.width * zoom, height: design.height * zoom)
        box.setBoundsSize(design)
        box.sharpen(zoom: zoom)
    }

    final class Container: NSView {
        weak var host: NSView?
        var design = CGSize.zero
        var zoom: CGFloat = 0
        private var drawn: CGFloat = 0
        private var pending: DispatchWorkItem?

        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

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
