import Foundation

// In place of wink2's API struct: same name, same calls, no network in it at all. There is no address, no token and no
// URLSession in this library, so a board cannot reach Wink's engine or anything else. Everything is answered from Fixtures.

struct API: Sendable {
    static let shared = API()
    static let device = "Mac"
    /// Only ever shown as words in Settings.
    let base = URL(fileURLWithPath: "/stand-in-engine")

    func call<T: Decodable>(_ path: String, method: String = "GET", json: (any Encodable)? = nil, raw: Data? = nil, timeout: Double = 30) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await FakeEngine.answer(path, method: method, json: json))
    }

    func bytes(_ path: String, timeout: Double = 30) async throws -> Data { try FakeEngine.bytes(path) }

    func send(_ method: String, _ path: String, json: (any Encodable)? = nil) async throws {}
}

enum FakeEngine {
    private static func encoded(_ value: some Encodable) throws -> Data { try JSONEncoder().encode(value) }

    static func answer(_ full: String, method: String, json: (any Encodable)?) async throws -> Data {
        let parts = full.split(separator: "?", maxSplits: 1).map(String.init)
        let path = parts[0], query = parts.count > 1 ? parts[1] : ""
        if path.hasPrefix("/chats/"), method == "GET" {
            // The engine holds this question until the chat changes. A made-up chat never does.
            if query.contains("v=") { while true { try await Task.sleep(for: .seconds(3600)) } }
            let id = String(path.dropFirst("/chats/".count))
            guard let detail = Fixtures.details[id] else { throw APIError(message: "No such chat.", status: 404) }
            return try encoded(detail)
        }
        if method != "GET", path != "/info" { return Data(#"{"ok":true}"#.utf8) }
        switch path {
        case "/harnesses": return try encoded(Fixtures.harnesses)
        case "/status": return try encoded(Fixtures.status)
        case "/shared": return try encoded(Fixtures.shared)
        case "/tasks": return try encoded(Fixtures.todos)
        case "/jobs": return try encoded(Fixtures.jobs)
        case "/agents": return try encoded(Fixtures.agents)
        case "/usage": return try encoded(Fixtures.limits)
        case "/updates": return try encoded(Fixtures.versions)
        case "/connections": return try encoded(Fixtures.connections)
        case "/search": return try encoded(Fixtures.hits)
        case "/info":
            guard let json else { throw APIError(message: "Nothing asked.") }
            let asked = try JSONDecoder().decode(OutputQuestion.self, from: try JSONEncoder().encode(json))
            return try encoded(asked.paths.map(Fixtures.info))
        default: throw APIError(message: "Not in the made-up engine.", status: 404)
        }
    }

    static func bytes(_ full: String) throws -> Data {
        let parts = full.split(separator: "?", maxSplits: 1).map(String.init)
        let query = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : ""
        let path = query.replacingOccurrences(of: "path=", with: "").components(separatedBy: "&")[0]
        let ending = (path as NSString).pathExtension.lowercased()
        switch parts[0] {
        case "/thumb":
            let media = ["mov", "mp4", "png", "jpg"].contains(ending)
            return try Data(contentsOf: Fixtures.folder.appendingPathComponent(media ? "still.jpg" : "doc.png"))
        case "/media":
            guard ["mov", "mp4", "m4v"].contains(ending) else { throw APIError(message: "Not a video.") }
            let length = path.contains("Teaser") ? 45.0 : 138.0
            return try encoded(MediaAnswer(length: length, siblings: [path], path: path))
        case "/notes":
            let two = BoardEnv.current["BOARD_NOTES"] == "2"
            return try encoded(Fixtures.notes.filter { !two || $0.time != 42 })
        default: throw APIError(message: "Not in the made-up engine.", status: 404)
        }
    }

    private struct MediaAnswer: Encodable { let length: Double; let siblings: [String]; let path: String }
}
