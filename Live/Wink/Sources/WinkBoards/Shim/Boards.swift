import SwiftUI

/// What Pin loads: Wink's real screens, by board name, each with its own model and made-up data. Nothing runs the engine.
@MainActor
enum WinkBoards {
    private enum Frame { case mac, phone, drawer, preview(SimPane.State), previewChip }

    private struct Spec {
        var frame = Frame.mac
        var chat: String?
        var page: AppModel.Page?
        var review: String?
        var env: [String: String] = [:]
        var setup: (AppModel) -> Void = { _ in }
    }

    private static let cut = "the drone shot stays as the opener"

    private static func spec(_ board: String) -> Spec {
        switch board {
        case "mac-start", "new-mac-side-list-with-agents": return Spec()
        case "new-mac-preview-an-app": return Spec(frame: .preview(.running), chat: "plain")
        case "new-mac-preview-building": return Spec(frame: .preview(.building), chat: "plain")
        case "new-mac-preview-in-the-bar": return Spec(frame: .previewChip, chat: "plain")
        case "mac-chat": return Spec(chat: "penpot")
        case "mac-chat-sidebar-hidden": return Spec(chat: "penpot", setup: { $0.sideShut = true })
        case "mac-chat-with-steps-open": return Spec(chat: "steps", env: ["WINK_STEPS": "1"])
        case "mac-compacted": return Spec(chat: "compacted")
        case "mac-compacted-open": return Spec(chat: "compacted", env: ["WINK_STEPS": "1"])
        case "mac-compacting": return Spec(chat: "compacting")
        case "mac-permission-question": return Spec(chat: "permission")
        case "mac-replying-to-the-selection":
            return Spec(chat: "plain", env: ["WINK_DRAFT": "Make it shorter, start with the bridge instead"], setup: { $0.quote["plain"] = cut })
        case "mac-right-click-on-a-file": return Spec(chat: "file", env: ["WINK_CONTEXT": "Launch_v3.mov"])
        case "mac-select-text-and-reply": return Spec(chat: "plain", env: ["WINK_REPLY_PILL": "520,104"])
        case "mac-to-do-list-and-thinking": return Spec(chat: "todo")
        case "mac-working": return Spec(chat: "working")
        case "new-mac-after-start-the-chat-with-the-brief": return Spec(chat: "brief")
        case "new-mac-output-a-chat-with-a-video", "new-mac-output-small-window": return Spec(chat: "output")
        case "new-mac-output-a-chat-without-video": return Spec(chat: "output2")

        case "mac-after-the-drop":
            return Spec(chat: "plain", env: ["WINK_DRAFT": "Use these for the outro"], setup: {
                $0.attached["plain"] = [("Outro.mov", "file"), ("Logo.png", "image"), ("Credits.md", "file")].map {
                    Attachment(ref: FileRef(name: $0.0, kind: $0.1, path: Fixtures.file($0.0)))
                }
            })
        case "mac-drop-zone": return Spec(chat: "plain", env: ["WINK_DROPPING": "1"])
        case "mac-instant-send-not-sent":
            return Spec(chat: "plain", env: ["WINK_OUTBOX": "shown"], setup: {
                // As wink2's own picture hook does it: these stay "on their way" whatever the chat shows.
                $0.outbox.settle("plain", users: 1_000_000)
                $0.outbox.add("Make the titles white instead of yellow", to: "plain")
                $0.outbox.fail($0.outbox.add("And add the logo at the end", to: "plain"), in: "plain")
            })
        case "mac-model-and-effort": return Spec(env: ["WINK_PICKER": "1"])
        case "mac-model-list": return Spec(env: ["WINK_PICKER": "list"])
        case "mac-queue-while-it-works":
            return Spec(chat: "queue", env: ["WINK_OUTBOX": "shown"], setup: {
                $0.outbox.queue("And export a 9:16 version for Instagram", to: "queue")
                $0.outbox.queue("Send me the link when it is rendered", to: "queue")
            })
        case "mac-skill-in-use": return Spec(chat: "skill")
        case "mac-skill-list": return Spec(setup: { $0.draft = "/" })
        case "mac-usage-high": return Spec(chat: "high", env: ["WINK_PEEK": "1"])
        case "mac-usage-in-the-box": return Spec(chat: "plain", env: ["WINK_PEEK": "1"])
        case "mac-usage-not-reported": return Spec(chat: "silent", env: ["WINK_PEEK": "1"])

        case "mac-buddy": return Spec(chat: "buddy")
        case "mac-delete-dialog": return Spec(env: ["WINK_DIALOG": "1"])
        case "mac-search":
            return Spec(env: ["WINK_SEARCH": "wink"], setup: { $0.chats += Fixtures.searchExtras })
        case "mac-new-task-via-chat": return Spec(setup: { $0.draft = "/tasks remind me to send Leonie the cut on Thursday" })
        case "mac-new-automation-via-chat": return Spec(setup: { $0.draft = "/automation every Friday at 17:00 check my Salto week" })
        case "new-mac-new-agent-via-chat": return Spec(setup: { $0.draft = "/agent watch Galaxus for a cheap Dyson under 200 CHF" })

        case "window-tasks": return Spec(page: .tasks, env: ["WINK_UNFOLD": "1"])
        case "window-automations": return Spec(page: .jobs, setup: { $0.chats += Fixtures.jobChats })
        case "new-mac-agents": return Spec(page: .agents)
        case "window-settings-general": return Spec(page: .settings)
        case "window-settings-general-model-menu": return Spec(page: .settings, env: ["WINK_MENU": "Model"])
        case "window-settings-instructions": return Spec(page: .instructions)
        case "window-settings-harnesses": return Spec(page: .harnesses)
        case "window-settings-data": return Spec(page: .data, setup: { $0.chats += Fixtures.archivedChats })

        case "mac-video-in-the-chat": return Spec(chat: "video")
        case "mac-video-review": return Spec(chat: "video", review: "Launch_v3.mov", env: ["WINK_REVIEW_NOTE": "n2"])
        case "mac-video-review-marking-an-area":
            return Spec(chat: "video", review: "Launch_v3.mov",
                        env: ["BOARD_NOTES": "2", "WINK_REVIEW_MARK": "0.78,0.78,0.18,0.14", "WINK_DRAFT": "Make the logo smaller and move it into the corner"])
        case "mac-video-review-v4": return Spec(chat: "video", review: "Launch_v4.mov")

        // The iPhone's boards run the same screens at the iPhone's size. Code only the iPhone build compiles cannot run here.
        case "iphone-start": return Spec(frame: .phone)
        case "iphone-chat": return Spec(frame: .phone, chat: "phone")
        case "iphone-compacted": return Spec(frame: .phone, chat: "compacted")
        case "iphone-menu", "iphone-menu-with-buddy", "new-iphone-menu-with-agents": return Spec(frame: .drawer)
        case "iphone-settings": return Spec(frame: .phone, page: .settings)
        case "iphone-tasks": return Spec(frame: .phone, page: .tasks)
        case "iphone-automations": return Spec(frame: .phone, page: .jobs, setup: { $0.chats += Fixtures.jobChats })
        case "new-iphone-agents": return Spec(frame: .phone, page: .agents)
        case "new-iphone-output": return Spec(frame: .phone, chat: "output")
        case "iphone-video-review": return Spec(frame: .phone, chat: "video", review: "Launch_v3.mov", env: ["WINK_REVIEW_NOTE": "n2"])
        default: return Spec()
        }
    }

    static func board(_ name: String) -> AnyView {
        let spec = spec(name)
        let env = BoardEnv.base.merging(spec.env) { $1 }
        return BoardEnv.$current.withValue(env) {
            let model = AppModel()
            model.harnesses = Fixtures.harnesses
            model.skills = Fixtures.skills
            model.status = Fixtures.status
            // The side list counts 3 open tasks, as on the boards; only the Tasks page has the long list.
            model.todos = spec.page == .tasks ? Fixtures.todos : Array(Fixtures.todos.prefix(3))
            model.todosLoaded = true
            model.agents = Fixtures.agents
            model.chats = Fixtures.sideList(open: spec.chat.flatMap { Fixtures.details[$0]?.chat })
            model.current = spec.chat
            model.page = spec.page
            if let film = spec.review {
                model.review = ReviewTarget(path: Fixtures.file(film), chat: spec.chat)
                model.sideShut = true
            }
            spec.setup(model)
            let screen = Self.screen(spec.frame)
                .environment(model)
                .tint(.primary)
                .font(.wink(.body))
                .environment(\.colorScheme, .dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            return AnyView(BoardScene(env: env, content: AnyView(screen)))
        }
    }

    @ViewBuilder private static func screen(_ frame: Frame) -> some View {
        switch frame {
        case .mac:
            Zoomed { Root().winkOverlays() }
                .overlay(alignment: .topLeading) { WindowDots() }
        case .preview(let state):
            Zoomed { SimPaneBoard(state: state, picture: Fixtures.file("sim-app.png")).winkOverlays() }
                .overlay(alignment: .topLeading) { WindowDots() }
        case .previewChip:
            Zoomed { SimChipBoard().winkOverlays() }
                .overlay(alignment: .topLeading) { WindowDots() }
        case .phone:
            PhoneScreen().winkOverlays().coordinateSpace(.named(WinkZoom.space))
                .safeAreaPadding(.top, 54)
                .overlay(alignment: .top) { PhoneStatusBar() }
                .background(Theme.canvas)
        case .drawer:
            ZStack(alignment: .leading) {
                Theme.tile
                Sidebar().frame(width: Theme.side).padding(.top, 54)
                Detail().background(Theme.canvas).offset(x: Theme.side)
            }
            .winkOverlays().coordinateSpace(.named(WinkZoom.space))
            .overlay(alignment: .top) { PhoneStatusBar() }
        }
    }

    /// As the iPhone's Root shows a page or a chat, without its drawer.
    private struct PhoneScreen: View {
        @Environment(AppModel.self) private var app
        var body: some View {
            Group {
                if let page = app.page { PageView(page: page) } else { Detail() }
            }
            .background(Theme.canvas)
        }
    }
}

/// Pin's way in: a live board by name, as a pointer to its view. Pin owns the pointer afterwards.
@_cdecl("pin_board")
public func pinBoard(_ name: UnsafePointer<CChar>) -> UnsafeMutableRawPointer {
    MainActor.assumeIsolated {
        let view = UnsafeMutablePointer<AnyView>.allocate(capacity: 1)
        view.initialize(to: WinkBoards.board(String(cString: name)))
        return UnsafeMutableRawPointer(view)
    }
}
