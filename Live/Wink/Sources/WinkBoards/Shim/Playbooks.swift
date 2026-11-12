import SwiftUI

// Boards for a Playbooks page (12 Nov 2026). Damian after a reel retelling Anthropic's "don't build agents, build skills": "i think i
// wanna build wink around that because it comes from anthropic directly". His skills in ~/.agents/skills already are the playbooks;
// Wink did not show them. Design only: none of this is in wink2 until he says yes on the boards. Made-up data, Wink's own pieces.

struct PlayFix: Hashable {
    let day: String
    let what: String
    let his: String?
}

struct Play: Hashable {
    let name: String
    let title: String
    let purpose: String
    let used: String
    let usedBy: String
    let fixes: [PlayFix]
    var every: String? = nil
}

enum Plays {
    static let all: [Play] = [
        Play(name: "yoveo-video", title: "Edit a Yoveo film", purpose: "Plans and cuts interview films in Resolve, from story to chapter markers.",
             used: "2 h ago", usedBy: "EHL portrait: Brankica",
             fixes: [PlayFix(day: "12 Nov", what: "Show a film as a light 720p file with its full path", his: "it doesnt load on my end"),
                     PlayFix(day: "6 Nov", what: "Back up a timeline as .drt, never as a copy tab", his: "i edited the copy"),
                     PlayFix(day: "29 Oct", what: "Keep the full render for Vimeo in its own folder", his: nil)]),
        Play(name: "pin", title: "Design in Pin", purpose: "Every screen is real code on a board; it ships after his yes.",
             used: "20 min ago", usedBy: "Wink: waiting ring",
             fixes: [PlayFix(day: "3 Nov", what: "Check only what changed, with one small picture", his: "why are you testing every page this is insane")]),
        Play(name: "salto", title: "Salto journal", purpose: "Writes the German Lernjournal and checks the hours in Zeiterfassung.",
             used: "Yesterday", usedBy: "Salto: week 45",
             fixes: [PlayFix(day: "10 Nov", what: "Stop the stopwatch before typing times by hand", his: nil)]),
        Play(name: "watch-social-media-videos", title: "Watch a reel", purpose: "Downloads a reel or post, listens to it and says what it is about.",
             used: "40 min ago", usedBy: "mymind worker",
             fixes: [PlayFix(day: "12 Nov", what: "Look a save up in the ledger before watching it again", his: nil)]),
        Play(name: "tasks", title: "Keep the task list", purpose: "Adds what needs him, ticks what is done, never deletes.",
             used: "Today", usedBy: "Buddy",
             fixes: [PlayFix(day: "27 Oct", what: "Only what needs him directly goes on the list",
                             his: "if it doesnt need me directly it shouldnt be in the list")]),
        Play(name: "yoveo-subtitles", title: "Subtitles", purpose: "Makes and fixes subtitles with Happy Scribe and puts each language on its own track.",
             used: "4 days ago", usedBy: "SwissSkills portraits", fixes: []),
    ]

    static let runningAlone: [Play] = [
        Play(name: "deal-sniper", title: "Deal sniper", purpose: "Watches Tutti and Ricardo for a PS5 and an OLED TV. Never buys.",
             used: "Checked 3 min ago", usedBy: "", fixes: [], every: "every 10 min"),
        Play(name: "tasks", title: "Tasks: morning", purpose: "Reads mail and chats, updates the task list, writes Buddy's morning note.",
             used: "Today 06:00", usedBy: "", fixes: [], every: "every day 06:00"),
    ]
}

// MARK: The page

/// One playbook as a panel: what it is for, when it was last used, what was last fixed in it.
struct PlayCard: View {
    let play: Play
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: SkillWords.symbol).foregroundStyle(Theme.skill)
                Text(play.title).font(.wink(.heading)).lineLimit(1)
                Spacer(minLength: 8)
                if let every = play.every { WinkChip { Image(systemName: "clock"); Text(every) }.foregroundStyle(.secondary) }
            }
            Text(play.purpose).font(.wink(.label)).foregroundStyle(.secondary).lineLimit(compact ? 1 : 2)
            Spacer(minLength: 0)
            if let fix = play.fixes.first, !compact {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fixed \(fix.day): \(fix.what)").lineLimit(1)
                    if let his = fix.his { Text("“\(his)”").foregroundStyle(.secondary).lineLimit(1) }
                }
                .font(.wink(.small))
            }
            HStack(spacing: 6) {
                Text(play.every == nil ? "Used \(play.used)" : play.used)
                if !play.usedBy.isEmpty { Text("· \(play.usedBy)").foregroundStyle(.secondary) }
            }
            .font(.wink(.small)).lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: compact ? 0 : 160, alignment: .topLeading)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

/// The Playbooks page. `alone` adds the option where agents and automations show as playbooks that run by themselves.
struct PlaybooksPage: View {
    var alone = false
    var compact = false
    @State private var search = ""

    var body: some View {
        Page(title: "Playbooks") {
            WinkMenuIcon(name: "New playbook", icon: "plus")
        } content: {
            WinkSearch("Search playbooks", text: $search).padding(.bottom, 24)
            if alone {
                Text("Runs by itself").font(.wink(.label)).foregroundStyle(.secondary).padding(.bottom, 12)
                LazyVGrid(columns: WinkGrid.panels, alignment: .leading, spacing: 12) {
                    ForEach(Plays.runningAlone, id: \.title) { PlayCard(play: $0, compact: compact) }
                }
                .padding(.bottom, 40)
                Text("Used by chats").font(.wink(.label)).foregroundStyle(.secondary).padding(.bottom, 12)
            }
            LazyVGrid(columns: compact ? [GridItem(.flexible())] : WinkGrid.panels, alignment: .leading, spacing: 12) {
                ForEach(Plays.all, id: \.name) { PlayCard(play: $0, compact: compact) }
            }
        }
    }
}

/// One playbook open: what it is for, the chats that used it, every fix with his words and an Undo.
struct PlaybookOpen: View {
    let play: Play
    var compact = false

    var body: some View {
        Page(title: play.title) {
            WinkChip { Image(systemName: "wrench.adjustable"); Text("Fix it") }
            if !compact { WinkMenuIcon(name: "Open the file", icon: "doc.text") }
        } content: {
            Text(play.purpose).font(.wink(.body)).padding(.bottom, 8)
            Text("Skill \(play.name)").font(.wink(.small)).foregroundStyle(.secondary).padding(.bottom, 40)
            Text("Fixes").font(.wink(.label)).foregroundStyle(.secondary).padding(.bottom, 12)
            ForEach(play.fixes.prefix(compact ? 3 : 10), id: \.what) { fix in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(fix.day).font(.wink(.small)).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fix.what)
                        if let his = fix.his { Text("You: “\(his)”").font(.wink(.small)).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 8)
                    Text("Undo").font(.wink(.small)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                WinkLine()
            }
            Text("Used by").font(.wink(.label)).foregroundStyle(.secondary).padding(.top, 40).padding(.bottom, 12)
            ForEach(["\(play.usedBy) · \(play.used)", "EHL portrait: Ugo · 3 days ago", "Lissabon reel · last week"], id: \.self) { line in
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left").foregroundStyle(.secondary).winkIconSlot()
                    Text(line).lineLimit(1)
                }
                .font(.wink(.label))
                .frame(height: Theme.menuRow)
            }
        }
    }
}

// MARK: The Mac window around a page

/// The settings window over the chat with Playbooks as a tab under Agents, as PagesWindow draws it.
struct PlayWindow<Content: View>: View {
    @ViewBuilder var content: Content
    private let tabs = [("Tasks", "checklist"), ("Automations", "clock"), ("Agents", "dot.radiowaves.left.and.right"), ("Playbooks", SkillWords.symbol),
                        ("General", "gearshape"), ("Instructions", "text.book.closed"), ("Harnesses", "cpu"), ("Data", "archivebox")]

    var body: some View {
        ZStack {
            Root().opacity(0.5)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(tabs, id: \.0) { tab in
                        if tab.0 == "General" { WinkLine().padding(.vertical, 8) }
                        HStack(spacing: 12) {
                            Image(systemName: tab.1).foregroundStyle(.secondary).winkIconSlot()
                            Text(tab.0)
                            Spacer(minLength: 0)
                        }
                        .font(.wink(.label))
                        .padding(.horizontal, 12)
                        .frame(height: Theme.menuRow)
                        .background(tab.0 == "Playbooks" ? Theme.chosen : .clear, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
                    }
                    Spacer()
                }
                .padding(.top, Theme.Room.head + (Theme.bar - Theme.menuRow) / 2).padding(.horizontal, 12)
                .frame(width: Theme.Window.tabs)
                .background(Theme.sidebar)
                content.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.canvas).environment(\.winkInWindow, true)
            }
            .frame(width: Theme.Window.width + 160, height: Theme.Window.height + 120)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.screen, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 40, y: 12)
        }
    }
}

// MARK: Fix the playbook, from a chat

/// A chat where he corrected the work: under the answer, "Fix the playbook" with the skill and the lesson already filled in.
struct FixFromChat: View {
    var body: some View {
        HStack(spacing: 0) {
            Sidebar().frame(width: Theme.side).background(Theme.tile)
            VStack(alignment: .leading, spacing: 24) {
                TopBar(title: "Wink: waiting ring") { EmptyView() }
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer(minLength: 120)
                        Text("why are you testing every page this is insane, just check what you changed")
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                    }
                    Text("You're right. I checked the one board that changed: the grey ring shows on Brand colours, green on Launch film.")
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.adjustable").foregroundStyle(Theme.skill)
                            Text("Fix the playbook").font(.wink(.heading))
                        }
                        HStack(spacing: 8) {
                            Text("Playbook").foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                            WinkChip { Image(systemName: SkillWords.symbol).foregroundStyle(Theme.skill); Text("Design in Pin"); Image(systemName: "chevron.down") }
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Lesson").foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                            Text("After a change, check only what changed, with one small picture. Never every page.")
                        }
                        Text("Your words go in with it. A backup is made first; you can undo it on the Playbooks page.")
                            .font(.wink(.small)).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Spacer()
                            Text("Not now").foregroundStyle(.secondary).padding(.horizontal, 16).frame(height: Theme.control)
                            Text("Fix it").foregroundStyle(.black).padding(.horizontal, 16).frame(height: Theme.control)
                                .background(.white, in: Capsule())
                        }
                    }
                    .font(.wink(.label))
                    .padding(16)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").foregroundStyle(Theme.skill)
                        Text("Earlier in this chat: fixed Edit a Yoveo film, “show a film as a light 720p file”.")
                        Text("Undo").foregroundStyle(.secondary)
                    }
                    .font(.wink(.small))
                }
                .winkColumn()
                Spacer()
            }
            .background(Theme.canvas)
        }
    }
}

// MARK: A new playbook starts with the interview

struct NewPlaybookInterview: View {
    var body: some View {
        HStack(spacing: 0) {
            Sidebar().frame(width: Theme.side).background(Theme.tile)
            VStack(alignment: .leading, spacing: 24) {
                TopBar(title: "New playbook") { EmptyView() }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: SkillWords.symbol).foregroundStyle(Theme.skill)
                        Text("Interview, then the playbook").font(.wink(.label)).foregroundStyle(.secondary)
                    }
                    Text("Let's write it once so it's never explained twice. A few questions, one at a time.")
                    Text("1. What's the job, in one sentence?").font(.wink(.heading))
                    Text("Then I'll ask what done looks like, what went wrong last time, and which tools it may use. When we're through, I write the playbook, show it to you, and it appears on the Playbooks page.")
                        .foregroundStyle(.secondary)
                }
                .winkColumn()
                Spacer()
                Text("Ask anything").foregroundStyle(.secondary).padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.box, style: .continuous))
                    .winkColumn().padding(.bottom, Theme.Room.foot)
            }
            .background(Theme.canvas)
        }
    }
}

// MARK: The brief: what to decide

struct PlaybooksBrief: View {
    private let items: [(String, String, String)] = [
        ("1. The word you see", "Playbooks, or Skills?",
         "My pick: Playbooks on screen, as you said after the reel. The files stay skills, so nothing else changes."),
        ("2. The Agents page", "A: keep it, each agent names the playbook it runs on.  B: fold Agents and Automations into Playbooks under “Runs by itself” (board B).",
         "My pick: B. The reel's point is few agents, many playbooks: an agent is a playbook with a schedule. One page less."),
        ("3. On the iPhone", "How much of a playbook to show.",
         "My pick: what it's for, the last 3 fixes with your words and Undo, and when it was used. Never the whole text; Open the file stays on the Mac."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Playbooks: 3 things to decide").font(.wink(.title))
            Text("Each playbook is one of your skills. The page shows what it's for, when it was last used, and what was last fixed in it and why. From any chat: “fix the playbook”. A new one starts with the interview.")
                .foregroundStyle(.secondary)
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.0).font(.wink(.heading))
                    Text(item.1)
                    Text(item.2).foregroundStyle(.secondary)
                }
            }
            Text("Where the facts come from: last used = the chats that loaded the skill (Wink's own log); last fixed = the backups and the task-observer notes, with your words when they were written down.")
                .font(.wink(.small)).foregroundStyle(.secondary)
            Spacer()
        }
        .font(.wink(.body))
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.canvas)
    }
}
