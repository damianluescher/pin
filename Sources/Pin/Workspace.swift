import AppKit
import PinCore
import SwiftUI

/// The canvas. Everything that moves with the camera lives in AppKit (see Stage.swift); SwiftUI only says what is on
/// the page and shows the comment beside its pin. This body does not read the camera, so zooming never reruns it.
struct Canvas: View {
    @Environment(Model.self) private var model

    var body: some View {
        GeometryReader { box in
            ZStack(alignment: .topLeading) {
                CanvasEvents(scene: scene)
                CanvasBubble(size: box.size)
            }
            .clipped()
        }
    }

    private var scene: StageScene {
        var pins = model.allThreads.compactMap { thread -> StageScene.Pin? in
            guard !thread.resolved || model.showResolved || model.selected == thread.id,
                  let box = model.placed.first(where: { $0.screen.id == thread.screen && $0.version.n == thread.version }) else { return nil }
            return StageScene.Pin(number: model.number(of: thread), chosen: model.selected == thread.id, faded: thread.resolved,
                                  spot: CGPoint(x: box.rect.minX + box.rect.width * thread.x, y: box.rect.minY + box.rect.height * thread.y))
        }
        if let draft = model.draft {
            let rect = draft.placed.rect
            pins.append(StageScene.Pin(number: model.threads(on: draft.placed).count + 1, chosen: true, faded: false,
                                       spot: CGPoint(x: rect.minX + rect.width * draft.x, y: rect.minY + rect.height * draft.y)))
        }
        return StageScene(app: model.app, page: model.page, boards: model.placed, pins: pins, flows: model.flowLines)
    }
}

/// The comment beside its pin, kept inside the canvas. It alone follows the camera through SwiftUI, and only while one is open.
private struct CanvasBubble: View {
    @Environment(Model.self) private var model
    let size: CGSize

    var body: some View {
        let width: CGFloat = 320
        let _ = model.bubbleTick
        if let draft = model.draft {
            let p = point(of: draft)
            NewComment(draft: draft).frame(width: width).id("\(draft.placed.id)\(draft.x)\(draft.y)")
                .offset(place(p, width: width))
        } else if let id = model.selected, let thread = model.allThreads.first(where: { $0.id == id }), let p = model.pinPoint(thread) {
            ThreadBubble(thread: thread).frame(width: width).id(thread.id)
                .offset(place(p, width: width))
        }
    }

    private func point(of draft: Draft) -> CGPoint {
        let rect = model.onScreen(draft.placed.rect)
        return CGPoint(x: rect.minX + rect.width * draft.x, y: rect.minY + rect.height * draft.y)
    }

    private func place(_ p: CGPoint, width: CGFloat) -> CGSize {
        let x = p.x + 22 + width > size.width - 12 ? p.x - 22 - width : p.x + 22
        let y = min(max(p.y - 16, 12), size.height - 260)
        return CGSize(width: max(x, 12), height: y)
    }
}

/// Takes the mouse, the trackpad and the keys for the canvas.
struct CanvasEvents: NSViewRepresentable {
    @Environment(Model.self) private var model
    let scene: StageScene

    func makeNSView(context: Context) -> Stage {
        let stage = Stage(model: model)
        let view = stage.events
        view.model = model
        // C comments; A and Esc go back to the cursor; P presses (Damian, 1 Nov 2026). Not while he is typing in a field.
        view.keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak view] event in
            guard let view, let window = view.window, event.window == window else { return event }
            return MainActor.assumeIsolated {
                guard let model = view.model else { return event }
                let isEsc = event.charactersIgnoringModifiers == "\u{1b}"
                // Typing in a running board keeps every key, except Esc, which leaves the board.
                if let board = LiveBoards.board(holding: window.firstResponder), board.isTyping(window.firstResponder) {
                    guard isEsc else { return event }
                    model.tool = .move
                    window.makeFirstResponder(view)
                    return nil
                }
                guard !(window.firstResponder is NSText) else { return event }
                // Keys typed into the Run panel's app or page are its own.
                guard !RunPanelModel.owns(window.firstResponder) else { return event }
                guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "c": model.tool = .comment
                case "a": model.tool = .move
                case "p": model.tool = .press
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
        return stage
    }

    static func dismantleNSView(_ stage: Stage, coordinator: ()) {
        if let keys = stage.events.keys { NSEvent.removeMonitor(keys) }
    }

    func updateNSView(_ stage: Stage, context: Context) {
        stage.events.model = model
        stage.events.tool = model.tool
        stage.show(scene)
    }

    final class EventView: NSView {
        weak var model: Model?
        var keys: Any?
        var tool = Tool.comment {
            didSet {
                guard tool != oldValue else { return }
                window?.invalidateCursorRects(for: self)
                // Leaving press mode takes the keys back from a screen inside a board.
                if tool != .press, let window, LiveBoards.board(holding: window.firstResponder) != nil { window.makeFirstResponder(self) }
            }
        }
        private var pressed: NSPoint?
        private var dragged = false
        private var movingBoard = false
        private var lastPoint: NSPoint?

        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: tool == .comment ? .crosshair : tool == .press ? .pointingHand : .openHand)
        }

        /// In press mode this view hands the input to the screen under the mouse, so it arrives the normal way:
        /// buttons, scrolling, text fields and web pages then work as they do in any window. What stays with the
        /// canvas: zooming, panning with the middle button, comment dots, and everywhere that is not a running board.
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let own = super.hitTest(point) else { return nil }
            return MainActor.assumeIsolated {
                guard let model, model.tool == .press else { return own }
                if let event = NSApp.currentEvent {
                    switch event.type {
                    case .magnify, .smartMagnify, .rotate, .otherMouseDown, .otherMouseDragged, .otherMouseUp: return own
                    case .scrollWheel where !event.modifierFlags.intersection([.command, .control]).isEmpty: return own
                    default: break
                    }
                }
                let here = convert(point, from: superview)
                guard model.pin(at: here) == nil else { return own }
                return model.pressTarget(at: here, inWindow: convert(here, to: nil)) ?? own
            }
        }
        override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }

        private func here(_ event: NSEvent) -> CGPoint { convert(event.locationInWindow, from: nil) }

        override func scrollWheel(with event: NSEvent) {
            MainActor.assumeIsolated {
                guard let model else { return }
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                    let factor = CGFloat(ZoomStep.factor(delta: event.scrollingDeltaY, precise: event.hasPreciseScrollingDeltas))
                    // A trackpad already sends small steps; a wheel's notches are glided between.
                    if event.hasPreciseScrollingDeltas { model.zoom(by: factor, at: here(event)) } else { model.glideZoom(by: factor, at: here(event)) }
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
            let last = lastPoint ?? start
            lastPoint = now
            MainActor.assumeIsolated {
                if movingBoard { model?.move(now.x - last.x, now.y - last.y) } else { model?.pan(now.x - last.x, now.y - last.y) }
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
            lastPoint = nil
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
        let shown = model.allThreads.filter { !$0.resolved || model.showResolved }
        let general = shown.filter { $0.screen == Store.general }
        let list = shown.filter { $0.screen != Store.general }
        let done = model.allThreads.filter(\.resolved).count
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                // Comments on the whole file, on no board.
                Text("Whole file").font(Style.small.weight(.semibold)).foregroundStyle(Style.grey).padding(.horizontal, 8).padding(.top, 4)
                GeneralField()
                ForEach(general) { thread in
                    row(thread)
                    if model.selected == thread.id { ThreadBubble(thread: thread).padding(.bottom, 8) }
                }
                Text("On boards").font(Style.small.weight(.semibold)).foregroundStyle(Style.grey).padding(.horizontal, 8).padding(.top, 16)
                if list.isEmpty {
                    Text("Click a board to add one.").font(Style.body).foregroundStyle(Style.grey).padding(8)
                }
                ForEach(list) { thread in row(thread) }
            }
            .padding(8)
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
        let name = thread.screen == Store.general ? "Whole file" : model.screens.first { $0.id == thread.screen }?.name ?? thread.screen
        let replies = thread.messages.count - 1
        return replies > 0 ? "\(name) · \(replies) \(replies == 1 ? "reply" : "replies")" : name
    }
}

/// Writes a comment on the whole file: Return sends it, Shift-Return makes a new line.
private struct GeneralField: View {
    @Environment(Model.self) private var model
    @State private var text = ""

    var body: some View {
        TextField("Comment on everything…", text: $text, axis: .vertical)
            .textFieldStyle(.plain).font(Style.body).foregroundStyle(Style.ink).lineLimit(1...6)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Style.raised))
            .padding(.vertical, 4)
            .onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.shift) { return .ignored }
                send()
                return .handled
            }
    }

    private func send() {
        guard let app = model.app, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if model.change({ try $0.addGeneralThread(app: app, text: text, author: "Damian") }) != nil { text = "" }
    }
}
