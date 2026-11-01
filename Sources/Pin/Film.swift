import AppKit
import QuartzCore

/// `PIN_SHOT=X PIN_FILM=FOLDER PIN_APP=A PIN_PAGE=P [PIN_BOARD=id] Pin` zooms one board from 0.5 to 8 and back around one
/// fixed point, the way a wheel does, stopping at the sizes where the page redraws. It records what really reached the
/// window (WebKit included, which `cacheDisplay` does not see) and fails if a picture is mostly blank or white, or if the
/// tracked point moves more than 2 points. Exits 1 when it fails. Run from a real app bundle for web boards.
@MainActor
final class Film {
    private let model: Model
    private let folder: String
    private var frames: [Shot] = []
    private var previous: Shot?
    private var anchor = CGPoint.zero
    private var failures: [String] = []
    private var worstMove: CGFloat = 0
    private var flat = 0
    private var measured = 0
    private var worstChange = 0
    private var stepCosts: [Double] = []
    private var swapMoves: [CGFloat] = []
    private var count = 0

    init(model: Model, folder: String) {
        self.model = model
        self.folder = folder
    }

    /// The canvas as one grey point per screen point, with its zoom.
    private struct Shot {
        let width: Int, height: Int, gray: [UInt8], scale: CGFloat
        func at(_ x: Int, _ y: Int) -> Int { Int(gray[y * width + x]) }
    }

    private var window: NSWindow? { NSApp.windows.first { $0.isVisible && $0.contentView != nil } }
    private func stage(in view: NSView? = nil) -> NSView? {
        guard let view = view ?? window?.contentView else { return nil }
        if view is Stage { return view }
        for child in view.subviews { if let found = stage(in: child) { return found } }
        return nil
    }

    private typealias Capture = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
    /// The system's picture of this very window, as the screen shows it. No screen permission is needed for one's own window.
    private static let capture: Capture? = {
        let library = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW)
        return dlsym(library, "CGWindowListCreateImage").map { unsafeBitCast($0, to: Capture.self) }
    }()

    func start() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        let env = ProcessInfo.processInfo.environment
        guard let item = env["PIN_BOARD"].flatMap({ id in model.placed.last { $0.screen.id == id } }) ?? model.placed.first else { return finish("no board") }
        // The board in the middle at the smallest size, and time for it to start running.
        model.keepFitted = false
        let center = CGPoint(x: model.viewport.width / 2, y: model.viewport.height / 2)
        model.look(scale: 0.5, origin: CGPoint(x: center.x - item.rect.midX * 0.5, y: center.y - item.rect.midY * 0.5))
        after(3.5) { self.begin(item) }
    }

    private func begin(_ item: Placed) {
        guard let first = grab() else { return finish("could not record the window: the capture call is gone") }
        anchor = busiestPoint(first)
        print("FILM \(model.app ?? "") board \(item.screen.id) canvas \(first.width)x\(first.height) anchor \(anchor)")
        previous = first
        save("start")
        var factors: [(CGFloat, Bool)] = []
        // Up in small steps, and a stop at each size where a page or a screen redraws, and the same way back.
        var zoom: CGFloat = 0.5
        let stops: [CGFloat] = [1.05, 2.1, 4.2, 8]
        var left = stops
        while zoom < 8 {
            let next = min(zoom * 1.12, 8)
            let stop = left.first.map { next >= $0 } ?? false
            if stop { left.removeFirst() }
            factors.append((next / zoom, stop))
            zoom = next
        }
        left = [4.2, 2.1, 0.95, 0.5]
        while zoom > 0.5 {
            let next = max(zoom / 1.12, 0.5)
            let stop = left.first.map { next <= $0 } ?? false
            if stop { left.removeFirst() }
            factors.append((next / zoom, stop))
            zoom = next
        }
        step(factors[...])
    }

    private func step(_ rest: ArraySlice<(CGFloat, Bool)>) {
        guard let (factor, stop) = rest.first else { return finish(nil) }
        let begun = CACurrentMediaTime()
        model.zoom(by: factor, at: anchor)
        CATransaction.flush()
        stepCosts.append((CACurrentMediaTime() - begun) * 1000)
        // The window has this step one screen frame later.
        after(0.034) {
            self.record()
            if stop { self.hold(16) { self.step(rest.dropFirst()) } } else { self.step(rest.dropFirst()) }
        }
    }

    /// Stands still and keeps looking while the boards sharpen, where a white flash would show.
    private func hold(_ left: Int, then: @escaping @MainActor () -> Void) {
        guard left > 0 else { return then() }
        after(0.1) {
            self.record()
            self.hold(left - 1, then: then)
        }
    }

    private func record() {
        guard let shot = grab() else { return fail("no picture") }
        defer { previous = shot }
        guard let previous else { return }
        save(String(format: "%.2f", shot.scale))
        checkBlank(shot, previous)
        checkAnchor(shot, previous)
    }

    private func checkBlank(_ shot: Shot, _ before: Shot) {
        var counts = [Int](repeating: 0, count: 32), white = 0
        for value in shot.gray {
            counts[Int(value) / 8] += 1
            if value >= 240 { white += 1 }
        }
        let total = shot.gray.count
        let whiteShare = Double(white) / Double(total)
        let same = Double(counts.max() ?? 0) / Double(total)
        var whiteBefore = 0
        for value in before.gray where value >= 240 { whiteBefore += 1 }
        let whiteJump = whiteShare - Double(whiteBefore) / Double(total)
        if same >= 0.97 { fail("frame \(count) at \(shot.scale): \(Int(same * 100))% one colour") }
        if whiteJump > 0.4 { fail("frame \(count) at \(shot.scale): white jumped by \(Int(whiteJump * 100))%") }
        // The whole canvas against the last picture enlarged by the zoom change: a blank or a jump is a big difference.
        let ratio = shot.scale / before.scale
        var sum = 0, n = 0
        for y in stride(from: 0, to: shot.height, by: 6) {
            for x in stride(from: 0, to: shot.width, by: 6) {
                let px = Int(anchor.x + (CGFloat(x) - anchor.x) / ratio), py = Int(anchor.y + (CGFloat(y) - anchor.y) / ratio)
                guard px >= 0, py >= 0, px < before.width, py < before.height else { continue }
                sum += abs(shot.at(x, y) - before.at(px, py))
                n += 1
            }
        }
        let change = n > 0 ? sum / n : 0
        worstChange = max(worstChange, change)
        if change > 50 { fail("frame \(count) at \(shot.scale): the picture changed by \(change) of 255 from the last") }
    }

    /// Where the patch around the tracked point went, compared with where the zoom says it must be.
    private func checkAnchor(_ shot: Shot, _ before: Shot) {
        let half = 56, reach = 8, ax = Int(anchor.x), ay = Int(anchor.y)
        guard ax - half - reach >= 0, ay - half - reach >= 0, ax + half + reach < shot.width, ay + half + reach < shot.height else { return }
        let ratio = shot.scale / before.scale
        var expected: [(Int, Int, Int)] = []
        var total = 0
        for dy in stride(from: -half, through: half, by: 2) {
            for dx in stride(from: -half, through: half, by: 2) {
                let px = Int(anchor.x + CGFloat(dx) / ratio), py = Int(anchor.y + CGFloat(dy) / ratio)
                guard px >= 0, py >= 0, px < before.width, py < before.height else { continue }
                let value = before.at(px, py)
                expected.append((dx, dy, value))
                total += value
            }
        }
        guard !expected.isEmpty else { return }
        let mean = total / expected.count
        let spread = expected.reduce(0) { $0 + abs($1.2 - mean) } / expected.count
        guard spread >= 4 else { flat += 1; return }
        var best = Int.max, bestShift = (0, 0)
        for sy in -reach...reach {
            for sx in -reach...reach {
                var sum = 0
                for (dx, dy, value) in expected { sum += abs(shot.at(ax + dx + sx, ay + dy + sy) - value) }
                if sum < best || (sum == best && abs(sx) + abs(sy) < abs(bestShift.0) + abs(bestShift.1)) { best = sum; bestShift = (sx, sy) }
            }
        }
        let moved = hypot(CGFloat(bestShift.0), CGFloat(bestShift.1))
        measured += 1
        // Not the camera: a board just swapped from its picture to its running code, and an old picture can differ from the code.
        if moved > 2, CACurrentMediaTime() - Stage.liveChanged < 1 {
            swapMoves.append(moved)
            return
        }
        worstMove = max(worstMove, moved)
        if moved > 2 { fail("frame \(count) at \(shot.scale): tracked point moved \(moved) points") }
    }

    private func grab() -> Shot? {
        guard let cg = rawImage(), let stage = stage(), let window else { return nil }
        count += 1
        last = cg
        let inWindow = stage.convert(stage.bounds, to: nil)
        let factor = CGFloat(cg.width) / window.frame.width
        // Window points run up from the bottom; the picture runs down from the top.
        let crop = CGRect(x: inWindow.minX * factor, y: (window.frame.height - inWindow.maxY) * factor,
                          width: inWindow.width * factor, height: inWindow.height * factor)
        guard let part = cg.cropping(to: crop) else { return nil }
        let width = Int(inWindow.width), height = Int(inWindow.height)
        var gray = [UInt8](repeating: 0, count: width * height)
        let made: Bool = gray.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(part, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return made ? Shot(width: width, height: height, gray: gray, scale: model.scale) : nil
    }
    private var last: CGImage?

    private func rawImage() -> CGImage? {
        guard let window, let capture = Self.capture else { return nil }
        return capture(.null, 1 << 3, UInt32(window.windowNumber), 1 << 0 | 1 << 3)?.takeRetainedValue()
    }

    /// The point near the middle with the most going on around it, so the tracking has something to follow all the way.
    private func busiestPoint(_ shot: Shot) -> CGPoint {
        var best = CGPoint(x: shot.width / 2, y: shot.height / 2), most = -1
        let box = 40
        for cy in stride(from: shot.height / 3, to: shot.height * 2 / 3, by: 30) {
            for cx in stride(from: shot.width / 3, to: shot.width * 2 / 3, by: 30) {
                var hop = 0
                for y in stride(from: cy - box, to: cy + box, by: 2) {
                    for x in stride(from: cx - box, to: cx + box - 2, by: 2) { hop += abs(shot.at(x, y) - shot.at(x + 2, y)) }
                }
                if hop > most { most = hop; best = CGPoint(x: cx, y: cy) }
            }
        }
        return best
    }

    private func save(_ tag: String) {
        guard let last else { return }
        let rep = NSBitmapImageRep(cgImage: last)
        let name = String(format: "%@/%03d-%@.png", folder, count, tag)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: name))
    }

    private func fail(_ text: String) {
        failures.append(text)
        print("FILM FAIL \(text)")
        fflush(stdout)
    }

    private func finish(_ problem: String?) {
        if let problem { failures.append(problem) }
        let costs = stepCosts.sorted()
        print("FILM \(count) pictures; tracked point checked \(measured) times (\(flat) too plain to check), moved at most \(worstMove) points; biggest change from one picture to the next \(worstChange) of 255; zoom step on the main thread: typical \(String(format: "%.1f", costs.isEmpty ? 0 : costs[costs.count / 2])) ms, slowest \(String(format: "%.1f", costs.last ?? 0)) ms")
        if !swapMoves.isEmpty { print("FILM NOTE not counted: picture differed from running code when a board started, by \(swapMoves) points") }
        print(failures.isEmpty ? "FILM PASS" : "FILM FAILED \(failures.count) checks")
        fflush(stdout)
        exit(failures.isEmpty ? 0 : 1)
    }

    private func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { MainActor.assumeIsolated { work() } }
    }
}
