import AppKit
import PinCore
import SwiftUI

struct Canvas: View {
    @Environment(Model.self) private var model

    var body: some View {
        GeometryReader { box in
            ZStack(alignment: .topLeading) {
                Style.canvas
                dots(in: box.size).allowsHitTesting(false)
                CanvasEvents()
                boards(in: box.size).allowsHitTesting(false)
                flowArrows.allowsHitTesting(false)
                pins.allowsHitTesting(false)
                bubble(in: box.size)
            }
            .clipped()
        }
    }

    /// The board's dots. They move and zoom with the canvas; zoomed far out only every other row and column stays.
    private func dots(in size: CGSize) -> some View {
        let scale = model.scale, origin = model.origin
        return SwiftUI.Canvas { context, _ in
            var step: CGFloat = 40 * scale
            while step < 14 { step *= 2 }
            let radius: CGFloat = 1.1
            var x = origin.x.truncatingRemainder(dividingBy: step)
            if x < 0 { x += step }
            var dots = Path()
            while x < size.width {
                var y = origin.y.truncatingRemainder(dividingBy: step)
                if y < 0 { y += step }
                while y < size.height {
                    dots.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    y += step
                }
                x += step
            }
            context.fill(dots, with: .color(.white.opacity(0.17)))
        }
    }

    /// The flow: a curved arrow from each board to the one it leads to, with what you tap on it.
    private var flowArrows: some View {
        let scale = model.scale
        let lines = model.flowLines.map { (model.onScreen($0.from), model.onScreen($0.to), $0.rise * scale, $0.label) }
        return SwiftUI.Canvas { context, _ in
            let ink = Color.white.opacity(0.6)
            for (start, end, rise, label) in lines {
                let top = min(start.y, end.y) - rise
                let tip = CGPoint(x: end.x, y: end.y - 3)
                var line = Path()
                line.move(to: start)
                line.addCurve(to: CGPoint(x: tip.x, y: tip.y - 8),
                              control1: CGPoint(x: start.x, y: top),
                              control2: CGPoint(x: tip.x, y: top))
                context.stroke(line, with: .color(ink), lineWidth: 1.5)
                var head = Path()
                head.move(to: tip)
                head.addLine(to: CGPoint(x: tip.x - 5, y: tip.y - 9))
                head.addLine(to: CGPoint(x: tip.x + 5, y: tip.y - 9))
                head.closeSubpath()
                context.fill(head, with: .color(ink))
                if let label {
                    let text = context.resolve(Text(label).font(Style.small).foregroundColor(Style.ink))
                    // The curve's highest point sits three quarters of the way up to its handles.
                    let middle = CGPoint(x: (start.x + tip.x) / 2, y: (start.y + tip.y) / 2 * 0.25 + top * 0.75)
                    let size = text.measure(in: CGSize(width: 220, height: 40))
                    let plate = CGRect(x: middle.x - size.width / 2 - 6, y: middle.y - size.height / 2 - 3, width: size.width + 12, height: size.height + 6)
                    context.fill(Path(roundedRect: plate, cornerRadius: 6), with: .color(Style.raised))
                    context.draw(text, at: middle)
                }
            }
        }
    }

    private func boards(in size: CGSize) -> some View {
        let frame = CGRect(origin: .zero, size: size)
        return ZStack(alignment: .topLeading) {
            ForEach(model.placed) { item in
                let rect = model.onScreen(item.rect)
                if rect.insetBy(dx: -40, dy: -40).intersects(frame) {
                    if let image = model.image(item.screen, item.version) {
                        Image(nsImage: image).resizable().interpolation(.high)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                    Text(label(item)).font(Style.small).foregroundStyle(Style.grey).lineLimit(1)
                        .frame(width: max(rect.width, 40), alignment: .leading)
                        .position(x: rect.minX + max(rect.width, 40) / 2, y: rect.minY - 11)
                }
            }
        }
    }

    private func label(_ item: Placed) -> String {
        item.screen.versions.count > 1 ? "\(item.screen.name) · v\(item.version.n)" : item.screen.name
    }

    private var pins: some View {
        ZStack(alignment: .topLeading) {
            ForEach(model.allThreads) { thread in
                if !thread.resolved || model.showResolved || model.selected == thread.id, let point = model.pinPoint(thread) {
                    PinDot(number: model.number(of: thread), chosen: model.selected == thread.id)
                        .opacity(thread.resolved ? 0.55 : 1)
                        .position(point)
                }
            }
            if let draft = model.draft {
                PinDot(number: model.threads(on: draft.placed).count + 1, chosen: true).position(point(of: draft))
            }
        }
    }

    private func point(of draft: Draft) -> CGPoint {
        let rect = model.onScreen(draft.placed.rect)
        return CGPoint(x: rect.minX + rect.width * draft.x, y: rect.minY + rect.height * draft.y)
    }

    /// The comment beside its pin, kept inside the canvas.
    @ViewBuilder private func bubble(in size: CGSize) -> some View {
        let width: CGFloat = 320
        if let draft = model.draft {
            let p = point(of: draft)
            NewComment(draft: draft).frame(width: width).id("\(draft.placed.id)\(draft.x)\(draft.y)")
                .offset(place(p, width: width, in: size))
        } else if let id = model.selected, let thread = model.allThreads.first(where: { $0.id == id }), let p = model.pinPoint(thread) {
            ThreadBubble(thread: thread).frame(width: width).id(thread.id)
                .offset(place(p, width: width, in: size))
        }
    }

    private func place(_ p: CGPoint, width: CGFloat, in size: CGSize) -> CGSize {
        let x = p.x + 22 + width > size.width - 12 ? p.x - 22 - width : p.x + 22
        let y = min(max(p.y - 16, 12), size.height - 260)
        return CGSize(width: max(x, 12), height: y)
    }
}

/// Takes the mouse, the trackpad and the keys for the canvas.
struct CanvasEvents: NSViewRepresentable {
    @Environment(Model.self) private var model

    func makeNSView(context: Context) -> EventView {
        let view = EventView()
        view.model = model
        // C comments; A and Esc go back to the cursor (Damian's keys, 1 Nov 2026). Not while he is typing in a field.
        view.keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak view] event in
            guard let view, let window = view.window, event.window == window, !(window.firstResponder is NSText) else { return event }
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
            return MainActor.assumeIsolated {
                guard let model = view.model else { return event }
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "c": model.tool = .comment
                case "a": model.tool = .move
                case "\u{1b}":
                    model.tool = .move
                    model.selected = nil
                    model.draft = nil
                case "=", "+": model.zoom(by: 1.25)
                case "-": model.zoom(by: 0.8)
                default: return event
                }
                return nil
            }
        }
        return view
    }

    static func dismantleNSView(_ view: EventView, coordinator: ()) {
        if let keys = view.keys { NSEvent.removeMonitor(keys) }
    }

    func updateNSView(_ view: EventView, context: Context) {
        view.model = model
        view.tool = model.tool
    }

    final class EventView: NSView {
        weak var model: Model?
        var keys: Any?
        var tool = Tool.comment {
            didSet { if tool != oldValue { window?.invalidateCursorRects(for: self) } }
        }
        private var pressed: NSPoint?
        private var dragged = false
        private var movingBoard = false

        override var isFlipped: Bool { true }
        /// The real size of the canvas, from the view that fills it.
        override func setFrameSize(_ size: NSSize) {
            super.setFrameSize(size)
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.model?.sized(size) }
            }
        }
        override var acceptsFirstResponder: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func resetCursorRects() { addCursorRect(bounds, cursor: tool == .comment ? .crosshair : .openHand) }
        override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }

        private func here(_ event: NSEvent) -> CGPoint { convert(event.locationInWindow, from: nil) }

        override func scrollWheel(with event: NSEvent) {
            MainActor.assumeIsolated {
                guard let model else { return }
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                    model.zoom(by: 1 + event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 0.01 : 0.05), at: here(event))
                } else {
                    let speed: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
                    model.pan(event.scrollingDeltaX * speed, event.scrollingDeltaY * speed)
                }
            }
        }

        override func magnify(with event: NSEvent) {
            MainActor.assumeIsolated { model?.zoom(by: 1 + event.magnification, at: here(event)) }
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            pressed = here(event)
            dragged = false
            let point = here(event)
            movingBoard = MainActor.assumeIsolated { model?.beginMove(at: point) ?? false }
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start = pressed else { return }
            let now = here(event)
            if !dragged, hypot(now.x - start.x, now.y - start.y) < 4 { return }
            dragged = true
            MainActor.assumeIsolated {
                if movingBoard { model?.move(event.deltaX, event.deltaY) } else { model?.pan(event.deltaX, event.deltaY) }
            }
        }

        // Holding the scroll wheel in moves the canvas, in either tool (Damian, 1 Nov 2026).
        override func otherMouseDragged(with event: NSEvent) {
            MainActor.assumeIsolated { model?.pan(event.deltaX, event.deltaY) }
        }

        override func mouseUp(with event: NSEvent) {
            MainActor.assumeIsolated {
                if movingBoard { model?.endMove() }
                if !dragged { model?.click(at: here(event)) }
            }
            movingBoard = false
            pressed = nil
        }

    }
}

// MARK: Comments on the canvas

struct NewComment: View {
    @Environment(Model.self) private var model
    let draft: Draft
    @State private var text = ""
    @FocusState private var writing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Write a comment", text: $text, axis: .vertical)
                .textFieldStyle(.plain).font(Style.body).foregroundStyle(Style.ink).lineLimit(1...8).focused($writing)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.shift) { return .ignored }
                    save()
                    return .handled
                }
                .onExitCommand { model.draft = nil; model.tool = .move }
            HStack(spacing: Style.tight) {
                Spacer()
                Button("Cancel") { model.draft = nil }.buttonStyle(PlainPill())
                Button("Post") { save() }.buttonStyle(PlainPill(on: true)).disabled(empty)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Style.corner).fill(Style.bubble))
        .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        .onAppear { writing = true }
    }

    private var empty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func save() {
        guard !empty, let app = model.app else { return }
        let saved = model.change {
            try $0.addThread(app: app, screen: draft.placed.screen.id, version: draft.placed.version.n, x: draft.x, y: draft.y, text: text, author: "Damian")
        }
        if saved != nil { model.draft = nil }
    }
}

struct ThreadBubble: View {
    @Environment(Model.self) private var model
    let thread: PinThread
    @State private var reply = ""
    @FocusState private var writing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(thread.resolved ? "Resolved" : "Comment \(model.number(of: thread))").font(Style.small.weight(.semibold)).foregroundStyle(Style.grey)
                Spacer()
                icon(thread.resolved ? "arrow.uturn.backward" : "checkmark", thread.resolved ? "Reopen" : "Resolve") {
                    model.change { try $0.setResolved(thread: thread.id, !thread.resolved) }
                    model.selected = nil
                }
                icon("xmark", "Close") { model.selected = nil }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider().overlay(Style.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(thread.messages) { message in
                        HStack(alignment: .top, spacing: 8) {
                            Avatar(name: message.author)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(message.author).font(Style.strong).foregroundStyle(Style.ink)
                                    Text(message.at.short).font(Style.small).foregroundStyle(Style.grey)
                                }
                                Text(message.text).font(Style.body).foregroundStyle(Style.ink).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 280)
            .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Style.line)
            TextField("Reply", text: $reply, axis: .vertical)
                .textFieldStyle(.plain).font(Style.body).foregroundStyle(Style.ink).lineLimit(1...6).focused($writing)
                .padding(12)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.shift) { return .ignored }
                    send()
                    return .handled
                }
                .onExitCommand { model.selected = nil; model.tool = .move }
        }
        .background(RoundedRectangle(cornerRadius: Style.corner).fill(Style.bubble))
        .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        .onAppear { writing = true }
    }

    private func icon(_ name: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 11, weight: .semibold)).foregroundStyle(Style.ink).frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(help)
    }

    private func send() {
        guard !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if model.change({ try $0.reply(thread: thread.id, text: reply, author: "Damian") }) != nil { reply = "" }
    }
}

// MARK: The list on the right

struct CommentsPanel: View {
    @Environment(Model.self) private var model

    var body: some View {
        @Bindable var model = model
        let list = model.allThreads.filter { !$0.resolved || model.showResolved }
        let done = model.allThreads.filter(\.resolved).count
        Group {
            if list.isEmpty {
                ContentUnavailableView("No comments", systemImage: "text.bubble", description: Text("Click a board to add one."))
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(list) { thread in row(thread) }
                    }
                    .padding(8)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if done > 0 {
                Toggle("Show resolved (\(done))", isOn: $model.showResolved)
                    .toggleStyle(.checkbox).font(Style.small).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.bar)
            }
        }
    }

    private func row(_ thread: PinThread) -> some View {
        let first = thread.messages.first
        return Button { model.reveal(thread) } label: {
            HStack(alignment: .top, spacing: 8) {
                PinDot(number: model.number(of: thread), chosen: model.selected == thread.id).scaleEffect(0.85).frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(first?.author ?? "").font(Style.strong).foregroundStyle(Style.ink)
                        Text(first?.at.short ?? "").font(Style.small).foregroundStyle(Style.grey)
                        Spacer(minLength: 0)
                        if thread.resolved { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Style.accent) }
                    }
                    Text(first?.text ?? "").font(Style.body).foregroundStyle(Style.ink).lineLimit(3).multilineTextAlignment(.leading)
                    Text(detail(thread)).font(Style.small).foregroundStyle(Style.grey).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(model.selected == thread.id ? Style.chosen : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func detail(_ thread: PinThread) -> String {
        let name = model.screens.first { $0.id == thread.screen }?.name ?? thread.screen
        let replies = thread.messages.count - 1
        return replies > 0 ? "\(name) · \(replies) \(replies == 1 ? "reply" : "replies")" : name
    }
}
