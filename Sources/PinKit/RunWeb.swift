import AppKit
import SwiftUI
import WebKit

// A website running in Pin's Run panel. Moved from Wink on 3 Nov 2026 (Damian: "i wanna have everything inside of pin that is about design").
// Pin starts the project's own dev server (npm/pnpm/yarn/bun run dev or start) or, for plain HTML, a small file server, and shows the page live.
// A dev server reloads by itself (hot reload); plain HTML reloads when a file changes. Closing the panel or quitting Pin stops the server.

/// A web project: a folder with a package.json that has a dev or start script, or an index.html.
/// Or a real website a picture board links to (3 Nov 2026: "maybe i can watch them inside of pin when i click on them"): https only, no server.
struct WebProject: Hashable, Sendable {
    enum Kind: Hashable, Sendable { case script(String), files, remote(URL) }
    let root: String
    let kind: Kind
    var title: String? = nil

    /// A board's website, when its link is a real https address.
    static func site(_ link: String, title: String) -> WebProject? {
        guard let url = URL(string: link), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        return WebProject(root: link, kind: .remote(url), title: title)
    }

    static func at(_ folder: String) -> WebProject? {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder, isDirectory: &isFolder), isFolder.boolValue else { return nil }
        if let data = FileManager.default.contents(atPath: folder + "/package.json"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let scripts = json["scripts"] as? [String: Any],
           let name = ["dev", "start", "serve", "preview"].first(where: { scripts[$0] != nil }) {
            return WebProject(root: folder, kind: .script(name))
        }
        if FileManager.default.fileExists(atPath: folder + "/index.html") { return WebProject(root: folder, kind: .files) }
        return nil
    }

    var name: String { title ?? (root as NSString).lastPathComponent }
}

/// Its own class, so Pin's keys (C, A, P) leave typing in the page alone.
final class RunWebView: WKWebView {}

/// How wide the page is drawn. A size wider than the pane is drawn whole and scaled down, as a real desktop screen would look.
enum WebSize: String, CaseIterable, Sendable {
    case fill = "Fill", desktop = "Desktop", tablet = "Tablet", phone = "Phone"
    var width: CGFloat? {
        switch self {
        case .fill: nil
        case .desktop: 1440
        case .tablet: 820
        case .phone: 390
        }
    }
    var icon: String {
        switch self {
        case .fill: "arrow.left.and.right"
        case .desktop: "desktopcomputer"
        case .tablet: "ipad"
        case .phone: "iphone"
        }
    }
}

@MainActor @Observable
final class WebPreview {
    enum State: Equatable { case starting, installing, running, failed(String) }

    let project: WebProject
    private(set) var state = State.starting
    private(set) var address: URL?
    var size: WebSize {
        didSet { UserDefaults.standard.set(size.rawValue, forKey: "preview.web.size") }
    }
    @ObservationIgnored let web: WKWebView
    @ObservationIgnored private var server: Process?
    @ObservationIgnored private var run: Task<Void, Never>?
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private var quitting: NSObjectProtocol?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var guardian: RemoteGuard?

    init(project: WebProject) {
        self.project = project
        size = WebSize(rawValue: UserDefaults.standard.string(forKey: "preview.web.size") ?? "") ?? .fill
        let setup = WKWebViewConfiguration()
        setup.websiteDataStore = .nonPersistent()
        web = RunWebView(frame: .zero, configuration: setup)
        web.allowsBackForwardNavigationGestures = true
        web.setValue(false, forKey: "drawsBackground")
        if case .remote = project.kind {
            let guardian = RemoteGuard()
            web.navigationDelegate = guardian
            web.uiDelegate = guardian
            self.guardian = guardian
        }
        quitting = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private var scratch: URL {
        let key = project.root.replacingOccurrences(of: "/", with: "_")
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Pin/RunWeb/\(key)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func startOnce() {
        guard !started else { return }
        started = true
        restart()
    }

    /// Stop the server and start it again.
    func restart() {
        run?.cancel()
        stopServer()
        state = .starting
        run = Task { await self.go() }
    }

    func reload() {
        if address == nil { restart() } else { web.reloadFromOrigin() }
    }
    func back() { web.goBack() }
    func openInBrowser() {
        guard let url = web.url ?? address else { return }
        let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        if FileManager.default.fileExists(atPath: chrome.path) {
            NSWorkspace.shared.open([url], withApplicationAt: chrome, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func close() {
        run?.cancel()
        watcher?.cancel()
        stopServer()
        if let quitting { NotificationCenter.default.removeObserver(quitting) }
        quitting = nil
    }

    private func go() async {
        if case .remote(let url) = project.kind {
            address = url
            state = .running
            web.load(URLRequest(url: url))
            await keepPicture(after: 8)
            return
        }
        let root = project.root
        let log = scratch.appendingPathComponent("server.log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let port = Self.freePort()
        let command: String
        switch project.kind {
        case .remote: return
        case .files:
            command = "exec /usr/bin/python3 -m http.server \(port) --bind 127.0.0.1"
        case .script(let script):
            let runner = Self.runner(root)
            if !FileManager.default.fileExists(atPath: root + "/node_modules") {
                state = .installing
                let installed = await Self.shell("\(runner) install", in: root, log: scratch.appendingPathComponent("install.log"))
                guard !Task.isCancelled else { return }
                guard installed == 0 else {
                    state = .failed("Installing the packages failed. " + Self.tail(scratch.appendingPathComponent("install.log")))
                    return
                }
            }
            command = "exec \(runner) run \(script)"
        }
        guard let server = Self.launch(command, in: root, port: port, log: log) else {
            state = .failed("Could not start the server")
            return
        }
        self.server = server
        let fallback = URL(string: "http://localhost:\(port)/")!
        // The address the server prints, else the port it was given, once something answers there.
        for _ in 0..<180 {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            if !server.isRunning {
                state = .failed("The server stopped. " + Self.tail(log))
                return
            }
            let printed = Self.address(in: (try? String(contentsOf: log, encoding: .utf8)) ?? "")
            let candidate = project.kind == .files ? fallback : printed ?? fallback
            if project.kind == .files || printed != nil, await Self.answers(candidate) {
                address = candidate
                state = .running
                web.load(URLRequest(url: candidate))
                if project.kind == .files { watch() }
                await keepPicture(after: 2)
                return
            }
        }
        state = .failed("The server did not answer in 90 seconds. " + Self.tail(log))
    }

    /// PIN_SHOT also keeps a picture of the page itself, which the window's picture cannot hold.
    private func keepPicture(after seconds: Int) async {
        guard let snapshot = ProcessInfo.processInfo.environment["PIN_SHOT"] else { return }
        try? await Task.sleep(for: .seconds(seconds))
        if let image = try? await web.takeSnapshot(configuration: nil), let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: snapshot.replacingOccurrences(of: ".png", with: "-web.png")))
        }
    }

    /// Plain HTML has no hot reload: the page reloads when a file in the folder changes.
    private func watch() {
        watcher?.cancel()
        let root = project.root
        watcher = Task { [weak self] in
            var last = await Task.detached { Self.newest(root) }.value
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let now = await Task.detached { Self.newest(root) }.value
                if now > last {
                    last = now
                    self?.web.reload()
                }
            }
        }
    }

    private nonisolated static func newest(_ root: String) -> Date {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        guard let walk = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return .distantPast }
        var newest = Date.distantPast
        var count = 0
        for case let url as URL in walk {
            count += 1
            if count > 3000 { break }
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true, url.lastPathComponent == "node_modules" { walk.skipDescendants(); continue }
            if let date = values?.contentModificationDate, date > newest { newest = date }
        }
        return newest
    }

    private func stopServer() {
        guard let server else { return }
        self.server = nil
        Self.stopTree(server.processIdentifier)
    }

    // MARK: Helpers

    private nonisolated static func runner(_ root: String) -> String {
        let has = { FileManager.default.fileExists(atPath: root + "/" + $0) }
        if has("bun.lockb") || has("bun.lock") { return "bun" }
        if has("pnpm-lock.yaml") { return "pnpm" }
        if has("yarn.lock") { return "yarn" }
        return "npm"
    }

    /// A login shell, so the PATH has node, npm and the rest the way Terminal has them.
    private nonisolated static func launch(_ command: String, in folder: String, port: Int, log: URL) -> Process? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = URL(fileURLWithPath: folder)
        var env = ProcessInfo.processInfo.environment
        env["PORT"] = String(port)
        env["BROWSER"] = "none"
        env["FORCE_COLOR"] = "0"
        env["NO_COLOR"] = "1"
        process.environment = env
        guard let handle = try? FileHandle(forWritingTo: log) else { return nil }
        process.standardOutput = handle
        process.standardError = handle
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        return process
    }

    private nonisolated static func shell(_ command: String, in folder: String, log: URL) async -> Int32 {
        FileManager.default.createFile(atPath: log.path, contents: nil)
        guard let process = launch(command, in: folder, port: 0, log: log) else { return -1 }
        return await withCheckedContinuation { done in
            process.terminationHandler = { done.resume(returning: $0.terminationStatus) }
        }
    }

    /// The server and everything it started (npm starts node, node starts esbuild).
    private nonisolated static func stopTree(_ pid: Int32) {
        var all = [pid]
        var index = 0
        while index < all.count {
            let children = Process()
            children.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            children.arguments = ["-P", String(all[index])]
            let pipe = Pipe()
            children.standardOutput = pipe
            try? children.run()
            children.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            all += out.split(separator: "\n").compactMap { Int32($0) }
            index += 1
        }
        for id in all.reversed() { kill(id, SIGTERM) }
    }

    private nonisolated static func freePort() -> Int {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        defer { Darwin.close(fd) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = 0
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, length) == 0 && getsockname(fd, $0, &length) == 0 }
        }
        return bound ? Int(UInt16(bigEndian: address.sin_port)) : 5199
    }

    nonisolated(unsafe) private static let printedAddress = try? NSRegularExpression(pattern: #"https?://(?:localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1?\]):\d+[^\s'"]*"#)
    nonisolated(unsafe) private static let colour = try? NSRegularExpression(pattern: #"\u001B\[[0-9;]*[A-Za-z]"#)

    nonisolated static func address(in log: String) -> URL? {
        guard let printedAddress, let colour else { return nil }
        let plain = colour.stringByReplacingMatches(in: log, range: NSRange(log.startIndex..., in: log), withTemplate: "")
        guard let match = printedAddress.firstMatch(in: plain, range: NSRange(plain.startIndex..., in: plain)),
              let range = Range(match.range, in: plain) else { return nil }
        let text = String(plain[range]).replacingOccurrences(of: "0.0.0.0", with: "localhost").replacingOccurrences(of: "[::]", with: "localhost")
        return URL(string: text)
    }

    private nonisolated static func answers(_ url: URL) async -> Bool {
        var request = URLRequest(url: url, timeoutInterval: 2)
        request.httpMethod = "GET"
        return (try? await URLSession.shared.data(for: request)) != nil
    }

    private nonisolated static func tail(_ log: URL) -> String {
        let text = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        let lines = text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lines.suffix(4).joined(separator: "\n")
    }
}


/// A linked website stays on https: other pages are not opened, and a link that opens a new window opens here instead.
private final class RemoteGuard: NSObject, WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        let scheme = action.request.url?.scheme?.lowercased() ?? ""
        let main = action.targetFrame?.isMainFrame ?? true
        decisionHandler(scheme == "https" || (!main && ["about", "data", "blob"].contains(scheme)) ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.request.url?.scheme?.lowercased() == "https" { webView.load(action.request) }
        return nil
    }
}
