import AppKit
import PinCore
import SwiftUI

/// A file open: pages and boards on the left, the canvas in the middle, comments on the right.
struct Workspace: View {
    @Environment(Model.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            LeftPanel()
            Canvas()
            CommentsPanel()
        }
        .ignoresSafeArea()
    }
}

struct LeftPanel: View {
    @Environment(Model.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button { model.closeFile() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold)).frame(width: 24, height: 24).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Style.grey).help("All files")
                Text(model.app ?? "").font(Style.strong).foregroundStyle(Style.ink).lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.top, 44)
            .padding(.bottom, 12)
            Divider().overlay(Style.line)
            heading("Pages")
            VStack(spacing: 1) {
                ForEach(model.pages, id: \.self) { name in
                    Button { model.choose(page: name) } label: { Text(name).lineLimit(1) }.buttonStyle(SideRow(chosen: model.page == name))
                }
            }
            .padding(.horizontal, 10)
            Divider().overlay(Style.line).padding(.top, 12)
            heading("Boards")
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(model.pageScreens) { screen in
                        Button { model.reveal(screen) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: icon(screen.kind)).font(.system(size: 11)).foregroundStyle(Style.grey).frame(width: 14)
                                Text(screen.name).lineLimit(1)
                                Spacer(minLength: 0)
                                if let last = screen.latest, last.n > 1 { Text("v\(last.n)").font(Style.small).foregroundStyle(Style.grey) }
                            }
                        }
                        .buttonStyle(SideRow())
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(width: 240)
        .background(Style.side)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(Style.small.weight(.semibold)).foregroundStyle(Style.grey).padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 6)
    }

    private func icon(_ kind: Kind) -> String {
        switch kind {
        case .iphone: "iphone"
        case .mac: "macwindow"
        case .web: "globe"
        }
    }
}

struct Canvas: View {
    @Environment(Model.self) private var model

    var body: some View {
        GeometryReader { box in
            ZStack(alignment: .topLeading) {
                Style.canvas
                CanvasEvents()
                boards(in: box.size).allowsHitTesting(false)
                pins.allowsHitTesting(false)
                bubble(in: box.size)
                toolbar(in: box.size)
            }
            .clipped()
            .onAppear { sized(box.size) }
            .onChange(of: box.size) { _, new in sized(new) }
        }
    }

    private func sized(_ size: CGSize) {
        let first = model.viewport != size
        model.viewport = size
        if first { model.fit() }
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
        let y = min(max(p.y - 16, 56), size.height - 260)
        return CGSize(width: max(x, 12), height: y)
    }

    private func toolbar(in size: CGSize) -> some View {
        @Bindable var model = model
        return HStack {
            Spacer()
            HStack(spacing: 2) {
                tool(.move, "cursorarrow", "Move")
                tool(.comment, "text.bubble", "Comment")
            }
            .padding(4)
            .background(Capsule().fill(Style.side))
            Spacer()
        }
        .overlay(alignment: .trailing) {
            HStack(spacing: 2) {
                Button { model.zoom(by: 0.8) } label: { Image(systemName: "minus").frame(width: 24, height: 24).contentShape(Rectangle()) }
                Button { model.fit() } label: { Text("\(Int(model.scale * 100))%").font(Style.small).monospacedDigit().frame(width: 46, height: 24).contentShape(Rectangle()) }.help("Fit page")
                Button { model.zoom(by: 1.25) } label: { Image(systemName: "plus").frame(width: 24, height: 24).contentShape(Rectangle()) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Style.ink)
            .font(.system(size: 11, weight: .semibold))
            .padding(4)
            .background(Capsule().fill(Style.side))
            .padding(.trailing, 12)
        }
        .padding(.top, 12)
        .frame(width: size.width)
    }

    private func tool(_ which: Tool, _ icon: String, _ help: String) -> some View {
        Button { model.tool = which } label: {
            Image(systemName: icon).font(.system(size: 13, weight: .medium))
                .frame(width: 32, height: 28)
                .background(Capsule().fill(model.tool == which ? Color.white : .clear))
                .foregroundStyle(model.tool == which ? .black : Style.ink)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Takes the mouse, the trackpad and the keys for the canvas.
struct CanvasEvents: NSViewRepresentable {
    @Environment(Model.self) private var model

    func makeNSView(context: Context) -> EventView {
        let view = EventView()
        view.model = model
        return view
    }

    func updateNSView(_ view: EventView, context: Context) {
        view.model = model
        view.tool = model.tool
    }

    final class EventView: NSView {
        weak var model: Model?
        var tool = Tool.comment {
            didSet { if tool != oldValue { window?.invalidateCursorRects(for: self) } }
        }
        private var pressed: NSPoint?
        private var dragged = false

        override var isFlipped: Bool { true }
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
                    model.origin.x += event.scrollingDeltaX * speed
                    model.origin.y += event.scrollingDeltaY * speed
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
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start = pressed else { return }
            let now = here(event)
            if !dragged, hypot(now.x - start.x, now.y - start.y) < 4 { return }
            dragged = true
            MainActor.assumeIsolated {
                model?.origin.x += event.deltaX
                model?.origin.y += event.deltaY
            }
        }

        override func mouseUp(with event: NSEvent) {
            if !dragged { MainActor.assumeIsolated { model?.click(at: here(event)) } }
            pressed = nil
        }

        override func keyDown(with event: NSEvent) {
            MainActor.assumeIsolated {
                guard let model else { return }
                switch event.charactersIgnoringModifiers {
                case "c": model.tool = .comment
                case "v": model.tool = .move
                case "=", "+": model.zoom(by: 1.25)
                case "-": model.zoom(by: 0.8)
                case "\u{1b}": model.selected = nil; model.draft = nil
                default: super.keyDown(with: event)
                }
            }
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
                .onExitCommand { model.draft = nil }
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
                .onExitCommand { model.selected = nil }
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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Comments").font(Style.strong).foregroundStyle(Style.ink)
                Spacer()
                Menu {
                    Toggle("Show resolved (\(done))", isOn: $model.showResolved)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease").font(.system(size: 12, weight: .medium)).foregroundStyle(Style.grey)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.top, 44)
            .padding(.bottom, 12)
            Divider().overlay(Style.line)
            if list.isEmpty {
                Text("Click a board to comment").font(Style.body).foregroundStyle(Style.grey).padding(14)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(list) { thread in row(thread) }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 300)
        .background(Style.side)
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
