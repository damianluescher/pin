import SwiftUI

// Board for Wink's Loops page (20 Nov 2026, Damian: "i like the new approval thing we have but we are still missing a place
// where we track those built loops and have an overview over them"). Next to Review in the side list. A loop is a workflow
// file in ~/.agents/workflows (stages, his gates, what done means); a run is one job going through it in a chat. One page:
// what runs now and where it stands, which loops exist, what finished lately, start a new run, pause or stop one.
// Design only. Only "Yoveo film" exists as a file today; the other three are examples of the loops he named.

private struct Loop {
    let name: String
    let stages: [String]
    let gates: Set<Int>
    let running: Int
    let done: Int
    let file: String?
}

private let loops: [Loop] = [
    Loop(name: "Yoveo film", stages: ["Select footage", "Rough cut", "Fixes", "Final cut", "Export"], gates: [1, 3, 4], running: 2, done: 3, file: "yoveo-film.md"),
    Loop(name: "LUT Cam release", stages: ["Plan", "Build", "Test on iPhone", "Store page", "Submit"], gates: [0, 3, 4], running: 1, done: 1, file: nil),
    Loop(name: "Content reel", stages: ["Idea", "Script", "Edit", "Post"], gates: [1, 3], running: 0, done: 4, file: nil),
    Loop(name: "App fix", stages: ["Find cause", "Fix", "Check", "Install"], gates: [3], running: 1, done: 9, file: nil),
]

private struct Run {
    let job: String
    let loop: Int
    let stage: Int
    let chat: String
    let since: String
    let waits: Bool
    var paused = false
}

private let runs: [Run] = [
    Run(job: "EHL portrait: Brankica", loop: 0, stage: 1, chat: "EHL Brankica", since: "2 h", waits: true),
    Run(job: "LUT Cam 1.0", loop: 1, stage: 2, chat: "LUT Cam", since: "1 d", waits: false),
    Run(job: "Wink: voice answers", loop: 3, stage: 3, chat: "Wink voice", since: "20 min", waits: false),
    Run(job: "EHL portrait: Ugo", loop: 0, stage: 0, chat: "EHL Ugo", since: "3 h", waits: false, paused: true),
]

private struct Finished { let job: String; let loop: String; let out: String; let notes: Int; let when: String }
private let finished: [Finished] = [
    Finished(job: "EHL portrait: Cindy", loop: "Yoveo film", out: "Cindy_final.mp4 · 2:41", notes: 1, when: "Tue"),
    Finished(job: "Wink: end the call", loop: "App fix", out: "Installed on Mac and iPhone", notes: 0, when: "Today"),
    Finished(job: "Reel: LUT Cam teaser", loop: "Content reel", out: "Posted on Instagram", notes: 2, when: "Mon"),
]

/// The stages as dots: done filled, now white, still to come grey; a ring under the stages that stop for him.
private struct StageDots: View {
    let loop: Loop
    var now: Int? = nil
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(loop.stages.indices), id: \.self) { index in
                let fill: Color = now.map { index < $0 ? Theme.accent : index == $0 ? .white : Theme.chip } ?? Theme.chip
                Circle().fill(fill).frame(width: 8, height: 8)
                    .padding(3)
                    .overlay { if loop.gates.contains(index) { Circle().stroke(Color.secondary.opacity(0.6), lineWidth: 1) } }
                    .help(loop.stages[index] + (loop.gates.contains(index) ? " · you look" : ""))
            }
        }
    }
}

private struct RunRow: View {
    let run: Run
    var compact = false
    var body: some View {
        let loop = loops[run.loop]
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(run.job).font(.wink(.label).weight(.semibold)).lineLimit(1)
                Spacer(minLength: 8)
                if run.waits {
                    Text("Waits on you").font(.wink(.small)).foregroundStyle(.black)
                        .padding(.horizontal, 10).frame(height: 24).background(Theme.amber, in: Capsule())
                } else if run.paused {
                    Text("Paused").font(.wink(.small)).foregroundStyle(.secondary)
                }
                if !compact { Image(systemName: "ellipsis").foregroundStyle(.secondary).frame(width: 24) }
            }
            HStack(spacing: 12) {
                StageDots(loop: loop, now: run.stage)
                Text(loop.stages[run.stage]).font(.wink(.small))
                Spacer(minLength: 0)
            }
            Text("\(loop.name) · \(run.chat) chat · since \(run.since)").font(.wink(.small)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.vertical, 12)
        .opacity(run.paused ? 0.6 : 1)
    }
}

private struct LoopCard: View {
    let loop: Loop
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(loop.name).font(.wink(.label).weight(.semibold))
                Spacer()
                Image(systemName: "play.fill").font(.wink(.small)).foregroundStyle(.secondary)
            }
            StageDots(loop: loop)
            Text(loop.stages.joined(separator: " · ")).font(.wink(.small)).foregroundStyle(.secondary).lineLimit(2)
            Text("\(loop.running) running · \(loop.done) done" + (loop.file.map { " · \($0)" } ?? " · example")).font(.wink(.small)).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

private struct FinishedRow: View {
    let item: Finished
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark").foregroundStyle(Theme.accent).frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.job).font(.wink(.label)).lineLimit(1)
                Text("\(item.loop) · \(item.out)").font(.wink(.small)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(item.notes == 0 ? "first try" : item.notes == 1 ? "1 redo" : "\(item.notes) redos").font(.wink(.small)).foregroundStyle(.secondary)
            Text(item.when).font(.wink(.small)).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

private struct Section<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.wink(.label).weight(.semibold)).foregroundStyle(.secondary).padding(.bottom, 4)
            content
        }
    }
}

/// The sheet behind "New run": which loop, what the job is, which chat does it.
private struct StartSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start a loop").font(.wink(.heading))
            VStack(alignment: .leading, spacing: 6) {
                Text("Loop").font(.wink(.small)).foregroundStyle(.secondary)
                HStack { Text("Yoveo film"); Spacer(); Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary) }
                    .padding(.horizontal, 12).frame(height: Theme.control).background(Theme.chip, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("The job").font(.wink(.small)).foregroundStyle(.secondary)
                Text("EHL portrait: Priya, footage on T9 OTHER").padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: Theme.control, alignment: .leading)
                    .background(Theme.chip, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Chat").font(.wink(.small)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text("New chat").padding(.horizontal, 12).frame(height: 28).background(Theme.chosen, in: Capsule())
                    Text("Pick a chat").padding(.horizontal, 12).frame(height: 28)
                }
                .font(.wink(.small))
            }
            StageDots(loop: loops[0], now: 0)
            Text("Stops for you at Rough cut, Final cut and Export.").font(.wink(.small)).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Text("Start").foregroundStyle(.black).padding(.horizontal, 18).frame(height: Theme.control).background(.white, in: Capsule())
            }
        }
        .font(.wink(.label))
        .padding(20)
        .frame(width: 340)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

/// The ⋯ on a running row.
private struct RunMenu: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach([("Open its chat", "bubble.left"), ("Open in Review", "checkmark.circle"), ("Pause", "pause"), ("Stop", "stop")], id: \.0) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.1).frame(width: 16).foregroundStyle(item.0 == "Stop" ? Theme.danger : .secondary)
                    Text(item.0).foregroundStyle(item.0 == "Stop" ? Theme.danger : .primary)
                    Spacer()
                }
                .padding(.horizontal, 12).frame(height: 32)
            }
        }
        .font(.wink(.label))
        .padding(.vertical, 6)
        .frame(width: 200)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
    }
}

struct LoopsBoard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mac · Loops (side list, under Review)").font(.wink(.label)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: Theme.Room.section) {
                    HStack(spacing: 8) {
                        Text("Loops").font(.wink(.title))
                        Spacer()
                        Text("New run").padding(.horizontal, 16).frame(height: Theme.control).background(Theme.chip, in: Capsule()).font(.wink(.label))
                    }
                    Section(title: "Running now") {
                        ForEach(Array(runs.enumerated()), id: \.offset) { index, run in
                            RunRow(run: run)
                            if index < runs.count - 1 { WinkLine() }
                        }
                    }
                    Section(title: "Loops") {
                        WinkFlow(spacing: 12) { ForEach(loops, id: \.name) { LoopCard(loop: $0) } }
                    }
                    Section(title: "Finished this week") {
                        ForEach(finished, id: \.job) { FinishedRow(item: $0) }
                    }
                }
                .padding(24)
                .frame(width: 640)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("iPhone · running and finished").font(.wink(.label)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Text("Loops").font(.wink(.title)); Spacer(); Image(systemName: "plus").foregroundStyle(.secondary) }
                    Section(title: "Running now") {
                        ForEach(Array(runs.prefix(3).enumerated()), id: \.offset) { index, run in
                            RunRow(run: run, compact: true)
                            if index < 2 { WinkLine() }
                        }
                    }
                    Section(title: "Finished this week") {
                        ForEach(finished.prefix(2), id: \.job) { FinishedRow(item: $0) }
                    }
                    Text("Loops: 4 · tap one to see its stages").font(.wink(.small)).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
                .frame(width: 340, height: 760)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.screen, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("New run").font(.wink(.label)).foregroundStyle(.secondary)
                StartSheet()
                Text("⋯ on a running job").font(.wink(.label)).foregroundStyle(.secondary).padding(.top, 20)
                RunMenu()
                Text("Dots: filled done, white now, grey to come. A ring is a stage that stops for you; “Waits on you” opens its card in Review.")
                    .font(.wink(.small)).foregroundStyle(.secondary).frame(width: 320, alignment: .leading).padding(.top, 20)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.tile)
    }
}
