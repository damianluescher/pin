import AppKit
import PinCore
import SwiftUI

// Pin inside Wink (25 Nov 2026, Damian: "I don't want to have Pin anymore as a separate app, rather have it inside of
// Wink"; "move everything from pin to buddy also give the option that i can open in the side panel different projects
// different apps"). Wink's side panel shows this view: the same canvas, live boards, comments and Run panel as the Pin app,
// for any app or project in Pin's store, laid out like Claude's side panel (analysis in
// ~/Documents/Wink-previews/claude-side-panel-analysis): the item's own line on top, the canvas, the tools floating at the
// bottom with Ask Buddy.

/// One canvas for the whole process, started once (it watches Pin's store and loads the live boards).
@MainActor public final class PinHost {
    public static let shared = PinHost()
    let model = Model()
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        model.start()
    }

    /// Whether the canvas goes to the board an AI works on. Wink sets it per chat (its Follow button).
    public var followCamera = true
    private var lastFocus: String?

    /// Pin's own name for an app, however it was written: "LUTCam", "lut cam" and "LUT Cam" are one file.
    public func name(of app: String) -> String? {
        start()
        let apps = model.store.apps()
        func plain(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
        return apps.first { $0 == app } ?? apps.first { plain($0) == plain(app) }
    }

    /// An AI works on this board now: opens the app, glides to the board (while following is on) and shows the green
    /// cursor there, unless `pin cursor` already says where it is. Called again with the same place, it only keeps the
    /// cursor alive and leaves the camera where he put it.
    public func focus(app: String, screen: String?, x: Double? = nil, y: Double? = nil, text: String? = nil) {
        guard let name = name(of: app) else { return }
        if model.app != name { model.open(name); lastFocus = nil }
        guard let screen, !screen.isEmpty else { return }
        let id = model.screen(named: screen)?.id ?? Store.slug(screen)
        model.show(spot: .init(screen: id, x: x ?? 0.5, y: y ?? 0.5, text: text ?? "", who: "Buddy"))
        let key = "\(name)/\(id)/\(x ?? -1)/\(y ?? -1)"
        guard followCamera, key != lastFocus else { return }
        lastFocus = key
        model.focus(screen: id, at: y.map { CGPoint(x: x ?? 0.5, y: $0) }, animated: true)
    }

    /// Every app and project in Pin's store, for Wink's New menu.
    public func apps() -> [String] {
        start()
        return model.store.apps()
    }
}

/// The boards fill the panel when it opens (they opened at Pin's own window's zoom, 8 %, "so many issues", 25 Nov).
@MainActor private func fitSoon(_ model: Model) {
    // Not over a board an AI was just sent to: the fit would throw the camera back out.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if Date().timeIntervalSince(model.focusedAt) > 3 { model.fit() } }
}

public struct PinPanel: View {
    let app: String
    let ask: (String) -> Void

    /// `ask` gets the words for the chat, with the app and the board they are about.
    public init(app: String, ask: @escaping (String) -> Void) {
        self.app = app
        self.ask = ask
    }

    public var body: some View {
        let model = PinHost.shared.model
        PanelBody(app: app, ask: ask)
            .environment(model)
            .onAppear {
                PinHost.shared.start()
                if model.app != app { model.open(app) }
                fitSoon(model)
            }
            .onChange(of: app) { if model.app != app { model.open(app) }; fitSoon(model) }
    }
}

private struct PanelBody: View {
    let app: String
    let ask: (String) -> Void
    @Environment(Model.self) private var model
    @AppStorage("panelComments") private var showComments = false
    @AppStorage("runWidth") private var runWidth: Double = 420
    @State private var asking = false
    @State private var words = ""
    @FocusState private var typing: Bool

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            line
            Divider().opacity(0.5)
            HStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Canvas()
                    tools.padding(.bottom, 16)
                }
                if model.run.isOpen {
                    RunEdge(width: $runWidth, range: 300...1200)
                    RunPanel(run: model.run).frame(width: runWidth)
                }
                if showComments {
                    Divider().opacity(0.5)
                    CommentsPanel().frame(width: 280)
                }
            }
            .onChange(of: model.app) { model.run.follow(app: model.app, store: model.store) }
        }
        .overlay(alignment: .bottom) {
            if let failure = model.failure {
                Text(failure).font(Style.body).padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.45, green: 0.12, blue: 0.12)))
                    .padding(.bottom, 72)
            }
        }
    }

    /// The item's own line, as Claude's: the page, then Refresh, Run and comments at the right.
    private var line: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(model.pages, id: \.self) { name in Button(name) { model.choose(page: name) } }
            } label: {
                Text(model.page ?? "All boards").lineLimit(1)
            }
            .menuStyle(.borderlessButton).fixedSize()
            .accessibilityLabel("Page, \(model.page ?? "All boards")")
            Spacer()
            ZoomMenu().menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Zoom, \(model.percent) %")
            icon("arrow.up.left.and.arrow.down.right.square", "Fit the boards to the panel") { model.fit() }
            icon("arrow.clockwise", "Refresh all boards") { model.reload(); LiveBoards.refreshWebBoards(); LiveBoards.refreshSwiftBoards() }
            icon(model.run.isOpen ? "stop.fill" : "play.fill", "Run the real app or website beside the boards") {
                model.run.toggle(app: app, store: model.store)
            }
            icon("text.bubble", "Comments", on: showComments) { showComments.toggle() }
        }
        .font(Style.body)
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    /// Floating at the bottom, as on Claude's board: cursor, comment, press, then Ask Buddy.
    private var tools: some View {
        @Bindable var model = model
        return VStack(spacing: 8) {
            if asking {
                HStack(spacing: 8) {
                    TextField(target.map { "Describe a change to \($0)" } ?? "Describe a change", text: $words)
                        .textFieldStyle(.plain).focused($typing)
                        .accessibilityLabel("Describe a change")
                        .onSubmit(send)
                    Button(action: send) {
                        Image(systemName: "arrow.up").font(.body.weight(.semibold)).foregroundStyle(.black)
                            .frame(width: 26, height: 26).background(Circle().fill(Color.white))
                    }
                    .buttonStyle(.plain).disabled(words.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Send to the chat")
                }
                .padding(.horizontal, 14).frame(width: 440, height: 48)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.11)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12)))
            }
            HStack(spacing: 4) {
                tool(.move, "cursorarrow", "Cursor (A or Esc)")
                tool(.comment, "text.bubble", "Comment (C)")
                tool(.press, "hand.point.up.left", "Press (P)")
                Button { asking.toggle(); if asking { typing = true } } label: {
                    Text("Ask Buddy").padding(.horizontal, 12).frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 9).fill(asking ? Color.white.opacity(0.16) : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 13).fill(Color(white: 0.11)))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.12)))
        }
        .font(Style.body)
    }

    /// The board the words are about: the selected one, else none.
    private var target: String? {
        guard let id = model.selected else { return nil }
        return model.screens.first { $0.id == id }?.name
    }

    private func send() {
        let text = words.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let about = target.map { "the \($0) board" } ?? "the boards"
        ask("\(text)\n\n(Asked from the side panel, about \(about) of \(app) in Pin.)")
        words = ""
        asking = false
    }

    private func tool(_ which: Tool, _ symbol: String, _ help: String) -> some View {
        Button { model.tool = which } label: {
            Image(systemName: symbol).frame(width: 32, height: 32)
                .foregroundStyle(model.tool == which ? Color.black : Color.primary)
                .background(RoundedRectangle(cornerRadius: 9).fill(model.tool == which ? Color(red: 0.24, green: 0.84, blue: 0.52) : .clear))
                .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain).help(help).accessibilityLabel(help)
    }

    private func icon(_ symbol: String, _ help: String, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 28, height: 28)
                .foregroundStyle(on ? Color.primary : Color.secondary)
                .background(RoundedRectangle(cornerRadius: 7).fill(on ? Color.white.opacity(0.1) : .clear))
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
}
