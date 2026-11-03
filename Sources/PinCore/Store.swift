import Foundation
import ImageIO

// Everything Pin knows lives in plain files, so the app and the agents' `pin` command share it with no server:
//   <home>/<app>/<screen>/screen.json          name, kind, versions
//   <home>/<app>/<screen>/v3.png               the picture of version 3
//   <home>/<app>/<screen>/threads/<id>.json    one comment thread, one file, so two writers never overwrite each other

public enum Kind: String, Codable, CaseIterable, Sendable {
    case iphone, mac, web
    public var title: String {
        switch self {
        case .iphone: "iPhone"
        case .mac: "Mac"
        case .web: "Web"
        }
    }
}

public struct Version: Codable, Equatable, Identifiable, Sendable {
    public var n: Int
    public var file: String
    public var created: Date
    public var note: String?
    public var id: Int { n }
}

public struct Screen: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var kind: Kind
    public var order: Int
    /// The page it sits on, like a page in a design file. Without one it goes on a page named after its kind.
    public var page: String?
    /// Where the code of this screen is, for the agent that changes it.
    public var source: String?
    /// The real website a picture board shows (an https link): clicking the board opens it in the Run panel.
    public var link: String?
    public var versions: [Version]
    public var latest: Version? { versions.last }
    public var pageName: String { page ?? kind.title }
}

public struct Message: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var author: String
    public var text: String
    public var at: Date
}

public struct PinThread: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var app: String
    public var screen: String
    public var version: Int
    /// Where on the picture, as shares of its width and height.
    public var x: Double
    public var y: Double
    public var resolved: Bool
    public var created: Date
    public var messages: [Message]
}

/// One step of a flow: tapping something on one board leads to another.
public struct FlowEdge: Codable, Equatable, Hashable, Sendable {
    public var from: String
    public var to: String
    public var label: String?
    public init(from: String, to: String, label: String? = nil) {
        self.from = from
        self.to = to
        self.label = label
    }
}

/// A board whose real code is a web page. Only pages on this Mac: a file, or a server already running on localhost.
public struct WebBoard: Codable, Equatable, Sendable {
    public var url: String
    public var width: Double
    public var height: Double
    /// Keep the page's cookies and storage between runs. Without this a board starts clean each time.
    public var persistent: Bool?

    public init(url: String, width: Double, height: Double, persistent: Bool? = nil) {
        self.url = url
        self.width = width
        self.height = height
        self.persistent = persistent
    }

    /// The page to open, or nil when the address is not allowed or the size is unusable: the board then stays a picture.
    public var address: URL? {
        guard width > 0, height > 0, let found = URL(string: url), Self.allows(found) else { return nil }
        return found
    }

    public static func allows(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "file": return true
        case "http": return ["localhost", "127.0.0.1", "::1"].contains(url.host?.lowercased() ?? "")
        default: return false
        }
    }
}

/// An app whose boards run live. `library`, `size` and `boards` name screens built from its Swift code, by board id;
/// `web` names boards that are web pages. An app may have either or both, so each part may be missing from the file.
public struct LiveConfig: Codable, Equatable, Sendable {
    public struct Size: Codable, Equatable, Sendable {
        public var width: Double
        public var height: Double
    }
    public var library: String
    public var size: Size
    /// A board that is not the usual size, by board id. Older files simply do not have this.
    public var sizes: [String: Size]?
    public var boards: [String: String]
    /// Older files simply do not have this.
    public var web: [String: WebBoard]?

    private enum CodingKeys: String, CodingKey { case library, size, sizes, boards, web }

    public init(from decoder: Decoder) throws {
        let file = try decoder.container(keyedBy: CodingKeys.self)
        library = try file.decodeIfPresent(String.self, forKey: .library) ?? ""
        size = try file.decodeIfPresent(Size.self, forKey: .size) ?? Size(width: 393, height: 852)
        sizes = try file.decodeIfPresent([String: Size].self, forKey: .sizes)
        boards = try file.decodeIfPresent([String: String].self, forKey: .boards) ?? [:]
        web = try file.decodeIfPresent([String: WebBoard].self, forKey: .web)
    }

    public func size(of board: String) -> Size {
        if let page = webBoard(board) { return Size(width: page.width, height: page.height) }
        return sizes?[board] ?? size
    }

    /// The web page of this board, if it has one Pin may open.
    public func webBoard(_ board: String) -> WebBoard? {
        guard let page = web?[board], page.address != nil else { return nil }
        return page
    }

    public var hasWeb: Bool { !(web ?? [:]).isEmpty }
}

public enum PinError: LocalizedError, Equatable {
    case notFound(String)
    case invalid(String)
    public var errorDescription: String? {
        switch self {
        case .notFound(let what): "Not found: \(what)"
        case .invalid(let why): why
        }
    }
}

public struct Store: Sendable {
    public let home: URL

    public init(home: URL? = nil) {
        if let home {
            self.home = home
        } else if let path = ProcessInfo.processInfo.environment["PIN_HOME"], !path.isEmpty {
            self.home = URL(fileURLWithPath: path)
        } else {
            self.home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Pin")
        }
    }

    public static func slug(_ text: String) -> String {
        let parts = text.lowercased().split { !($0.isLetter || $0.isNumber) }
        return parts.joined(separator: "-")
    }

    // MARK: Reading

    public func apps() -> [String] {
        folders(in: home).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// The folder of a file's general comments: about everything, on no board (Damian, 3 Nov 2026: "there should be a overall comment section
    /// ... that is regarding everythign"). It holds only `threads`, no screen.
    public static let general = "_general"

    public func screens(app: String) throws -> [Screen] {
        try folders(in: appURL(app)).filter { $0 != Self.general }.map { try screen(app: app, id: $0) }
            .sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    public func screen(app: String, id: String) throws -> Screen {
        let url = screenURL(app, id).appendingPathComponent("screen.json")
        guard FileManager.default.fileExists(atPath: url.path) else { throw PinError.notFound("\(app)/\(id)") }
        return try Self.decoder.decode(Screen.self, from: Data(contentsOf: url))
    }

    public func picture(app: String, screen: String, version: Version) -> URL {
        screenURL(app, screen).appendingPathComponent(version.file)
    }

    /// Oldest first: a pin's number is its place in this list on its version.
    public func threads(app: String, screen: String) throws -> [PinThread] {
        let folder = screenURL(app, screen).appendingPathComponent("threads")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return try names.filter { $0.hasSuffix(".json") }
            .map { try Self.decoder.decode(PinThread.self, from: Data(contentsOf: folder.appendingPathComponent($0))) }
            .sorted { ($0.created, $0.id) < ($1.created, $1.id) }
    }

    public func thread(id: String) throws -> PinThread {
        guard let found = try allThreads().first(where: { $0.id == id }) else { throw PinError.notFound("comment \(id)") }
        return found
    }

    public func allThreads(app: String? = nil) throws -> [PinThread] {
        try (app.map { [$0] } ?? apps()).flatMap { app in
            try folders(in: appURL(app)).flatMap { try threads(app: app, screen: $0) }
        }
    }

    // MARK: Changing

    /// Adds a picture as the next version of a screen, making the app and the screen if they are new.
    @discardableResult
    public func addVersion(app: String, name: String, picture: URL, kind: Kind? = nil, note: String? = nil, source: String? = nil, page: String? = nil) throws -> (Screen, Version) {
        let appID = app
        guard !appID.isEmpty, !appID.contains("/"), !appID.hasPrefix(".") else { throw PinError.invalid("Bad app name: \(app)") }
        let id = Self.slug(name)
        guard !id.isEmpty else { throw PinError.invalid("Bad screen name: \(name)") }
        guard Self.pictureSize(picture) != nil else { throw PinError.invalid("Not a picture: \(picture.path)") }
        let existing = try? screen(app: appID, id: id)
        if let existing, let kind, existing.kind != kind {
            throw PinError.invalid("\(name) is already a \(existing.kind.rawValue) screen")
        }
        var current = existing ?? Screen(
            id: id, name: name, kind: kind ?? .iphone,
            order: ((try? screens(app: appID))?.map(\.order).max() ?? -1) + 1,
            page: page, source: source, versions: [])
        if let source { current.source = source }
        if let page { current.page = page }
        let folder = screenURL(appID, id)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("threads"), withIntermediateDirectories: true)
        let n = (current.versions.last?.n ?? 0) + 1
        let ext = picture.pathExtension.isEmpty ? "png" : picture.pathExtension.lowercased()
        let file = "v\(n).\(ext)"
        let target = folder.appendingPathComponent(file)
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: picture, to: target)
        let version = Version(n: n, file: file, created: Date(), note: note)
        current.versions.append(version)
        try write(current, to: folder.appendingPathComponent("screen.json"))
        return (current, version)
    }

    @discardableResult
    public func addThread(app: String, screen: String, version: Int, x: Double, y: Double, text: String, author: String) throws -> PinThread {
        let found = try self.screen(app: app, id: screen)
        guard found.versions.contains(where: { $0.n == version }) else { throw PinError.notFound("version \(version) of \(screen)") }
        guard (0...1).contains(x), (0...1).contains(y) else { throw PinError.invalid("A pin must be on the picture") }
        let clean = try Self.clean(text)
        let now = Date()
        let thread = PinThread(id: Self.newID(), app: app, screen: screen, version: version, x: x, y: y, resolved: false, created: now,
                               messages: [Message(id: Self.newID(), author: author, text: clean, at: now)])
        try save(thread)
        return thread
    }

    /// A comment on the whole file, on no board.
    @discardableResult
    public func addGeneralThread(app: String, text: String, author: String) throws -> PinThread {
        guard apps().contains(app) else { throw PinError.notFound(app) }
        try FileManager.default.createDirectory(at: screenURL(app, Self.general).appendingPathComponent("threads"), withIntermediateDirectories: true)
        let clean = try Self.clean(text)
        let now = Date()
        let thread = PinThread(id: Self.newID(), app: app, screen: Self.general, version: 0, x: 0, y: 0, resolved: false, created: now,
                               messages: [Message(id: Self.newID(), author: author, text: clean, at: now)])
        try save(thread)
        return thread
    }

    @discardableResult
    public func reply(thread id: String, text: String, author: String) throws -> PinThread {
        var found = try thread(id: id)
        found.messages.append(Message(id: Self.newID(), author: author, text: try Self.clean(text), at: Date()))
        try save(found)
        return found
    }

    @discardableResult
    public func setResolved(thread id: String, _ resolved: Bool) throws -> PinThread {
        var found = try thread(id: id)
        found.resolved = resolved
        try save(found)
        return found
    }

    public func delete(thread id: String) throws {
        let found = try thread(id: id)
        try FileManager.default.removeItem(at: threadURL(found))
    }

    // MARK: Flows

    private func flowsURL(_ app: String) -> URL { appURL(app).appendingPathComponent("flows.json") }

    public func flows(app: String) throws -> [FlowEdge] {
        let url = flowsURL(app)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try Self.decoder.decode([FlowEdge].self, from: Data(contentsOf: url))
    }

    public func addFlow(app: String, from: String, to: String, label: String? = nil) throws {
        let start = try screen(app: app, id: from), end = try screen(app: app, id: to)
        guard start.id != end.id else { throw PinError.invalid("A flow step goes to another board") }
        var list = try flows(app: app).filter { !($0.from == from && $0.to == to) }
        list.append(FlowEdge(from: from, to: to, label: label))
        try write(list, to: flowsURL(app))
    }

    public func removeFlow(app: String, from: String, to: String) throws {
        try write(try flows(app: app).filter { !($0.from == from && $0.to == to) }, to: flowsURL(app))
    }

    // MARK: Live boards

    public func live(app: String) -> LiveConfig? {
        let url = appURL(app).appendingPathComponent("live.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(LiveConfig.self, from: data)
    }

    // MARK: Run panel

    /// The folder whose app or website the Run panel starts for this file: `run.json` beside its screens, `{ "folder": "/path" }`.
    public func runFolder(app: String) -> String? {
        let url = appURL(app).appendingPathComponent("run.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (json["folder"] as? String).map { ($0 as NSString).expandingTildeInPath }
    }

    public func setRunFolder(app: String, folder: String?) throws {
        let url = appURL(app).appendingPathComponent("run.json")
        guard let folder else { try? FileManager.default.removeItem(at: url); return }
        let data = try JSONSerialization.data(withJSONObject: ["folder": folder], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    // MARK: Where boards sit

    private func positionsURL(_ app: String) -> URL { appURL(app).appendingPathComponent("positions.json") }

    /// Boards he dragged somewhere, by screen id, as [x, y] in canvas units.
    public func positions(app: String) throws -> [String: [Double]] {
        let url = positionsURL(app)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try Self.decoder.decode([String: [Double]].self, from: Data(contentsOf: url))
    }

    public func setPosition(app: String, screen id: String, x: Double, y: Double) throws {
        _ = try screen(app: app, id: id)
        var all = try positions(app: app)
        all[id] = [x, y]
        try write(all, to: positionsURL(app))
    }

    // MARK: Helpers

    public static func pictureSize(_ url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = info[kCGImagePropertyPixelWidth] as? Double,
              let height = info[kCGImagePropertyPixelHeight] as? Double, width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
    }

    private func appURL(_ app: String) -> URL { home.appendingPathComponent(app) }
    private func screenURL(_ app: String, _ id: String) -> URL { appURL(app).appendingPathComponent(id) }
    private func threadURL(_ t: PinThread) -> URL {
        screenURL(t.app, t.screen).appendingPathComponent("threads/\(t.id).json")
    }
    private func save(_ thread: PinThread) throws { try write(thread, to: threadURL(thread)) }

    private func folders(in url: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return names.filter { name in
            var isFolder: ObjCBool = false
            return !name.hasPrefix(".") && FileManager.default.fileExists(atPath: url.appendingPathComponent(name).path, isDirectory: &isFolder) && isFolder.boolValue
        }
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(value).write(to: url, options: .atomic)
    }

    private static func clean(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PinError.invalid("A comment needs text") }
        return trimmed
    }

    private static func newID() -> String {
        let letters = Array("abcdefghjkmnpqrstuvwxyz23456789")
        return String((0..<8).compactMap { _ in letters.randomElement() })
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// How much one scroll event zooms. Multiplying by an exponent can never go negative, in and out mirror each other, and
/// a fast flick of a wheel is capped, so no single event jumps.
public enum ZoomStep {
    public static func factor(delta: Double, precise: Bool) -> Double {
        precise ? exp(max(min(delta, 40), -40) * 0.006) : exp(max(min(delta, 6), -6) * 0.05)
    }
}
