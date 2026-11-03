import AppKit
import PinCore
import SwiftUI
import WebKit

// The Run panel: the file's real app or website, running beside the canvas (Damian, 3 Nov 2026: "i wanna have everything inside of pin that is
// about design so that also includes the app preview we have inside of wink and the website so lets swap everything into pin"). An iPhone project
// runs on the simulator "Pin Preview" and is clicked through like a phone; a website runs on its own dev server, at Fill, Desktop, Tablet or Phone
// width. The panel's left edge drags it wider or narrower. Which folder runs is `run.json` beside the file's screens (`pin run APP FOLDER`).

@MainActor @Observable final class RunPanelModel {
    enum Running { case phone(SimPreview), web(WebPreview) }
    private(set) var app: String?
    private(set) var folder: String?
    private(set) var running: Running?
    var isOpen = false

    /// Opens or closes the panel for this file.
    func toggle(app: String, store: Store) {
        if isOpen, self.app == app { close(); return }
        open(app: app, store: store)
    }

    func open(app: String, store: Store) {
        stop()
        self.app = app
        folder = store.runFolder(app: app)
        isOpen = true
        start()
    }

    /// Another file was opened: what ran for the last one stops.
    func follow(app: String?, store: Store) {
        guard isOpen, app != self.app else { return }
        if let app { open(app: app, store: store) } else { close() }
    }

    func choose(folder: String, store: Store) {
        guard let app else { return }
        try? store.setRunFolder(app: app, folder: folder)
        stop()
        self.folder = folder
        start()
    }

    func close() {
        stop()
        isOpen = false
    }

    private func start() {
        guard let folder else { return }
        if let phone = PreviewProject.at(folder) {
            running = .phone(SimPreview(project: phone))
        } else if let site = WebProject.at(folder) {
            running = .web(WebPreview(project: site))
        } else {
            running = nil
        }
    }

    private func stop() {
        switch running {
        case .phone(let phone): phone.close()
        case .web(let web): web.close()
        case nil: break
        }
        running = nil
    }

    /// Typing goes to the running app, not to Pin's keys.
    static func owns(_ responder: NSResponder?) -> Bool {
        var view = responder as? NSView
        while let current = view {
            if current is RunWebView || current is PreviewPhoneView || current is PreviewScreenView { return true }
            view = current.superview
        }
        return false
    }
}

struct RunPanel: View {
    let run: RunPanelModel
    @Environment(Model.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Style.tight) {
                title
                Spacer(minLength: 0)
                controls
                Button { choose() } label: { Image(systemName: "folder") }.help("Choose the folder to run")
                Button { run.close() } label: { Image(systemName: "xmark") }.help("Close")
            }
            .buttonStyle(.borderless)
            .font(Style.body)
            .foregroundStyle(Style.grey)
            .padding(.horizontal, Style.gap)
            .frame(height: 44)
            Rectangle().fill(Style.line).frame(height: 1)
            content
                .padding(Style.tight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Style.side)
    }

    @ViewBuilder private var title: some View {
        switch run.running {
        case .phone(let phone):
            if phone.apps.count > 1 {
                Menu {
                    ForEach(phone.apps, id: \.self) { option in
                        Button(option.name) { phone.pick(option) }
                    }
                } label: { Text(phone.name).font(Style.strong) }
                .menuStyle(.borderlessButton).fixedSize()
            } else {
                Text(phone.name).font(Style.strong).foregroundStyle(Style.ink).lineLimit(1)
            }
            Text(phone.device).font(Style.small).lineLimit(1)
        case .web(let web):
            Text(web.project.name).font(Style.strong).foregroundStyle(Style.ink).lineLimit(1)
            if let address = web.address {
                Text(verbatim: "\(address.host(percentEncoded: false) ?? ""):\(String(address.port ?? 80))").font(Style.small).lineLimit(1)
            }
        case nil:
            Text("Run").font(Style.strong).foregroundStyle(Style.ink)
        }
    }

    @ViewBuilder private var controls: some View {
        switch run.running {
        case .phone(let phone):
            Button { phone.runAgain() } label: { Image(systemName: "arrow.clockwise") }.help("Build and run again")
            Button { phone.home() } label: { Image(systemName: "house") }.help("Home")
        case .web(let web):
            Menu {
                ForEach(WebSize.allCases, id: \.self) { size in
                    Button { web.size = size } label: {
                        Label(size.width.map { "\(size.rawValue) · \(Int($0))" } ?? size.rawValue, systemImage: size == web.size ? "checkmark" : size.icon)
                    }
                }
            } label: { Image(systemName: web.size.icon) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Size")
            Button { web.back() } label: { Image(systemName: "chevron.left") }.help("Back")
            Button { web.reload() } label: { Image(systemName: "arrow.clockwise") }.help("Reload")
            Button { web.openInBrowser() } label: { Image(systemName: "safari") }.help("Open in Chrome")
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder private var content: some View {
        switch run.running {
        case .phone(let phone): PhoneRun(model: phone)
        case .web(let web): WebRun(model: web)
        case nil:
            VStack(spacing: Style.gap) {
                Text(run.folder == nil ? "Choose the folder of this file's app or website." : "No iPhone app or website in this folder.")
                    .font(Style.body).foregroundStyle(Style.grey).multilineTextAlignment(.center)
                Button("Choose Folder…") { choose() }.buttonStyle(PlainPill())
            }
            .padding(Style.edge)
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Run"
        panel.message = "The folder of the iPhone app (Xcode project) or website (package.json or index.html)"
        if let folder = run.folder { panel.directoryURL = URL(fileURLWithPath: folder) }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        run.choose(folder: url.path, store: model.store)
    }
}

/// The phone, from Wink's pane.
private struct PhoneRun: View {
    let model: SimPreview

    var body: some View {
        ZStack {
            PreviewPhone(model: model, chrome: model.chrome, live: model.state == .running)
            status.allowsHitTesting(false)
        }
        .aspectRatio(model.chrome.whole.width / model.chrome.whole.height, contentMode: .fit)
        .task(id: ObjectIdentifier(model)) { model.startOnce() }
    }

    @ViewBuilder private var status: some View {
        switch model.state {
        case .running: EmptyView()
        case .starting, .building:
            HStack(spacing: Style.tight) {
                ProgressView().controlSize(.small)
                Text(model.state == .building ? "Building…" : "Starting the simulator…").font(Style.small)
            }
        case .failed(let why):
            Text(why).font(Style.small).foregroundStyle(Style.grey).multilineTextAlignment(.center).lineLimit(8).padding(Style.edge)
        }
    }
}

/// The page. A size wider than the panel is laid out at its width and scaled down, as that screen would show it.
private struct WebRun: View {
    let model: WebPreview

    var body: some View {
        GeometryReader { box in
            let wanted = model.size.width ?? box.size.width
            let shown = min(wanted, box.size.width)
            ZStack {
                WebPage(web: model.web, zoom: shown / wanted)
                    .frame(width: shown)
                    .clipShape(RoundedRectangle(cornerRadius: Style.tight, style: .continuous))
                    .opacity(model.state == .running ? 1 : 0)
                status.allowsHitTesting(false)
            }
            .frame(width: box.size.width, height: box.size.height)
        }
        .task(id: ObjectIdentifier(model)) { model.startOnce() }
    }

    @ViewBuilder private var status: some View {
        switch model.state {
        case .running: EmptyView()
        case .starting, .installing:
            HStack(spacing: Style.tight) {
                ProgressView().controlSize(.small)
                Text(model.state == .installing ? "Installing packages…" : "Starting the site…").font(Style.small)
            }
        case .failed(let why):
            Text(why).font(Style.small).foregroundStyle(Style.grey).multilineTextAlignment(.center).lineLimit(10).padding(Style.edge)
                .textSelection(.enabled)
        }
    }
}

private struct WebPage: NSViewRepresentable {
    let web: WKWebView
    let zoom: CGFloat
    func makeNSView(context: Context) -> WKWebView { web }
    func updateNSView(_ view: WKWebView, context: Context) {
        if abs(view.pageZoom - zoom) > 0.001 { view.pageZoom = zoom }
    }
}

/// The panel's left edge: drag it to make the panel wider or narrower.
struct RunEdge: View {
    @Binding var width: Double
    let range: ClosedRange<CGFloat>
    @State private var from: Double?
    @State private var pushed = false

    var body: some View {
        Rectangle().fill(Style.line)
            .frame(width: 1)
            .overlay { Color.clear.frame(width: 9).contentShape(Rectangle())
                .onHover { inside in
                    if inside, !pushed { NSCursor.resizeLeftRight.push(); pushed = true }
                    if !inside, pushed { NSCursor.pop(); pushed = false }
                }
                .onDisappear { if pushed { NSCursor.pop(); pushed = false } }
                .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        let start = from ?? min(max(width, range.lowerBound), range.upperBound)
                        from = start
                        width = min(max(start - drag.translation.width, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in from = nil })
            }
    }
}
