import SwiftUI

/// What Pin loads: Night Roll's real screens (App/UI) by board name, each in its own state with its own objects, so
/// no board can change another. Data is made up (App/UI/Samples.swift). Pressing a board moves it along the app's
/// flow; the same link table writes Pin's flows (NightRollProbe --setup).
@MainActor
public enum NightRollBoards {
    public struct Board: Sendable {
        public let name: String
        public let page: String
        /// Height when the board is a whole scrolling page, not one phone screen.
        public let height: CGFloat?
        /// Place on its page: column left to right, row top to bottom. Branches sit in rows below, so no arrow
        /// crosses another board.
        public var col = 0
        public var row = 0
        public var id: String { slug(name) }
    }

    public struct Link: Sendable {
        public let from: String
        public let label: String
        public let to: String
        /// Drawn as an arrow on Pin's canvas. Way-back links (Done, Close, Keep shooting) only work as taps, so the
        /// arrows show the way forward without crossing other boards.
        public var drawn = true
    }

    /// Every board, page by page, in the order they sit on the canvas.
    public static let boards: [Board] = [
        Board(name: "Onboarding what it does", page: "First open", height: nil, col: 0, row: 0),
        Board(name: "Onboarding allow", page: "First open", height: nil, col: 1, row: 0),
        Board(name: "Onboarding lock", page: "First open", height: nil, col: 2, row: 0),
        Board(name: "Onboarding lock Screen Time (paid team)", page: "First open", height: nil, col: 2, row: 1),
        Board(name: "Start roll", page: "Start a roll", height: nil, col: 0, row: 0),
        Board(name: "Start roll Screen Time (paid team)", page: "Start a roll", height: nil, col: 0, row: 1),
        Board(name: "Look", page: "Start a roll", height: nil, col: 1, row: 0),
        Board(name: "Develop time", page: "Start a roll", height: nil, col: 1, row: 1),
        Board(name: "Open apps", page: "Start a roll", height: nil, col: 1, row: 2),
        Board(name: "Camera not locked yet", page: "The night", height: nil, col: 0, row: 0),
        Board(name: "Camera fresh roll", page: "The night", height: nil, col: 0, row: 2),
        Board(name: "Camera mid roll", page: "The night", height: nil, col: 1, row: 0),
        Board(name: "Camera last shot", page: "The night", height: nil, col: 1, row: 1),
        Board(name: "Camera flash on", page: "The night", height: nil, col: 0, row: 1),
        Board(name: "Camera hold to end", page: "The night", height: nil, col: 2, row: 0),
        Board(name: "End early", page: "The night", height: nil, col: 3, row: 0),
        Board(name: "Roll full", page: "The night", height: nil, col: 2, row: 1),
        Board(name: "Ended early", page: "The night", height: nil, col: 4, row: 0),
        Board(name: "Developing", page: "Morning", height: 900, col: 0, row: 0),
        Board(name: "Contact sheet", page: "Morning", height: 1190, col: 1, row: 0),
        Board(name: "Photo", page: "Morning", height: nil, col: 2, row: 0),
        Board(name: "Photo saved", page: "Morning", height: nil, col: 3, row: 0),
        Board(name: "Save and share", page: "Morning", height: 1500, col: 2, row: 1),
        Board(name: "Rolls empty", page: "Rolls", height: nil, col: 0, row: 0),
        Board(name: "Rolls", page: "Rolls", height: nil, col: 1, row: 0),
        Board(name: "Settings", page: "Settings", height: nil, col: 0, row: 0),
        Board(name: "Guided Access guide", page: "Lock and permissions", height: 900, col: 0, row: 0),
        Board(name: "Guided Access on", page: "Lock and permissions", height: 900, col: 1, row: 0),
        Board(name: "Camera denied", page: "Lock and permissions", height: nil, col: 2, row: 0),
        Board(name: "Notifications denied", page: "Lock and permissions", height: nil, col: 3, row: 0),
        Board(name: "Paywall", page: "Paywall", height: nil, col: 0, row: 0),
        Board(name: "Options camera", page: "Options", height: nil, col: 0, row: 0),
        Board(name: "Options start", page: "Options", height: nil, col: 0, row: 1),
    ]

    /// Where each action on a screen leads. Taps on a board follow these; Pin's flows are made from them.
    public static let links: [Link] = [
        Link(from: "onboarding-what-it-does", label: "Next", to: "onboarding-allow"),
        Link(from: "onboarding-allow", label: "Next", to: "onboarding-lock"),
        Link(from: "onboarding-allow", label: "Camera not allowed", to: "camera-denied"),
        Link(from: "onboarding-allow", label: "Note not allowed", to: "notifications-denied"),
        Link(from: "onboarding-lock", label: "Show me how", to: "guided-access-guide"),
        Link(from: "onboarding-lock", label: "Later", to: "rolls-empty", drawn: false),
        Link(from: "onboarding-lock-screen-time-paid-team", label: "Allow Screen Time", to: "rolls-empty"),
        Link(from: "onboarding-lock-screen-time-paid-team", label: "Later", to: "rolls-empty", drawn: false),
        Link(from: "rolls-empty", label: "Start a roll", to: "start-roll"),
        Link(from: "rolls", label: "Start a roll", to: "start-roll"),
        Link(from: "rolls", label: "Open a roll", to: "contact-sheet"),
        Link(from: "rolls", label: "Settings", to: "settings"),
        Link(from: "settings", label: "Lock", to: "guided-access-guide"),
        Link(from: "settings", label: "Done", to: "rolls", drawn: false),
        Link(from: "start-roll", label: "Look", to: "look"),
        Link(from: "start-roll", label: "Develops", to: "develop-time"),
        Link(from: "start-roll", label: "Open apps", to: "open-apps"),
        Link(from: "start-roll", label: "Start roll", to: "camera-not-locked-yet"),
        Link(from: "start-roll", label: "Lock", to: "guided-access-guide", drawn: false),
        Link(from: "start-roll", label: "No free roll left", to: "paywall"),
        Link(from: "start-roll", label: "Close", to: "rolls", drawn: false),
        Link(from: "start-roll-screen-time-paid-team", label: "Start roll", to: "camera-fresh-roll"),
        Link(from: "camera-not-locked-yet", label: "Triple-click", to: "camera-fresh-roll"),
        Link(from: "camera-not-locked-yet", label: "Lock", to: "guided-access-guide", drawn: false),
        Link(from: "look", label: "Done", to: "start-roll", drawn: false),
        Link(from: "develop-time", label: "Done", to: "start-roll", drawn: false),
        Link(from: "open-apps", label: "Done", to: "start-roll", drawn: false),
        Link(from: "camera-fresh-roll", label: "Shutter", to: "camera-mid-roll"),
        Link(from: "camera-mid-roll", label: "Flash", to: "camera-flash-on", drawn: false),
        Link(from: "camera-mid-roll", label: "Hold End", to: "camera-hold-to-end"),
        Link(from: "camera-hold-to-end", label: "3 seconds", to: "end-early"),
        Link(from: "camera-last-shot", label: "Last shot", to: "roll-full"),
        Link(from: "end-early", label: "Keep shooting", to: "camera-mid-roll", drawn: false),
        Link(from: "end-early", label: "End roll", to: "ended-early"),
        Link(from: "roll-full", label: "Done", to: "rolls", drawn: false),
        Link(from: "ended-early", label: "Done", to: "rolls", drawn: false),
        Link(from: "roll-full", label: "09:00 note", to: "developing"),
        Link(from: "developing", label: "Developed", to: "contact-sheet"),
        Link(from: "contact-sheet", label: "Tap a frame", to: "photo"),
        Link(from: "contact-sheet", label: "Select", to: "save-and-share"),
        Link(from: "contact-sheet", label: "Save all", to: "rolls", drawn: false),
        Link(from: "contact-sheet", label: "Close", to: "rolls", drawn: false),
        Link(from: "photo", label: "Save", to: "photo-saved"),
        Link(from: "photo", label: "Close", to: "contact-sheet", drawn: false),
        Link(from: "photo-saved", label: "Close", to: "contact-sheet", drawn: false),
        Link(from: "save-and-share", label: "Cancel", to: "contact-sheet", drawn: false),
        Link(from: "save-and-share", label: "Save", to: "rolls", drawn: false),
        Link(from: "guided-access-guide", label: "Done", to: "start-roll"),
        Link(from: "paywall", label: "Close", to: "start-roll", drawn: false),
    ]

    public static func size(_ name: String) -> CGSize {
        if name == "Options camera" || name == "Options start" { return CGSize(width: 1291, height: 1086) }
        let board = boards.first { $0.name == name }
        return CGSize(width: NRLayout.phoneWidth, height: board?.height ?? NRLayout.phoneHeight)
    }

    public static func board(_ name: String, still: Bool = false) -> AnyView {
        AnyView(make(name).environment(\.nrStill, still))
    }

    private static func make(_ name: String) -> AnyView {
        let size = size(name)
        if name == "Options camera" {
            return AnyView(OptionsBoard(screenName: "Camera") {
                QuietCameraScreen(state: Samples.camera(left: 13)) { Viewfinder() }
            } b: {
                DisposableCameraScreen(state: Samples.camera(left: 13)) { Viewfinder() }
            } c: {
                ContactPrintCameraScreen(state: Samples.camera(left: 13)) { Viewfinder() }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(NRColor.raised))
        }
        if name == "Options start" {
            return AnyView(OptionsBoard(screenName: "Start a roll") {
                StartRollScreen(state: Samples.startRoll())
            } b: {
                DisposableStartScreen(state: Samples.startRoll())
            } c: {
                ContactPrintStartScreen(state: Samples.startRoll())
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(NRColor.raised))
        }
        let id = slug(name)
        return AnyView(
            BoardPhone(height: size.height) { Host(start: id) }
                .frame(width: size.width, height: size.height)
                .background(NRColor.canvas)
                .preferredColorScheme(.dark)
        )
    }

    static func next(from id: String, _ label: String) -> String? {
        links.first { $0.from == id && $0.label == label }?.to
    }

    /// The same slug Pin's Store makes from a screen name.
    nonisolated static func slug(_ text: String) -> String {
        text.lowercased().split { !($0.isLetter || $0.isNumber) }.joined(separator: "-")
    }
}

/// The camera's still picture on boards: a made-up night scene, never a real photo.
private struct Viewfinder: View {
    var body: some View { PlaceholderPhoto(seed: 11, tone: .warm) }
}

/// One board: a screen in its state, with taps that change the state or follow a link to the next screen.
private struct Host: View {
    @State private var id: String
    @State private var camera: CameraState
    @State private var start: StartRollState
    @State private var lookPicker = Samples.lookPicker
    @State private var developTime = Samples.developTime
    @State private var apps = Samples.allowedApps()
    @State private var photo: PhotoState
    @State private var saveShare = Samples.saveShare
    @State private var paywall = Samples.paywall
    @State private var onboarding: OnboardingState

    init(start id: String) {
        _id = State(initialValue: id)
        _camera = State(initialValue: Self.camera(for: id))
        _start = State(initialValue: Samples.startRoll(lock: id == "start-roll-screen-time-paid-team" ? .screenTime : .guidedAccess))
        _photo = State(initialValue: Samples.photo(saved: id == "photo-saved"))
        _onboarding = State(initialValue: Self.onboarding(for: id))
    }

    var body: some View {
        screen
            .id(id)
            .transition(NRMotion.appear)
    }

    private func go(_ label: String) {
        guard let to = NightRollBoards.next(from: id, label) else { return }
        withAnimation(NRMotion.snap) {
            camera = Self.camera(for: to)
            photo = Samples.photo(saved: to == "photo-saved")
            onboarding = Self.onboarding(for: to)
            start = Samples.startRoll(lock: to == "start-roll-screen-time-paid-team" ? .screenTime : .guidedAccess)
            id = to
        }
    }

    private static func camera(for id: String) -> CameraState {
        switch id {
        case "camera-not-locked-yet": Samples.camera(left: 24, lock: .unavailable)
        case "camera-fresh-roll": Samples.camera(left: 24)
        case "camera-last-shot": Samples.camera(left: 1)
        case "camera-flash-on": Samples.camera(left: 11, flash: true)
        case "camera-hold-to-end": Samples.camera(left: 11, hold: 0.62)
        default: Samples.camera(left: 11)
        }
    }

    private static func onboarding(for id: String) -> OnboardingState {
        switch id {
        case "onboarding-allow": Samples.onboarding(.permissions)
        case "onboarding-lock": Samples.onboarding(.lock)
        case "onboarding-lock-screen-time-paid-team": Samples.onboarding(.lock, screenTime: true)
        default: Samples.onboarding(.intro)
        }
    }

    @ViewBuilder private var screen: some View {
        switch id {
        case "onboarding-what-it-does", "onboarding-allow", "onboarding-lock", "onboarding-lock-screen-time-paid-team":
            OnboardingScreen(state: onboarding, onNext: { go("Next") },
                             onAllowCamera: { onboarding.cameraAllowed = true },
                             onAllowNotifications: { onboarding.notificationsAllowed = true },
                             onSetUpLock: { go(onboarding.screenTimeAvailable ? "Allow Screen Time" : "Show me how") },
                             onLater: { go("Later") })
        case "start-roll", "start-roll-screen-time-paid-team":
            StartRollScreen(state: start, onShots: { start.shots = $0 }, onLook: { go("Look") },
                            onDevelop: { go("Develops") }, onApps: { go("Open apps") }, onLockHelp: { go("Lock") },
                            onClose: { go("Close") }, onStart: { go("Start roll") })
        case "look":
            LookPickerScreen(state: lookPicker, onPick: { lookPicker.selectedID = $0 }, onDone: { go("Done") })
        case "develop-time":
            DevelopTimeScreen(state: developTime, onPick: { developTime.selectedID = $0 }, onDone: { go("Done") })
        case "open-apps":
            AllowedAppsScreen(state: apps, onToggle: { appID, on in
                if let i = apps.apps.firstIndex(where: { $0.id == appID }) { apps.apps[i].isOn = on }
            }, onDone: { go("Done") })
        case "camera-not-locked-yet", "camera-fresh-roll", "camera-mid-roll", "camera-last-shot", "camera-flash-on",
             "camera-hold-to-end":
            CameraScreen(state: camera) { Viewfinder() } onShutter: {
                if camera.shotsLeft <= 1 { go("Last shot") } else { camera.shotsLeft -= 1 }
            } onFlash: {
                camera.flashOn.toggle()
            } onEndEarly: {
                id = "camera-hold-to-end"; go("3 seconds")
            } onLockInfo: {
                go("Lock")
            }
        case "end-early":
            EndEarlyScreen(state: Samples.endEarly) {
                CameraScreen(state: Samples.camera(left: 11)) { Viewfinder() }
            } onKeepShooting: { go("Keep shooting") } onEnd: { go("End roll") }
        case "roll-full":
            WaitingScreen(state: Samples.waiting(.rollFull), onDone: { go("Done") })
        case "ended-early":
            WaitingScreen(state: Samples.waiting(.endedEarly), onDone: { go("Done") })
        case "developing":
            DevelopingScreen(state: Samples.developing)
                .onTapGesture { go("Developed") }
        case "contact-sheet":
            ContactSheetScreen(state: Samples.contactSheet, onOpen: { frame in go("Tap a frame"); photo = Samples.photo(frame) },
                               onSelect: { go("Select") }, onSaveAll: { go("Save all") }, onClose: { go("Close") })
        case "photo", "photo-saved":
            PhotoScreen(state: photo, onClose: { go("Close") },
                        onPrevious: { if photo.photo.id > 1 { photo = Samples.photo(photo.photo.id - 1) } },
                        onNext: { if photo.photo.id < photo.count { photo = Samples.photo(photo.photo.id + 1) } },
                        onSave: { withAnimation(NRMotion.snap) { photo.isSaved = true } })
        case "save-and-share":
            SaveShareScreen(state: saveShare, onToggle: { photoID in
                if saveShare.selected.contains(photoID) { saveShare.selected.remove(photoID) } else { saveShare.selected.insert(photoID) }
            }, onAll: { saveShare.selected = Set(saveShare.photos.map(\.id)) },
                            onSave: { go("Save") }, onCancel: { go("Cancel") })
        case "rolls-empty":
            RollsScreen(state: Samples.rollsEmpty, onStart: { go("Start a roll") })
        case "rolls":
            RollsScreen(state: Samples.rolls, onOpen: { _ in go("Open a roll") }, onStart: { go("Start a roll") },
                        onSettings: { go("Settings") })
        case "settings":
            SettingsScreen(state: Samples.settings, onLock: { go("Lock") }, onDone: { go("Done") })
        case "guided-access-guide", "guided-access-on":
            GuidedAccessScreen(state: GuidedAccessState(isOn: id == "guided-access-on"), onDone: { go("Done") })
        case "camera-denied":
            PermissionDeniedScreen(state: PermissionDeniedState(kind: .camera))
        case "notifications-denied":
            PermissionDeniedScreen(state: PermissionDeniedState(kind: .notifications))
        case "paywall":
            PaywallScreen(state: paywall, onPick: { paywall.selectedID = $0 }, onClose: { go("Close") })
        default:
            Text("No board named \(id)").nrType(.body).foregroundStyle(NRColor.text)
        }
    }
}

/// Pin's way in: a live board by name, as a pointer to its view. Pin owns the pointer afterwards.
@_cdecl("pin_board")
public func pinBoard(_ name: UnsafePointer<CChar>) -> UnsafeMutableRawPointer {
    MainActor.assumeIsolated {
        let view = UnsafeMutablePointer<AnyView>.allocate(capacity: 1)
        view.initialize(to: NightRollBoards.board(String(cString: name)))
        return UnsafeMutableRawPointer(view)
    }
}
