import AppKit
import IOSurface
import SwiftUI
import XPC

// Moved from Wink to Pin on 3 Nov 2026 (Damian: "i wanna have everything inside of pin that is about design so that also includes the app
// preview ... and the website"). Pin's Run panel shows it beside the canvas. Below, the words of the Wink original.
// An app running beside the chat, the way the Claude app has it (Damian, 2 Nov 2026: "you can even click through the simulation ... i want the same thing
// inside of wink"; boards "New · Mac · Preview…", his yes the same day). Mac only: an iPhone cannot run a simulator. The chat's bar has a Preview chip
// when the chat works on an Xcode project. The pane stands where a file's side pane stands: Wink builds the app, starts it on its own simulator "Wink
// Preview", and shows that simulator's live screen. Pressing is a finger on the glass: it goes down, follows the pointer and lifts as he does (SimLink).
// Closing the pane shuts the simulator down: left booted it takes memory, and it once took the iPhone install.

/// An Xcode project with an iPhone app: what the Run panel builds and starts.
struct PreviewProject: Hashable, Sendable {
    let root: String
    /// The .xcodeproj, or nil when only a project.yml is there yet.
    let project: String?
    let generated: Bool

    /// The iPhone project in this folder, if it has one.
    static func at(_ folder: String) -> PreviewProject? {
        let files = FileManager.default
        var isFolder: ObjCBool = false
        guard files.fileExists(atPath: folder, isDirectory: &isFolder), isFolder.boolValue,
              let names = try? files.contentsOfDirectory(atPath: folder) else { return nil }
        let project = names.first { $0.hasSuffix(".xcodeproj") }.map { folder + "/" + $0 }
        let spec = folder + "/project.yml"
        if names.contains("project.yml"), let text = try? String(contentsOfFile: spec, encoding: .utf8),
           text.contains("platform: iOS") {
            return PreviewProject(root: folder, project: project, generated: true)
        }
        if let project, let text = try? String(contentsOfFile: project + "/project.pbxproj", encoding: .utf8),
           text.contains("com.apple.product-type.application"), text.contains("iphoneos") {
            return PreviewProject(root: folder, project: project, generated: false)
        }
        return nil
    }
}

/// One iPhone app in a project.
struct PreviewApp: Hashable, Sendable {
    let scheme: String
    let name: String
    let bundle: String
    /// The built app, where this build puts it.
    let built: String
}

/// Runs the Mac's own tools. They read and write a lot, so the output is read while they run.
private enum SimTool {
    static let xcrun = "/usr/bin/xcrun"
    static let xcodebuild = "/usr/bin/xcodebuild"
    static let xcodegen = "/opt/homebrew/bin/xcodegen"
    static let xcodeSelect = "/usr/bin/xcode-select"

    /// A running tool, so Run again and Close can stop it.
    final class Running: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        func set(_ value: Process) { lock.withLock { process = value } }
        func clear(_ value: Process) { lock.withLock { if process === value { process = nil } } }
        func stop() { lock.withLock { if process?.isRunning == true { process?.terminate() } } }
    }

    static func run(_ tool: String, _ arguments: [String], in folder: String? = nil, log: URL? = nil, running: Running? = nil) async -> (code: Int32, out: String) {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            if let folder { process.currentDirectoryURL = URL(fileURLWithPath: folder) }
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
            process.environment = environment
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = log == nil ? FileHandle.nullDevice : pipe
            do { try process.run() } catch { return (-1, error.localizedDescription) }
            running?.set(process)
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            running?.clear(process)
            if let log { try? data.write(to: log) }
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }.value
    }
}

/// A direct line to a booted simulator: its live screen and a finger on its glass. A first version started a tool for every touch and read screenshots
/// (Damian, 2 Nov: "it runs like shit"): 7 pictures a second and half a second per tap. This is what Xcode's own Simulator does, 60 pictures a second at
/// full sharpness and touches as they happen. Apple's frameworks for it are private, so they are looked up by name; how to talk to them is from Meta's idb
/// (github.com/facebook/idb, MIT), FBSimulatorControl/HID and Framebuffer. A new Xcode can change them: then the pane says so instead of showing a phone.
final class SimLink: @unchecked Sendable {
    private let device: AnyObject
    private var touch: xpc_connection_t?
    private var screen: AnyObject?
    private let token = NSUUID()
    private let queue = DispatchQueue(label: "wink.preview.screen", qos: .userInteractive)
    private let lock = NSLock()
    private var frameWaiting = false
    private static let digitizer = "com.apple.coredevice.feature.remote.hid.digitizer"

    private init(device: AnyObject) { self.device = device }

    /// The simulator as CoreSimulator knows it.
    static func open(udid: String, developer: String) -> SimLink? {
        guard dlopen("/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator", RTLD_NOW) != nil,
              let contexts: AnyObject = NSClassFromString("SimServiceContext") else { return nil }
        typealias Named = @convention(c) (AnyObject, Selector, NSString, UnsafeMutablePointer<NSError?>?) -> AnyObject?
        typealias Plain = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<NSError?>?) -> AnyObject?
        let shared = NSSelectorFromString("sharedServiceContextForDeveloperDir:error:")
        let defaultSet = NSSelectorFromString("defaultDeviceSetWithError:")
        guard contexts.responds(to: shared),
              let context = unsafeBitCast(contexts.method(for: shared), to: Named.self)(contexts, shared, developer as NSString, nil),
              context.responds(to: defaultSet),
              let set = unsafeBitCast(context.method(for: defaultSet), to: Plain.self)(context, defaultSet, nil),
              let all = set.perform(NSSelectorFromString("devices"))?.takeUnretainedValue() as? [AnyObject],
              let device = all.first(where: { ($0.perform(NSSelectorFromString("UDID"))?.takeUnretainedValue() as? NSUUID)?.uuidString == udid })
        else { return nil }
        return SimLink(device: device)
    }

    // MARK: The finger

    /// The simulator's touch service starts with its boot and can be a moment behind it: a send to one that is not up yet is lost without a word, so a
    /// question has to come back before it counts.
    func connectFinger() -> Bool {
        for attempt in 0..<8 {
            if attempt > 0 { Thread.sleep(forTimeInterval: 2) }
            guard let line = openLine() else { continue }
            let answered = DispatchSemaphore(value: 0)
            let question = xpc_dictionary_create(nil, nil, 0)
            xpc_dictionary_set_uint64(question, "usageCode", 0)
            xpc_dictionary_set_uint64(question, "state", 2)
            xpc_connection_send_message_with_reply(line, Self.message("IndigoKeyboardButtonEvent", barrier: true, payload: question), queue) { reply in
                if xpc_get_type(reply) == XPC_TYPE_DICTIONARY { answered.signal() }
            }
            if answered.wait(timeout: .now() + 4) == .success {
                lock.withLock { touch = line }
                return true
            }
            xpc_connection_cancel(line)
        }
        return false
    }

    private func openLine() -> xpc_connection_t? {
        typealias Lookup = @convention(c) (AnyObject, Selector, NSString, UnsafeMutablePointer<NSError?>?) -> mach_port_t
        typealias Endpoint = @convention(c) (mach_port_t, UInt64, UInt64) -> Unmanaged<AnyObject>?
        typealias FromEndpoint = @convention(c) (AnyObject) -> Unmanaged<AnyObject>?
        typealias SimToHost = @convention(c) (AnyObject) -> Void
        let lookup = NSSelectorFromString("lookup:error:")
        guard device.responds(to: lookup), let here = dlopen(nil, RTLD_NOW),
              let makeEndpoint = dlsym(here, "xpc_endpoint_create_mach_port_4sim"),
              let makeLine = dlsym(here, "xpc_connection_create_from_endpoint"),
              let simToHost = dlsym(here, "xpc_connection_enable_sim2host_4sim") else { return nil }
        let port = unsafeBitCast(device.method(for: lookup), to: Lookup.self)(device, lookup, Self.digitizer as NSString, nil)
        guard port != mach_port_t(MACH_PORT_NULL),
              let endpoint = unsafeBitCast(makeEndpoint, to: Endpoint.self)(port, 0, 0)?.takeRetainedValue(),
              let made = unsafeBitCast(makeLine, to: FromEndpoint.self)(endpoint)?.takeRetainedValue() else { return nil }
        let line = made as! xpc_connection_t
        unsafeBitCast(simToHost, to: SimToHost.self)(made)
        // Without a handler XPC refuses to start the line. It comes back by itself after a drop, at the next thing sent.
        xpc_connection_set_event_handler(line) { _ in }
        xpc_connection_resume(line)
        return line
    }

    private static func message(_ type: String, barrier: Bool = false, payload: xpc_object_t) -> xpc_object_t {
        let message = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_string(message, "messageType", type)
        xpc_dictionary_set_bool(message, "isBarrier", barrier)
        xpc_dictionary_set_string(message, "featureIdentifier", digitizer)
        xpc_dictionary_set_value(message, "payload", payload)
        return message
    }

    private func send(_ type: String, _ payload: xpc_object_t) {
        guard let line = lock.withLock({ touch }) else { return }
        xpc_connection_send_message(line, Self.message(type, payload: payload))
    }

    enum Phase: UInt64 { case down = 0, move = 1, up = 2 }
    enum Edge: UInt64 { case none = 0, top = 1, left = 2, bottom = 3, right = 4 }

    /// One finger, from the screen's top left, 0 to 1 across and down. The edge is how iOS knows the swipes from the rim: home, back, Notification Centre.
    func finger(_ phase: Phase, x: Double, y: Double, edge: Edge) {
        let point = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_double(point, "x", x)
        xpc_dictionary_set_double(point, "y", y)
        let payload = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_value(payload, "pointOne", point)
        xpc_dictionary_set_uint64(payload, "eventType", phase.rawValue)
        xpc_dictionary_set_uint64(payload, "edge", edge.rawValue)
        xpc_dictionary_set_uint64(payload, "target", 0)
        send("IndigoDigitizerEvent", payload)
    }

    /// A key by its USB code.
    func key(_ usage: UInt64, down: Bool) {
        let payload = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_uint64(payload, "usageCode", usage)
        xpc_dictionary_set_uint64(payload, "state", down ? 1 : 2)
        send("IndigoKeyboardButtonEvent", payload)
    }

    /// A button on the phone's body, by its place in the USB tables.
    func button(page: UInt64, usage: UInt64, down: Bool) {
        let payload = xpc_dictionary_create(nil, nil, 0)
        xpc_dictionary_set_uint64(payload, "usagePage", page)
        xpc_dictionary_set_uint64(payload, "usageCode", usage)
        xpc_dictionary_set_uint64(payload, "state", down ? 1 : 2)
        send("IndigoButtonEvent", payload)
    }

    /// The Home button: page 12, usage 64.
    func home() {
        button(page: 0x0C, usage: 0x40, down: true)
        button(page: 0x0C, usage: 0x40, down: false)
    }

    // MARK: The screen

    /// Calls `surface` with the screen's memory, and `frame` on the main thread whenever a new picture is in it. One call waits at most, so a slow
    /// moment on the Mac skips pictures instead of falling behind.
    func watchScreen(surface: @escaping @Sendable (IOSurface) -> Void, frame: @escaping @Sendable () -> Void) -> Bool {
        guard let io = device.perform(NSSelectorFromString("io"))?.takeUnretainedValue(),
              let ports = io.perform(NSSelectorFromString("ioPorts"))?.takeUnretainedValue() as? [AnyObject] else { return false }
        let read = NSSelectorFromString("framebufferSurface")
        var biggest: (screen: AnyObject, surface: IOSurface)?
        for port in ports {
            guard let screen = port.perform(NSSelectorFromString("descriptor"))?.takeUnretainedValue(), screen.responds(to: read),
                  let found = screen.perform(read)?.takeUnretainedValue() as? IOSurface else { continue }
            if found.width > biggest?.surface.width ?? 0 { biggest = (screen, found) }
        }
        let register = NSSelectorFromString("registerScreenCallbacksWithUUID:callbackQueue:frameCallback:surfacesChangedCallback:propertiesChangedCallback:")
        guard let biggest, biggest.screen.responds(to: register) else { return false }
        surface(biggest.surface)
        let tick: @convention(block) () -> Void = { [weak self] in
            guard let self, self.lock.withLock({ if self.frameWaiting { return false }; self.frameWaiting = true; return true }) else { return }
            DispatchQueue.main.async {
                self.lock.withLock { self.frameWaiting = false }
                frame()
            }
        }
        let changed: @convention(block) (AnyObject?, AnyObject?) -> Void = { new, _ in
            if let new = new as? IOSurface { surface(new) }
        }
        let properties: @convention(block) (AnyObject?) -> Void = { _ in }
        typealias Register = @convention(c) (AnyObject, Selector, NSUUID, DispatchQueue, AnyObject, AnyObject, AnyObject) -> Void
        unsafeBitCast(biggest.screen.method(for: register), to: Register.self)(biggest.screen, register, token, queue, tick as AnyObject, changed as AnyObject, properties as AnyObject)
        lock.withLock { screen = biggest.screen }
        return true
    }

    func close() {
        let (line, watched) = lock.withLock { (touch, screen) }
        if let line { xpc_connection_cancel(line) }
        let unregister = NSSelectorFromString("unregisterScreenCallbacksWithUUID:")
        if let watched, watched.responds(to: unregister) { _ = watched.perform(unregister, with: token) }
        lock.withLock { touch = nil; screen = nil }
    }
}

/// The app running beside the chat: from Preview to Close.
@MainActor @Observable final class SimPreview {
    enum State: Equatable { case starting, building, running, failed(String) }
    let project: PreviewProject
    private(set) var state = State.starting
    private(set) var apps: [PreviewApp] = []
    private(set) var current: PreviewApp?
    private(set) var device = "iPhone 18 Pro"
    /// Apple's own body for that phone.
    private(set) var chrome = PreviewChrome.standard
    /// The screen's shape, from its pixels.
    private(set) var size = CGSize(width: 402, height: 874)

    @ObservationIgnored private var udid: String?
    @ObservationIgnored private var booted = false
    @ObservationIgnored private var started = false
    @ObservationIgnored private var run: Task<Void, Never>?
    @ObservationIgnored private let build = SimTool.Running()
    @ObservationIgnored private var link: SimLink?
    @ObservationIgnored private var closed = false
    @ObservationIgnored private var quitting: NSObjectProtocol?
    @ObservationIgnored fileprivate var surface: IOSurface?
    @ObservationIgnored fileprivate weak var screen: PreviewScreenView?
    /// The apps of a project do not change often: looking takes seconds, so once per launch.
    private static var known: [PreviewProject: [PreviewApp]] = [:]

    init(project: PreviewProject) {
        self.project = project
        quitting = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    /// The name on the app's icon, once it is built.
    private var iconName: String?
    var name: String { iconName ?? current?.name ?? (project.root as NSString).lastPathComponent }
    private var scratch: URL {
        let key = project.root.replacingOccurrences(of: "/", with: "_")
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Pin/Run/\(key)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    private var remembered: String { "preview.app." + project.root }

    func startOnce() {
        guard !started else { return }
        started = true
        runAgain()
    }

    /// Build what is there now and start it.
    func runAgain() {
        run?.cancel()
        build.stop()
        run = Task { await self.go() }
    }

    func pick(_ app: PreviewApp) {
        current = app
        iconName = nil
        UserDefaults.standard.set(app.scheme, forKey: remembered)
        runAgain()
    }

    private func go() async {
        if !booted { state = .starting }
        guard await bootOnce(), await connect() else { return }
        state = .building
        let scratch = self.scratch
        if project.generated {
            _ = await SimTool.run(SimTool.xcodegen, ["generate", "--quiet"], in: project.root, running: build)
        }
        guard !Task.isCancelled else { return }
        if apps.isEmpty { apps = await findApps(scratch) }
        guard !Task.isCancelled else { return }
        if current == nil {
            let wanted = UserDefaults.standard.string(forKey: remembered)
            current = apps.first { $0.scheme == wanted } ?? apps.first
        }
        guard let app = current, let project = projectFile, let udid else {
            state = .failed("No iPhone app in this project")
            return
        }
        let log = scratch.appendingPathComponent("build.log")
        let built = await SimTool.run(SimTool.xcodebuild, ["-project", project, "-scheme", app.scheme, "-configuration", "Debug", "-destination", "id=\(udid)", "-derivedDataPath", scratch.appendingPathComponent("Build").path, "build"], in: self.project.root, log: log, running: build)
        guard !Task.isCancelled else { return }
        guard built.code == 0 else {
            state = .failed(Self.firstError(built.out))
            return
        }
        await keepOnly(app.bundle, on: udid)
        guard !Task.isCancelled else { return }
        let plist = NSDictionary(contentsOfFile: app.built + "/Info.plist")
        iconName = (plist?["CFBundleDisplayName"] ?? plist?["CFBundleName"]) as? String
        let installed = await SimTool.run(SimTool.xcrun, ["simctl", "install", udid, app.built], log: scratch.appendingPathComponent("install.log"))
        guard !Task.isCancelled else { return }
        guard installed.code == 0 else {
            state = .failed(Self.firstLine(installed.out))
            return
        }
        let launched = await SimTool.run(SimTool.xcrun, ["simctl", "launch", "--terminate-running-process", udid, app.bundle], log: scratch.appendingPathComponent("launch.log"))
        guard !Task.isCancelled else { return }
        state = launched.code == 0 ? .running : .failed(Self.firstLine(launched.out))
    }

    /// The phone holds the app of this chat and nothing else (Damian, 2 Nov: "there is even nod on it which i deleted long time ago"): whatever an earlier
    /// preview left on it is taken off.
    private func keepOnly(_ bundle: String, on udid: String) async {
        let listed = await SimTool.run(SimTool.xcrun, ["simctl", "listapps", udid])
        guard let apps = (try? PropertyListSerialization.propertyList(from: Data(listed.out.utf8), format: nil)) as? [String: [String: Any]] else { return }
        for (id, app) in apps where app["ApplicationType"] as? String == "User" && id != bundle {
            _ = await SimTool.run(SimTool.xcrun, ["simctl", "uninstall", udid, id])
        }
    }

    private var projectFile: String? { project.project ?? (try? FileManager.default.contentsOfDirectory(atPath: project.root))?.first { $0.hasSuffix(".xcodeproj") }.map { project.root + "/" + $0 } }

    private static func firstLine(_ text: String) -> String {
        text.split(separator: "\n").first.map { String($0.prefix(240)) } ?? "It did not start"
    }

    /// The first thing the build complains about, without the long path in front.
    private static func firstError(_ log: String) -> String {
        for line in log.split(separator: "\n") where line.contains(" error: ") || line.hasPrefix("error: ") {
            let words = line.components(separatedBy: "error: ").last ?? String(line)
            let file = line.components(separatedBy: ":").first.map { ($0 as NSString).lastPathComponent }
            return String(((file.map { $0.hasSuffix(".swift") ? $0 + ": " : "" } ?? "") + words).prefix(240))
        }
        return "The build failed"
    }

    /// The newest iOS on this Mac and the newest Pro iPhone it runs (Damian, 2 Nov: "this simulation is super old", it stood on iOS 26.5 with iOS 27 out).
    private func newest() async -> (runtime: String, type: String, name: String)? {
        let listed = await SimTool.run(SimTool.xcrun, ["simctl", "list", "runtimes", "-j"])
        struct List: Decodable {
            struct Runtime: Decodable {
                struct Kind: Decodable { let name: String; let identifier: String }
                let identifier: String
                let version: String
                let platform: String?
                let isAvailable: Bool?
                let supportedDeviceTypes: [Kind]?
            }
            let runtimes: [Runtime]
        }
        let runtimes = (try? JSONDecoder().decode(List.self, from: Data(listed.out.utf8)))?.runtimes ?? []
        func number(_ name: String) -> Int? {
            let words = name.split(separator: " ")
            return words.count == 3 && words[2] == "Pro" ? Int(words[1]) : nil
        }
        // Newest first. A system can run one special phone only (iOS 27.1 runs nothing but the foldable iPhone Duo), so the newest that runs a normal Pro counts.
        let usable = runtimes.filter { $0.platform == "iOS" && $0.isAvailable == true }
            .sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
        for runtime in usable {
            let phones = (runtime.supportedDeviceTypes ?? []).filter { number($0.name) != nil }
            if let phone = phones.max(by: { number($0.name) ?? 0 < number($1.name) ?? 0 }) {
                return (runtime.identifier, phone.identifier, phone.name)
            }
        }
        return nil
    }

    /// The simulator "Pin Preview": its own, so nothing he or another chat runs is in the way. On the newest iOS and iPhone: when Xcode brings newer ones it
    /// is made again, and what was on it goes with it. It only ever holds apps Wink built for it.
    private func bootOnce() async -> Bool {
        if booted { return true }
        guard let wanted = await newest() else {
            state = .failed("No iOS simulator is installed")
            return false
        }
        device = wanted.name
        chrome = PreviewChrome.load(device: wanted.name)
        let listed = await SimTool.run(SimTool.xcrun, ["simctl", "list", "devices", "-j"])
        struct List: Decodable {
            struct Device: Decodable { let name: String; let udid: String; let deviceTypeIdentifier: String? }
            let devices: [String: [Device]]
        }
        let all = (try? JSONDecoder().decode(List.self, from: Data(listed.out.utf8)))?.devices ?? [:]
        var id: String?
        for (runtime, devices) in all {
            for found in devices where found.name == "Pin Preview" {
                if runtime == wanted.runtime, found.deviceTypeIdentifier == wanted.type, id == nil {
                    id = found.udid
                } else {
                    _ = await SimTool.run(SimTool.xcrun, ["simctl", "shutdown", found.udid])
                    _ = await SimTool.run(SimTool.xcrun, ["simctl", "delete", found.udid])
                }
            }
        }
        if id == nil {
            let made = await SimTool.run(SimTool.xcrun, ["simctl", "create", "Pin Preview", wanted.type, wanted.runtime])
            let line = made.out.trimmingCharacters(in: .whitespacesAndNewlines)
            if made.code == 0, !line.isEmpty { id = line }
        }
        guard let id else {
            state = .failed("Could not make a simulator")
            return false
        }
        udid = id
        // It may still be shutting down from the last Close.
        var up = false
        for _ in 0..<40 where !up && !Task.isCancelled {
            up = await SimTool.run(SimTool.xcrun, ["simctl", "bootstatus", id, "-b"]).code == 0
            if !up { try? await Task.sleep(for: .milliseconds(500)) }
        }
        guard !Task.isCancelled else { return false }
        guard up else {
            state = .failed("The simulator did not start")
            return false
        }
        booted = true
        return true
    }

    /// The iPhone apps among the project's schemes.
    private func findApps(_ scratch: URL) async -> [PreviewApp] {
        if let known = Self.known[project] { return known }
        guard let file = projectFile else { return [] }
        let listed = await SimTool.run(SimTool.xcodebuild, ["-list", "-json", "-project", file], running: build)
        struct List: Decodable { struct Project: Decodable { let schemes: [String]?; let targets: [String]? }; let project: Project }
        guard let found = (try? JSONDecoder().decode(List.self, from: Data(listed.out.utf8)))?.project else { return [] }
        let schemes = found.schemes ?? []
        let targets = Set(found.targets ?? [])
        let worth = schemes.filter(targets.contains)
        let derived = scratch.appendingPathComponent("Build").path
        let apps = await withTaskGroup(of: PreviewApp?.self) { group in
            for scheme in worth.isEmpty ? schemes : worth {
                group.addTask { await Self.app(scheme, file: file, derived: derived) }
            }
            var all: [PreviewApp] = []
            for await app in group { if let app { all.append(app) } }
            return all.sorted { $0.name < $1.name }
        }
        Self.known[project] = apps
        return apps
    }

    private nonisolated static func app(_ scheme: String, file: String, derived: String) async -> PreviewApp? {
        let out = await SimTool.run(SimTool.xcodebuild, ["-showBuildSettings", "-json", "-project", file, "-scheme", scheme, "-configuration", "Debug", "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", derived])
        struct Entry: Decodable { let buildSettings: [String: String] }
        guard let start = out.out.firstIndex(of: "["),
              let entries = try? JSONDecoder().decode([Entry].self, from: Data(out.out[start...].utf8)) else { return nil }
        for settings in entries.map(\.buildSettings) {
            guard settings["PRODUCT_TYPE"] == "com.apple.product-type.application",
                  settings["SUPPORTED_PLATFORMS"]?.contains("iphonesimulator") == true,
                  let bundle = settings["PRODUCT_BUNDLE_IDENTIFIER"], let wrapper = settings["WRAPPER_NAME"], let folder = settings["TARGET_BUILD_DIR"] else { continue }
            let shown = settings["INFOPLIST_KEY_CFBundleDisplayName"].flatMap { $0.isEmpty ? nil : $0 } ?? settings["PRODUCT_NAME"] ?? scheme
            return PreviewApp(scheme: scheme, name: shown, bundle: bundle, built: folder + "/" + wrapper)
        }
        return nil
    }

    /// The live screen and the finger, once per boot.
    private func connect() async -> Bool {
        if link != nil { return true }
        guard let udid else { return false }
        let developer = await SimTool.run(SimTool.xcodeSelect, ["-p"]).out.trimmingCharacters(in: .whitespacesAndNewlines)
        let opened = await Task.detached { () -> SimLink? in
            guard let link = SimLink.open(udid: udid, developer: developer), link.connectFinger() else { return nil }
            return link
        }.value
        guard !Task.isCancelled, !closed else {
            opened?.close()
            return false
        }
        guard let opened, opened.watchScreen(surface: { [weak self] new in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.show(new) } }
        }, frame: { [weak self] in
            MainActor.assumeIsolated { self?.screen?.refresh() }
        }) else {
            opened?.close()
            state = .failed("This Xcode's simulator does not answer the way Wink expects")
            return false
        }
        link = opened
        return true
    }

    private func show(_ new: IOSurface) {
        surface = new
        if new.width > 0, new.height > 0 { size = CGSize(width: new.width, height: new.height) }
        screen?.show(new)
    }

    /// Stop everything: the build, the picture and the simulator.
    func close() {
        guard !closed else { return }
        closed = true
        run?.cancel()
        build.stop()
        link?.close()
        if let quitting { NotificationCenter.default.removeObserver(quitting) }
        if let udid {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: SimTool.xcrun)
            process.arguments = ["simctl", "shutdown", udid]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
    }

    // MARK: What he does on the screen

    func finger(_ phase: SimLink.Phase, x: Double, y: Double, edge: SimLink.Edge) { link?.finger(phase, x: x, y: y, edge: edge) }
    func key(_ usage: UInt64, down: Bool) { link?.key(usage, down: down) }
    func home() { link?.home() }
    func button(page: UInt64, usage: UInt64, down: Bool) { link?.button(page: page, usage: usage, down: down) }

    /// Text a key cannot give (a pasted line, an ä): through the phone's clipboard, then Command-V.
    func paste(_ words: String) {
        guard let udid else { return }
        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: SimTool.xcrun)
            process.arguments = ["simctl", "pbcopy", udid]
            let pipe = Pipe()
            process.standardInput = pipe
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return }
            pipe.fileHandleForWriting.write(Data(words.utf8))
            try? pipe.fileHandleForWriting.close()
            while process.isRunning { try? await Task.sleep(for: .milliseconds(20)) }
            key(227, down: true)
            key(25, down: true)
            key(25, down: false)
            key(227, down: false)
        }
    }
}

/// The simulator's screen: what it shows, and what he does on it.
final class PreviewScreenView: NSView {
    var model: SimPreview? {
        didSet {
            model?.screen = self
            if let surface = model?.surface { show(surface) }
        }
    }
    /// The edge the finger went down at, for the whole touch.
    private var edge = SimLink.Edge.none
    private var down = false
    /// Two fingers on the trackpad are one finger on the phone: where it is, between the first movement and the end.
    private var scrolling: CGPoint?
    private var scrollEnd: DispatchWorkItem?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contentsGravity = .resize
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.actions = ["contents": NSNull()]
    }
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func show(_ surface: IOSurface) {
        layer?.contents = surface
        refresh()
    }

    /// A still instead of the simulator, on a design board.
    func show(picture: NSImage) { layer?.contents = picture }

    /// The screen's own shape, corners and all: Apple's mask for this phone.
    private var shape: CALayer?
    func shape(_ mask: CGImage?, corners: CGFloat) {
        guard let mask else {
            layer?.mask = nil
            shape = nil
            layer?.cornerRadius = corners
            layer?.cornerCurve = .continuous
            layer?.masksToBounds = true
            return
        }
        let shape = self.shape ?? CALayer()
        shape.contents = mask
        shape.contentsGravity = .resize
        shape.actions = ["bounds": NSNull(), "position": NSNull(), "contents": NSNull()]
        shape.frame = bounds
        self.shape = shape
        layer?.masksToBounds = false
        layer?.cornerRadius = 0
        layer?.mask = shape
    }

    override func layout() {
        super.layout()
        shape?.frame = bounds
    }

    /// A touch counts while the app runs.
    var live = true

    /// The same memory holds a new picture.
    func refresh() {
        layer?.perform(NSSelectorFromString("setContentsChanged"))
    }

    /// A place in this view, from the screen's top left, 0 to 1.
    private func onPhone(_ event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        return CGPoint(x: min(1, max(0, point.x / bounds.width)), y: min(1, max(0, 1 - point.y / bounds.height)))
    }

    /// Going down this close to the rim is a swipe from the rim.
    private static func edge(at point: CGPoint) -> SimLink.Edge {
        if point.y > 0.975 { return .bottom }
        if point.y < 0.015 { return .top }
        if point.x < 0.03 { return .left }
        if point.x > 0.97 { return .right }
        return .none
    }

    override func mouseDown(with event: NSEvent) {
        guard live else { return }
        window?.makeFirstResponder(self)
        let point = onPhone(event)
        edge = Self.edge(at: point)
        down = true
        model?.finger(.down, x: point.x, y: point.y, edge: edge)
    }

    override func mouseDragged(with event: NSEvent) {
        guard down else { return }
        let point = onPhone(event)
        model?.finger(.move, x: point.x, y: point.y, edge: edge)
    }

    override func mouseUp(with event: NSEvent) {
        guard down else { return }
        down = false
        let point = onPhone(event)
        model?.finger(.up, x: point.x, y: point.y, edge: edge)
        edge = .none
    }

    /// The trackpad scrolls: a finger that moves with his, and lets go when he does, so the app's list runs on as it does on a phone. The Mac's own drift
    /// after he lets go is left out for that reason.
    override func scrollWheel(with event: NSEvent) {
        guard live, event.momentumPhase == [], bounds.height > 0 else { return }
        let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 12
        var at = scrolling ?? onPhone(event)
        if scrolling == nil { model?.finger(.down, x: at.x, y: at.y, edge: .none) }
        at.x += event.scrollingDeltaX * scale / bounds.width
        at.y += event.scrollingDeltaY * scale / bounds.height
        // A long scroll runs out of glass: lift and go down again in the middle.
        if at.y < 0.05 || at.y > 0.95 || at.x < 0.05 || at.x > 0.95 {
            let inside = CGPoint(x: min(0.95, max(0.05, at.x)), y: min(0.95, max(0.05, at.y)))
            model?.finger(.up, x: inside.x, y: inside.y, edge: .none)
            at = CGPoint(x: 0.5, y: 0.5)
            model?.finger(.down, x: at.x, y: at.y, edge: .none)
        } else {
            model?.finger(.move, x: at.x, y: at.y, edge: .none)
        }
        scrolling = at
        scrollEnd?.cancel()
        if event.phase == .ended || event.phase == .cancelled {
            endScroll()
        } else {
            let end = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.endScroll() }
            }
            scrollEnd = end
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: end)
        }
    }

    private func endScroll() {
        guard let at = scrolling else { return }
        scrolling = nil
        model?.finger(.up, x: at.x, y: at.y, edge: .none)
    }

    /// A Mac key as the same physical key on the phone, as Xcode's Simulator sends it: the phone takes the Mac's layout, so his Swiss keyboard's y stays a y
    /// and the ö stays where it is. The Mac's key numbers against the USB tables.
    private static let usages: [UInt16: UInt64] = [
        0: 4, 11: 5, 8: 6, 2: 7, 14: 8, 3: 9, 5: 10, 4: 11, 34: 12, 38: 13, 40: 14, 37: 15, 46: 16, 45: 17, 31: 18, 35: 19, 12: 20, 15: 21, 1: 22, 17: 23, 32: 24, 9: 25, 13: 26, 7: 27, 16: 28, 6: 29,
        18: 30, 19: 31, 20: 32, 21: 33, 23: 34, 22: 35, 26: 36, 28: 37, 25: 38, 29: 39,
        36: 40, 76: 40, 53: 41, 51: 42, 48: 43, 49: 44, 27: 45, 24: 46, 33: 47, 30: 48, 42: 49, 41: 51, 39: 52, 50: 53, 43: 54, 47: 55, 44: 56, 10: 100,
        117: 76, 124: 79, 123: 80, 125: 81, 126: 82
    ]

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) { return super.keyDown(with: event) }
        guard let usage = Self.usages[event.keyCode] else {
            if let words = event.characters, !words.isEmpty { model?.paste(words) }
            return
        }
        let held: [UInt64] = (event.modifierFlags.contains(.shift) ? [225] : []) + (event.modifierFlags.contains(.option) ? [226] : [])
        for modifier in held { model?.key(modifier, down: true) }
        model?.key(usage, down: true)
        model?.key(usage, down: false)
        for modifier in held { model?.key(modifier, down: false) }
    }

    @objc func paste(_ sender: Any?) {
        if let words = NSPasteboard.general.string(forType: .string) { model?.paste(words) }
    }
}

/// The body of a phone as Xcode's Simulator draws it: Apple's own artwork, which every Mac with Xcode has (Damian, 2 Nov: "this one looks so cheap", about a
/// black rectangle of mine). The picture of the frame in eight pieces that stretch to the phone's size, the side buttons that stand out from under it, the
/// mask with the screen's real corners. Without Xcode's files the phone is a plain black shape.
final class PreviewChrome {
    struct Button {
        let name: String
        let page: UInt64
        let usage: UInt64
        let up: NSImage
        let down: NSImage
        let left: Bool
        let y: CGFloat
    }
    /// The screen in points.
    var screen = CGSize(width: 402, height: 874)
    /// From the body's outer edge to the screen.
    var inset: CGFloat = 8
    var pieces: [String: NSImage] = [:]
    var buttons: [Button] = []
    var mask: CGImage?

    /// How far the buttons stand out, and the room kept for them beside the body.
    static let out: CGFloat = 3
    static let hovered: CGFloat = 6

    var body: CGSize { CGSize(width: screen.width + 2 * inset, height: screen.height + 2 * inset) }
    var whole: CGSize { CGSize(width: body.width + 2 * Self.hovered, height: body.height) }

    @MainActor static let standard = load(device: "iPhone 18 Pro")

    static func load(device: String) -> PreviewChrome {
        let chrome = PreviewChrome()
        let type = "/Library/Developer/CoreSimulator/Profiles/DeviceTypes/\(device).simdevicetype/Contents/Resources/"
        guard let profile = NSDictionary(contentsOfFile: type + "profile.plist") else { return chrome }
        if let width = profile["mainScreenWidth"] as? Double, let height = profile["mainScreenHeight"] as? Double, let scale = profile["mainScreenScale"] as? Double, scale > 0 {
            chrome.screen = CGSize(width: width / scale, height: height / scale)
        }
        if let name = profile["framebufferMask"] as? String, let image = NSImage(contentsOfFile: type + name + ".pdf") {
            var box = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            chrome.mask = image.cgImage(forProposedRect: &box, context: nil, hints: nil)
        }
        guard let identifier = (profile["chromeIdentifier"] as? String)?.split(separator: ".").last else { return chrome }
        let folder = "/Library/Developer/DeviceKit/Chrome/\(identifier).devicechrome/Contents/Resources/"
        guard let data = FileManager.default.contents(atPath: folder + "chrome.json"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let images = json["images"] as? [String: Any] else { return chrome }
        var pieces: [String: NSImage] = [:]
        for place in ["topLeft", "top", "topRight", "right", "bottomRight", "bottom", "bottomLeft", "left"] {
            if let name = images[place] as? String, let image = NSImage(contentsOfFile: folder + name + ".pdf") { pieces[place] = image }
        }
        guard pieces.count == 8, let sizing = images["sizing"] as? [String: Any], let side = sizing["leftWidth"] as? Double else { return chrome }
        chrome.pieces = pieces
        // Its composite picture of the 402 wide phone is 436 wide: one less than the "sizing" it names.
        chrome.inset = side - 1
        for input in json["inputs"] as? [[String: Any]] ?? [] {
            guard let name = input["image"] as? String, let up = NSImage(contentsOfFile: folder + name + ".pdf"),
                  let page = input["usagePage"] as? Int, let usage = input["usage"] as? Int,
                  let offsets = (input["offsets"] as? [String: Any])?["normal"] as? [String: Any], let y = offsets["y"] as? Double else { continue }
            let pressed = (input["imageDown"] as? String).flatMap { NSImage(contentsOfFile: folder + $0 + ".pdf") } ?? up
            chrome.buttons.append(Button(name: input["accessibilityTitle"] as? String ?? "", page: UInt64(page), usage: UInt64(usage), up: up, down: pressed, left: input["anchor"] as? String == "left", y: y))
        }
        return chrome
    }
}

/// The phone: its body and side buttons, the live screen in it.
final class PreviewPhoneView: NSView {
    let screen = PreviewScreenView()
    var chrome = PreviewChrome() {
        didSet {
            if chrome !== oldValue { needsLayout = true; needsDisplay = true }
        }
    }
    private var hovered: Int?
    private var pressed: Int?

    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(screen)
    }
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var scale: CGFloat {
        let whole = chrome.whole
        return min(bounds.width / whole.width, bounds.height / whole.height)
    }

    /// The body's place in this view.
    private var body: CGRect {
        let size = CGSize(width: chrome.body.width * scale, height: chrome.body.height * scale)
        return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
    }

    private func rect(_ button: PreviewChrome.Button, out: CGFloat) -> CGRect {
        let size = CGSize(width: button.up.size.width * scale, height: button.up.size.height * scale)
        let x = button.left ? body.minX - out * scale : body.maxX + out * scale - size.width
        return CGRect(x: x, y: body.minY + button.y * scale, width: size.width, height: size.height)
    }

    override func layout() {
        super.layout()
        screen.frame = body.insetBy(dx: chrome.inset * scale, dy: chrome.inset * scale)
        screen.shape(chrome.mask, corners: 24 * scale)
    }

    override func draw(_ dirty: NSRect) {
        for (index, button) in chrome.buttons.enumerated() {
            let image = pressed == index ? button.down : button.up
            draw(image, rect(button, out: hovered == index ? PreviewChrome.hovered : PreviewChrome.out))
        }
        let box = body
        guard chrome.pieces.count == 8 else {
            NSColor.black.setFill()
            NSBezierPath(roundedRect: box, xRadius: 32 * scale, yRadius: 32 * scale).fill()
            return
        }
        // Whole pixels, and the stretched sides run under the corners, or the pieces show a hairline where they meet.
        let pixel = 1 / (window?.backingScaleFactor ?? 2)
        let corner = ((chrome.pieces["topLeft"]?.size.width ?? 110) * scale / pixel).rounded() * pixel
        let frame = CGRect(x: (box.minX / pixel).rounded() * pixel, y: (box.minY / pixel).rounded() * pixel, width: (box.width / pixel).rounded() * pixel, height: (box.height / pixel).rounded() * pixel)
        NSColor.black.setFill()
        frame.insetBy(dx: corner / 2, dy: corner / 2).fill()
        let places: [(String, CGRect)] = [
            ("top", CGRect(x: frame.minX + corner - pixel, y: frame.minY, width: frame.width - 2 * corner + 2 * pixel, height: corner)),
            ("bottom", CGRect(x: frame.minX + corner - pixel, y: frame.maxY - corner, width: frame.width - 2 * corner + 2 * pixel, height: corner)),
            ("left", CGRect(x: frame.minX, y: frame.minY + corner - pixel, width: corner, height: frame.height - 2 * corner + 2 * pixel)),
            ("right", CGRect(x: frame.maxX - corner, y: frame.minY + corner - pixel, width: corner, height: frame.height - 2 * corner + 2 * pixel)),
            ("topLeft", CGRect(x: frame.minX, y: frame.minY, width: corner, height: corner)),
            ("topRight", CGRect(x: frame.maxX - corner, y: frame.minY, width: corner, height: corner)),
            ("bottomLeft", CGRect(x: frame.minX, y: frame.maxY - corner, width: corner, height: corner)),
            ("bottomRight", CGRect(x: frame.maxX - corner, y: frame.maxY - corner, width: corner, height: corner))
        ]
        for (place, where_) in places {
            if let image = chrome.pieces[place] { draw(image, where_) }
        }
    }

    private func draw(_ image: NSImage, _ rect: CGRect) {
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    // MARK: The side buttons

    private func button(at event: NSEvent) -> Int? {
        let point = convert(event.locationInWindow, from: nil)
        return chrome.buttons.indices.first { rect(chrome.buttons[$0], out: PreviewChrome.hovered).insetBy(dx: -2, dy: -2).contains(point) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        let now = button(at: event)
        if now != hovered {
            hovered = now
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if hovered != nil {
            hovered = nil
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard screen.live, let index = button(at: event) else { return }
        pressed = index
        needsDisplay = true
        let button = chrome.buttons[index]
        screen.model?.button(page: button.page, usage: button.usage, down: true)
    }

    override func mouseUp(with event: NSEvent) {
        guard let index = pressed else { return }
        pressed = nil
        needsDisplay = true
        let button = chrome.buttons[index]
        screen.model?.button(page: button.page, usage: button.usage, down: false)
    }
}

/// The phone in a SwiftUI view: with the simulator's screen in the pane, with a still on a design board.
struct PreviewPhone: NSViewRepresentable {
    var model: SimPreview?
    var chrome: PreviewChrome
    var picture: NSImage?
    var live: Bool

    func makeNSView(context: Context) -> PreviewPhoneView { PreviewPhoneView() }

    func updateNSView(_ view: PreviewPhoneView, context: Context) {
        view.chrome = chrome
        if view.screen.model !== model { view.screen.model = model }
        if let picture { view.screen.show(picture: picture) }
        view.screen.live = live
        view.screen.alphaValue = live ? 1 : 0.25
    }
}
