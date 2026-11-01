import Foundation
import PinCore

// The agents' side of Pin. Everything goes through the same files as the app, so the app shows it within two seconds.
let usage = """
pin apps
pin screens APP
pin comments [APP [SCREEN]] [--all] [--json]     open comments, with where they sit and the picture's path
pin add APP SCREEN PICTURE [--kind iphone|mac|web] [--page NAME] [--note TEXT] [--source PATH]     next version of a screen
pin flow APP FROM TO [--label TEXT]     an arrow between two boards
pin unflow APP FROM TO
pin flows APP
pin reply ID TEXT [--as NAME]
pin resolve ID
pin reopen ID
pin comment APP SCREEN X Y TEXT [--version N] [--as NAME]     X and Y from 0 to 1
pin capture web APP SCREEN URL [--size 1440x900] [--note TEXT]
pin capture sim APP SCREEN --bundle ID [--arg A]... [--wait SECONDS] [--note TEXT] [--source PATH]
"""

var args = Array(CommandLine.arguments.dropFirst())
var pageOption: String?
func option(_ flag: String) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    let value = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return value
}
func options(_ flag: String) -> [String] {
    var out: [String] = []
    while let value = option(flag) { out.append(value) }
    return out
}
func flag(_ name: String) -> Bool {
    guard let i = args.firstIndex(of: name) else { return false }
    args.remove(at: i)
    return true
}
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
func need(_ count: Int) { if args.count < count { fail(usage) } }

@discardableResult
func run(_ tool: String, _ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let text = String(decoding: data, as: UTF8.self)
    guard process.terminationStatus == 0 else { throw PinError.invalid("\(tool) failed: \(text)") }
    return text
}

/// A screen comes back as its version; both capture routes and `add` end here.
func addVersion(_ store: Store, _ app: String, _ name: String, _ file: URL, kind: Kind?, note: String?, source: String?) throws {
    let (screen, version) = try store.addVersion(app: app, name: name, picture: file, kind: kind, note: note, source: source, page: pageOption)
    print("\(app)/\(screen.id) v\(version.n)")
}

func temporaryPicture() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("pin-\(UUID().uuidString).png")
}

func captureWeb(_ store: Store) throws {
    let size = option("--size") ?? "1440x900"
    let note = option("--note")
    need(3)
    let parts = size.split(separator: "x")
    guard parts.count == 2, Int(parts[0]) != nil, Int(parts[1]) != nil else { fail("Size looks like 1440x900") }
    let out = temporaryPicture()
    defer { try? FileManager.default.removeItem(at: out) }
    let profile = FileManager.default.temporaryDirectory.appendingPathComponent("pin-chrome-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: profile) }
    try run("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", [
        "--headless=new", "--user-data-dir=\(profile.path)", "--hide-scrollbars", "--force-device-scale-factor=2",
        "--virtual-time-budget=4000", "--window-size=\(parts[0]),\(parts[1])", "--screenshot=\(out.path)", args[2],
    ])
    try addVersion(store, args[0], args[1], out, kind: .web, note: note, source: args[2])
}

func captureSim(_ store: Store) throws {
    guard let bundle = option("--bundle") else { fail(usage) }
    let launch = options("--arg")
    let wait = Double(option("--wait") ?? "") ?? 4
    let note = option("--note")
    let source = option("--source")
    need(2)
    let simctl = "/usr/bin/xcrun"
    _ = try? run(simctl, ["simctl", "terminate", "booted", bundle])
    try run(simctl, ["simctl", "launch", "booted", bundle] + launch)
    Thread.sleep(forTimeInterval: wait)
    let out = temporaryPicture()
    defer { try? FileManager.default.removeItem(at: out) }
    try run(simctl, ["simctl", "io", "booted", "screenshot", out.path])
    try addVersion(store, args[0], args[1], out, kind: .iphone, note: note, source: source)
}

pageOption = option("--page")
let store = Store()
guard !args.isEmpty else { fail(usage) }
let command = args.removeFirst()
do {
    switch command {
    case "apps":
        store.apps().forEach { print($0) }
    case "screens":
        need(1)
        for s in try store.screens(app: args[0]) {
            let open = try store.threads(app: args[0], screen: s.id).filter { !$0.resolved }.count
            print("\(s.id)\t\(s.name)\t\(s.kind.rawValue)\tv\(s.latest?.n ?? 0)\t\(open) open\t\(s.source ?? "")")
        }
    case "comments":
        let all = flag("--all")
        let json = flag("--json")
        var list = try store.allThreads(app: args.first)
        if args.count > 1 { list = list.filter { $0.screen == args[1] } }
        if !all { list = list.filter { !$0.resolved } }
        list.sort { ($0.app, $0.screen, $0.version, $0.created) < ($1.app, $1.screen, $1.version, $1.created) }
        if json {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(list), as: UTF8.self))
        } else {
            for t in list {
                let screen = try store.screen(app: t.app, id: t.screen)
                let picture = screen.versions.first { $0.n == t.version }.map { store.picture(app: t.app, screen: t.screen, version: $0).path } ?? ""
                print("\(t.id)  \(t.app)/\(t.screen) v\(t.version)\(t.version == screen.latest?.n ? "" : " (older version)")\(t.resolved ? " (done)" : "")  at \(Int(t.x * 100))% across, \(Int(t.y * 100))% down")
                if let source = screen.source { print("  code: \(source)") }
                print("  picture: \(picture)")
                for m in t.messages { print("  \(m.author): \(m.text)") }
            }
        }
    case "add":
        let kind = option("--kind")
        let note = option("--note")
        let source = option("--source")
        need(3)
        if let kind, Kind(rawValue: kind) == nil { fail("Kind is iphone, mac or web") }
        try addVersion(store, args[0], args[1], URL(fileURLWithPath: args[2]), kind: kind.flatMap(Kind.init(rawValue:)), note: note, source: source)
    case "flow":
        let label = option("--label")
        need(3)
        try store.addFlow(app: args[0], from: Store.slug(args[1]), to: Store.slug(args[2]), label: label)
    case "unflow":
        need(3)
        try store.removeFlow(app: args[0], from: Store.slug(args[1]), to: Store.slug(args[2]))
    case "flows":
        need(1)
        for f in try store.flows(app: args[0]) { print("\(f.from) -> \(f.to)\(f.label.map { "  \($0)" } ?? "")") }
    case "reply":
        let author = option("--as") ?? "Claude"
        need(2)
        try store.reply(thread: args[0], text: args[1], author: author)
    case "resolve":
        need(1)
        try store.setResolved(thread: args[0], true)
    case "reopen":
        need(1)
        try store.setResolved(thread: args[0], false)
    case "comment":
        let author = option("--as") ?? "Claude"
        let chosen = option("--version").flatMap(Int.init)
        need(5)
        guard let x = Double(args[2]), let y = Double(args[3]) else { fail("X and Y are numbers from 0 to 1") }
        let screen = Store.slug(args[1])
        guard let version = try chosen ?? store.screen(app: args[0], id: screen).latest?.n else { fail("That screen has no version") }
        print(try store.addThread(app: args[0], screen: screen, version: version, x: x, y: y, text: args[4], author: author).id)
    case "capture":
        need(1)
        let route = args.removeFirst()
        switch route {
        case "web": try captureWeb(store)
        case "sim": try captureSim(store)
        default: fail(usage)
        }
    default:
        fail(usage)
    }
} catch {
    fail(error.localizedDescription)
}
