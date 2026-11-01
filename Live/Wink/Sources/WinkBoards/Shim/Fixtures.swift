import Foundation

/// All made up. Names and words come from the boards themselves; nothing here is read from Wink's chats or database.
enum Fixtures {
    static let folder = URL(fileURLWithPath: "/Users/damian/tools/pin/Live/Wink/Fixtures")
    static func file(_ name: String) -> String { folder.appendingPathComponent(name).path }
    static let now = Date().timeIntervalSince1970

    // MARK: Chats

    static func chat(_ id: String, _ title: String, harness: String = "claude", model: String = "claude-opus-5-5", state: String = "idle",
                     unread: Bool = false, job: String? = nil, preview: String? = nil, pinned: Bool = false, archived: Bool = false, ago: Double = 3600) -> Chat {
        Chat(id: id, title: title, harness: harness, model: model, folder: "~", state: state, unread: unread, job: job,
             created: now - ago, updated: now - ago, preview: preview, archived: archived, pinned: pinned, named: true)
    }

    /// The side list every board shows. `open` takes the place of the row with its title, so that row is the lit one.
    static func sideList(open: Chat?) -> [Chat] {
        var list = [
            chat("night", "Night: Kalogeras", unread: true, job: "night", preview: "Found two matches, one needs you.", ago: 7200),
            chat("launch", "Launch film", pinned: true), chat("brand", "Brand colours", pinned: true),
            chat("lisbon", "Trip to Lisbon", pinned: true), chat("reflection", "Weekly reflection", pinned: true),
            chat("penpot", "Try out Penpot with Wink", state: "working", ago: 60),
            chat("newsletter", "Newsletter draft", unread: true, ago: 1800), chat("landlord", "Reply to the landlord", ago: 2400),
            chat("buddy", "Buddy", unread: true, preview: "Morning. 3 things for today", ago: 600),
        ]
        if let open {
            if let index = list.firstIndex(where: { $0.title == open.title }) {
                var same = open
                same.pinned = list[index].pinned
                list[index] = same
            } else { list.insert(open, at: 5) }
        }
        return list
    }

    static let searchExtras = [
        chat("s1", "Long job: Wink 2.0", pinned: true), chat("s2", "Night: Wink (approved…)", ago: 3000),
        chat("s3", "Nightly: Wink 2", unread: true, ago: 3600), chat("s4", "Wink comparison", ago: 400_000),
        chat("s5", "Wink", ago: 500_000), chat("s6", "Night: Wink 2", archived: true, ago: 900_000),
        chat("s7", "Wink harness", archived: true, ago: 950_000),
    ]
    static let hits: [SearchHit] = []

    static let archivedChats = [
        chat("a1", "Night: Wink 2", archived: true, ago: 900_000), chat("a2", "Tasks: afternoon", archived: true, ago: 910_000),
        chat("a3", "Test: chat id check", archived: true, ago: 920_000), chat("a4", "Slack: news the 25 Oct", archived: true, ago: 930_000),
        chat("a5", "Weekly reflection 19 Oct", archived: true, ago: 940_000),
    ]

    static let jobChats = [
        chat("j1", "Tasks: morning", job: "morning", preview: "The morning run is done. A quiet night: two new mails, both newsletters, nothing from Slack.", archived: true),
        chat("j2", "Tasks: afternoon", job: "afternoon", preview: "Ticked two tasks and moved the dentist to Thursday. Nothing new needs you.", archived: true),
        chat("j3", "Website check", job: "website", preview: "I checked both pages and changed nothing today.", archived: true),
    ]

    // MARK: A chat's blocks

    static func you(_ id: String, _ text: String, status: String? = nil) -> Block { Block(id: id, kind: .user, text: text, status: status) }
    static func says(_ id: String, _ text: String) -> Block { Block(id: id, kind: .text, text: text) }
    static func step(_ id: String, _ title: String, result: String? = nil, status: String = "done") -> Block {
        Block(id: id, kind: .tool, glyph: "⏺", title: title, text: result, status: status)
    }
    static func turn(_ id: String, _ seconds: Double) -> Block { Block(id: id, kind: .turn, seconds: seconds) }
    static func live(_ seconds: Double, tokens: Int?) -> Live { Live(since: now - seconds, tokens: tokens) }

    static func detail(_ id: String, _ title: String, harness: String = "claude", model: String = "claude-opus-5-5", state: String = "idle",
                       live: Live? = nil, usage: Usage? = plainUsage, _ blocks: [Block]) -> ChatDetail {
        ChatDetail(chat: chat(id, title, harness: harness, model: model, state: state, ago: 60), blocks: blocks, usage: usage, version: 1, live: live)
    }

    static let plainUsage = Usage(contextUsed: 124_000, contextMax: 200_000, limits: [Limit(name: "5-hour limit", used: 0.41, resets: now + 3 * 3600), Limit(name: "Week", used: 0.61, resets: now + 4 * 86400)])
    static let highUsage = Usage(contextUsed: 182_000, contextMax: 200_000, limits: [Limit(name: "5-hour limit", used: 0.82, resets: now + 3600), Limit(name: "Week", used: 0.91, resets: now + 86400)])

    static let cut = [you("u", "Cut the intro to 20 seconds and keep the drone shot"), step("s", "Bash(resolve-cli trim intro 00:20)"), turn("t", 48),
                      says("a", "Done. The intro is 20 seconds now and the drone shot stays as the opener.")]
    static let compacted = cut + [
        Block(id: "c0", kind: .user, text: "/compact", compact: true),
        Block(id: "c1", kind: .notice, title: "Chat compacted · 896k → 17k",
              text: "The intro of the launch film is cut to 20 seconds, the drone shot stays as the opener.\nNext: export v3 with the new intro, then the music fade at the end.",
              status: "done", compact: true),
    ]
    static let penpot = [
        you("u1", "Can you connect to Penpot and build the Wink 2 start screen?"), step("s1", "penpot - execute_code (MCP)(Start screen)"), turn("t1", 64),
        says("a1", "Penpot is connected. I made a Wink 2 file and built the start screen from real layers: the side list, the greeting and the message box.\n\nEverything stays editable, so you can move, recolour or rename any piece."),
        you("u2", "Now do the tasks page too"), step("s2", "penpot - execute_code (MCP)(Tasks window)", status: "running"),
    ]
    static let film = file("Launch_v3.mov")

    static let details: [String: ChatDetail] = {
        let list: [ChatDetail] = [
            detail("penpot", "Try out Penpot with Wink", state: "working", live: live(12, tokens: 1200), penpot),
            detail("plain", "Launch film", cut),
            detail("phone", "Launch film", [you("u", "Cut the intro to 20 seconds and keep the drone shot"), step("s", "Bash(resolve-cli trim intro 00:20)"), turn("t", 48),
                                            says("a", "Done. The intro is 20 seconds now and the drone shot stays as the opener.\n\nWant a 9:16 version for Instagram?")]),
            detail("steps", "Launch film", [you("u", "Run the check and tell me if the build is clean"),
                                            step("s1", "Bash(./build.sh check)", result: "design checks: passed"),
                                            step("s2", "Read(App/ChatView.swift)", result: "Read 412 lines"),
                                            step("s3", "Bash(./build.sh mac)", result: "built: build/Build/Products/Release/Wink.app"), turn("t", 14),
                                            says("a", "Clean. The design check passed and the Mac app built without a warning.")]),
            detail("compacted", "Launch film", compacted),
            detail("compacting", "Launch film", state: "working", live: live(21, tokens: nil), cut + [Block(id: "c0", kind: .user, text: "/compact", compact: true),
                Block(id: "c1", kind: .notice, title: "Compacting…", status: "running", compact: true)]),
            detail("permission", "Launch film", state: "waiting", [you("u", "Write a test file into the proof folder"),
                step("s", "Write(~/tools/wink2/proof/claude/wink-test.txt)", status: "running"),
                Block(id: "p", kind: .permission, title: "Do you want to proceed?", text: "Write(~/tools/wink2/proof/claude/wink-test.txt)", status: "waiting",
                      choices: [Choice(id: "y", label: "Yes", allow: true), Choice(id: "a", label: "Yes, and don’t ask again for this folder", allow: true),
                                Choice(id: "n", label: "No, and tell Claude what to do differently", allow: false)])]),
            detail("file", "Launch film", [you("u", "Cut the intro to 20 seconds and keep the drone shot"), turn("t", 48), says("a", "Done. I exported the new cut here:\n\n\(film)")]),
            detail("todo", "Launch film", state: "working", live: live(21, tokens: 1800), [you("u", "Make the five changes from my notes, one by one"),
                Block(id: "th", kind: .thinking, text: "He wants each note done on its own, so a to-do list keeps the order visible. Start with the title colour, it is the smallest."),
                Block(id: "l", kind: .todo, glyph: "⏺", title: "5 tasks (2 done, 1 in progress, 2 open)", items: [
                    Step(text: "Titles white instead of yellow", state: "done", glyph: "✔"), Step(text: "Logo at the end", state: "done", glyph: "✔"),
                    Step(text: "Cut the intro to 20 s", state: "active", glyph: "◼"), Step(text: "Keep the drone shot", state: "pending", glyph: "◻"),
                    Step(text: "Export for Instagram", state: "pending", glyph: "◻")])]),
            detail("working", "Launch film", state: "working", live: live(21, tokens: 1800), [you("u", "Export the reel for Instagram"),
                step("s", "Bash(ffmpeg -i reel.mov -vf scale=1080:1920 reel-ig.mp4)", result: "frame= 412 fps=96 time=00:00:13.7", status: "running")]),
            detail("queue", "Launch film", state: "working", live: live(48, tokens: 3400), [you("u", "Cut the intro to 20 seconds and keep the drone shot"),
                step("s1", "Read(Launch_v2.drp)"), step("s2", "Bash(resolve-cli trim intro 00:20)"),
                you("u2", "Also make the music fade out at the end", status: "delivered"), step("s3", "Bash(./build.sh check)", status: "running")]),
            detail("skill", "Launch film", state: "working", live: live(14, tokens: 2300), [you("u", "/yoveo-video cut the intro to 20 seconds"),
                Block(id: "sk", kind: .tool, glyph: "⏺", title: "Skill(yoveo-video)", text: "Launching skill: yoveo-video", status: "done", skills: ["yoveo-video"]),
                step("s", "Read(Launch_v2.drp)", status: "running")]),
            detail("high", "Launch film", usage: highUsage, cut),
            detail("silent", "Launch film", harness: "antigravity", model: "gemini-3-pro", usage: Usage(), cut),
            detail("video", "Launch film", state: "working", live: live(6, tokens: nil), [you("u", "Export the launch film for review"), turn("t", 30),
                says("a", "Here it is. Open it, scrub through and leave your notes on the picture.\n\n\(film)"),
                you("n", "3 notes on Launch_v3.mov:\n- 0:12 Start on the drone shot, not the logo\n- 0:42 Make the logo smaller and move it into the corner\n- 1:32 The music is too loud under the interview")]),
            detail("buddy", "Buddy", [you("c", "Check-in · morning"), turn("t", 9),
                says("a", "Morning. You went to bed at 2:30 after cutting 59 tasks to 34, so coffee first. School today, Dad’s call at 19:00.\n\n1. Konzeptbeschrieb: print it and hand it in today, it’s the last chance.\n2. IPA papers to your supervisor.\n3. Banking: Salt is due today.\n\nWaiting on you: keep last night’s AutoBalance changes? Reply keep or throw away in its chat.")]),
            detail("brief", "Leonie: reply about the explainer", state: "working", live: live(12, tokens: 1100), [
                you("u", "Draft the reply to Leonie about the explainer.\nWhy: she asked twice. The shoot is next week.\nWhat is known: her Slack messages of 26 and 27 Oct, the brief in the project’s channel, the shoot day in the calendar.\nDone when: a short draft in her language, ready for Allow once. Do not send it."),
                step("s", "Read(Slack: Leonie)", status: "running")]),
            detail("output", "Launch film", [you("u", "Export the launch film and make a thumbnail"), turn("t", 40),
                says("a", "Done. The film and the thumbnail are in Output on the right.\n\n\(film)\n\n\(file("Teaser_v2.mov"))\n\n\(file("Thumbnail.png"))\n\n\(file("Launch_brief.pdf"))\n\n\(file("Deliverables"))")]),
            detail("output2", "Brand colours", [you("u", "Write down our brand colours"), turn("t", 20),
                says("a", "Here is the palette and a short guide. No video in this chat, so Output only lists these files.\n\n\(file("Palette.png"))\n\n\(file("Brand_guide.pdf"))\n\n\(file("Colours.md"))\n\n\(file("Tokens.json"))")]),
        ]
        return Dictionary(uniqueKeysWithValues: list.map { ($0.chat.id, $0) })
    }()

    static func info(_ path: String) -> OutputInfo {
        let folder = (path as NSString).pathExtension.isEmpty
        return OutputInfo(path: path, found: true, folder: folder, size: 2_000_000, count: folder ? 6 : nil, offline: false)
    }

    static let notes = [
        ReviewNote(id: "n1", time: 12, text: "Start on the drone shot, not the logo", version: "v3"),
        ReviewNote(id: "n2", time: 42, text: "Make the logo smaller and move it into the corner", area: [0.78, 0.78, 0.18, 0.14], version: "v3"),
        ReviewNote(id: "n3", time: 92, text: "The music is too loud under the interview", version: "v3"),
    ]

    // MARK: The rest of the engine's answers

    static let status = Status(owner: "Damian", scheduler: true, address: "", buddy: "buddy")
    static let harnesses = [
        Harness(id: "claude", name: "Claude Code", route: "stream-json", models: ["claude-fable-5-1", "claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5"],
                modes: [Mode(id: "default", name: "Default"), Mode(id: "acceptEdits", name: "Accept Edits"), Mode(id: "plan", name: "Plan Mode"), Mode(id: "bypassPermissions", name: "Bypass Permissions")],
                defaultMode: "bypassPermissions", efforts: ["claude-opus-5-5": Levels(options: ["low", "medium", "high", "xhigh", "max"], standard: "low")], effortWord: "effort", missing: [], problems: []),
        Harness(id: "codex", name: "Codex", route: "app-server", models: ["gpt-6-astra", "gpt-6"], modes: [], defaultMode: nil,
                efforts: ["gpt-6-astra": Levels(options: ["low", "medium", "high"], standard: "medium")], effortWord: "reasoning", missing: [], problems: []),
        Harness(id: "antigravity", name: "Antigravity", route: "print", models: ["gemini-3-pro", "gemini-4-argon"], modes: [], defaultMode: nil, efforts: [:], effortWord: "effort",
                missing: [Missing(feature: "Usage", short: "Reports no usage", reason: "Its print route does not say how much is used.")], problems: []),
        Harness(id: "hermes", name: "Hermes", route: "acp", models: ["hermes-4"], modes: [], defaultMode: nil, efforts: [:], effortWord: "reasoning", missing: [], problems: []),
    ]
    static let skills = [
        ("app-store-product-researcher", "Research App Store niches to find winning app ideas."), ("app-tester", "End-to-end QA for SwiftUI apps on the Simulator and Mac."),
        ("apple-app-design", "Design, prototype, improve or review native Apple app screens."), ("autoskills", "Detect and install project-specific agent skills."),
        ("bbz", "Damian’s school (BZZ, class ME23f) in one place."), ("calender", "Put every deadline from Damian’s task list into Google Calendar."),
        ("automation", "Make, change, pause or run a Wink automation."), ("agent", "Build or change an agent with its own card in Wink."),
        ("tasks", "Add and finish tasks on Wink’s list."), ("ponytail", "The simplest solution that works."), ("yoveo-video", "Plan and edit live-action and interview videos."),
    ].map { Skill(name: $0.0, about: $0.1, path: "/stand-in/\($0.0)/SKILL.md") }
    static let shared = Shared(instructions: "/stand-in/AGENTS.md",
        text: "# Damian’s defaults for agent harnesses\n\nHost instructions and permissions come first. His own requests override these defaults.\n\n## Communication\n\n- Always talk to Damian in plain English: everyday words and short sentences.\n- Keep replies short. Answer first, then only what he needs to act or decide.\n- Inspect before asking. Ask only when truly blocked.",
        skills: skills, servers: ["composio", "context-mode", "penpot", "whatsapp", "teams"])
    static let connections = [
        Connection(name: "composio", title: "Composio", about: "Gmail, Slack, Calendar, Monday and more", status: "connected"),
        Connection(name: "context-mode", title: "Context mode", about: "Keeps big output out of the chat", status: "connected"),
        Connection(name: "penpot", title: "Penpot", about: "Design files", status: "connected"),
        Connection(name: "whatsapp", title: "WhatsApp", about: "Read chats on this Mac", status: "connected"),
        Connection(name: "teams", title: "Teams", about: "School mail and classes", status: "sign-in"),
    ]
    static let limits: [String: [Limit]] = [
        "claude": [Limit(name: "5-hour limit", used: 0.41, resets: now + 3 * 3600), Limit(name: "Week", used: 0.61, resets: now + 4 * 86400)],
        "codex": [Limit(name: "Week", used: 0.22, resets: now + 5 * 86400)],
    ]
    static let versions = [
        HarnessVersion(harness: "claude", installed: "2.1.310", latest: "2.1.310", newer: false),
        HarnessVersion(harness: "codex", installed: "0.181.0", latest: "0.183.0", newer: true),
        HarnessVersion(harness: "antigravity", installed: "1.14.2"),
        HarnessVersion(harness: "hermes", installed: "0.9.1", newer: false),
    ]
    static let todos: [Todo] = {
        let day = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        var list = [
            Todo(id: "t1", text: "Launch film: Check the second cut for shots cropped too tight", due: day - 9 * 86400),
            Todo(id: "t2", text: "Leonie: Talk with her about the explainer video", due: day - 9 * 86400),
            Todo(id: "t3", text: "Sandra: Bring the second drive to the office", chat: "plain", due: day),
            Todo(id: "t4", text: "Julian: Get a birthday present", due: day + 5 * 86400),
            Todo(id: "t5", text: "Salt: Pay CHF 70", due: day + 8 * 86400),
            Todo(id: "t6", text: "Newsletter: Send the October issue", due: day + 10 * 86400),
        ]
        for n in 1...9 { list.append(Todo(id: "l\(n)", text: "Later task \(n)", due: day + Double(10 + n) * 86400)) }
        for n in 1...27 { list.append(Todo(id: "f\(n)", text: "Loose task \(n)")) }
        for n in 1...80 { list.append(Todo(id: "d\(n)", text: "Finished task \(n)", state: "done")) }
        return list
    }()
    static let jobs = [
        Job(id: "morning", title: "Tasks: morning", prompt: "Run the task routine.", folder: "~", agent: "claude", model: "claude-opus-5-5", time: "06:00", next: now + 12 * 3600),
        Job(id: "afternoon", title: "Tasks: afternoon", prompt: "Run the task routine.", folder: "~", agent: "claude", model: "claude-opus-5-5", time: "14:00", next: now + 8 * 3600),
        Job(id: "website", title: "Website check", prompt: "Check both pages.", folder: "~", agent: "claude", model: "claude-opus-5-5", time: "18:00", next: now + 10 * 3600),
        Job(id: "weekly", title: "Weekly reflection", prompt: "Read the week’s chats and write down what was learned. Ask before changing a rule.", folder: "~", agent: "claude", model: "claude-opus-5-5", time: "19:00", days: [1], enabled: false),
    ]
    static let agents: [Agent] = {
        var sniper = Agent(id: "deal", name: "Deal sniper", line: "A PS5 for 265 CHF. Set your maximum bid to 300.")
        sniper.needs = false
        sniper.checked = now - 180
        sniper.every = "Every 5 min"
        sniper.on = true
        return [sniper]
    }()
}
