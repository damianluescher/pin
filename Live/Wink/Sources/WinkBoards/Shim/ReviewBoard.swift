import SwiftUI

// Board for Wink's Review page (19 Nov 2026; research ~/Documents/Research/review-not-prompt.md, sections 1, 3, 5). Every gate
// lands in one list: a plan before a big job, a result, anything going out, and a run that failed or stalled. One card per item
// with the thing itself and four fixed buttons, Approve / Edit / Note / Skip (LangChain Agent Inbox); one answer per item; a redo
// only from his note. Each kind of job has a small workflow file with its stages and what "done" means (OpenAI Symphony);
// Approve moves the job to its next stage by itself (Orkas auto-advance). His notes are kept with the skill the run used, so the
// skill gets better (Harness² idea). Design only.

private enum Gate: String { case plan = "Plan", result = "Result", out = "Goes out", stuck = "Stopped" }

private struct ReviewItem {
    let gate: Gate
    let job: String
    let stage: String
    let what: String
    let proof: Proof
    let age: String
    enum Proof { case video(String), board, draft(String), diff, reason(String), steps([String]) }
}

private let items: [ReviewItem] = [
    ReviewItem(gate: .result, job: "EHL portrait: Brankica", stage: "Rough cut", what: "Rough cut v3, 2:14, chapters set", proof: .video("Brankica_v3.mp4 · 2:14"), age: "2 h"),
    ReviewItem(gate: .plan, job: "LUT Cam launch reel", stage: "Plan", what: "Plan: 5 shots, 20 s, music with a drop at 0:08",
               proof: .steps(["Hook: the phone screen flips to the grade", "Three before/after shots", "Price and App Store badge"]), age: "1 h"),
    ReviewItem(gate: .out, job: "Invoice for Patrick", stage: "Send", what: "Mail to Patrick (Ella Ciao), from damian@yoveo.ch",
               proof: .draft("Hoi Patrick, anbei die Rechnung für Fokus Empathie. Liebe Grüsse, Damian"), age: "40 min"),
    ReviewItem(gate: .result, job: "Wink: waiting ring", stage: "Board", what: "Pin board: grey ring for a chat waiting on its job", proof: .board, age: "25 min"),
    ReviewItem(gate: .stuck, job: "mymind sprint: AI video", stage: "Download", what: "Stopped: Instagram refused downloads twice",
               proof: .reason("29 reels left. Try again tomorrow, or skip this topic."), age: "10 min"),
]

/// The four fixed answers. One answer per item; after it the card shows what happened.
private struct Answers: View {
    var compact = false
    var body: some View {
        HStack(spacing: 8) {
            Text("Approve").foregroundStyle(.black).padding(.horizontal, 16).frame(height: Theme.control).background(.white, in: Capsule())
            ForEach(["Edit", "Note", "Skip"], id: \.self) { word in
                Text(word).padding(.horizontal, compact ? 12 : 16).frame(height: Theme.control).background(Theme.chip, in: Capsule())
            }
        }
        .font(.wink(.label))
    }
}

private struct Proof: View {
    let proof: ReviewItem.Proof
    var body: some View {
        switch proof {
        case .video(let name):
            ZStack {
                LinearGradient(colors: [Color(white: 0.25), Color(white: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "play.fill").font(.wink(.title))
                VStack { Spacer(); HStack { Text(name).font(.wink(.small)); Spacer() }.padding(8) }
            }
            .frame(height: 120).clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        case .board:
            HStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle").foregroundStyle(.secondary)
                Text("Pin · Wink · Start & sidebar · 1 board").font(.wink(.small))
                Spacer()
                Text("Open").font(.wink(.small)).foregroundStyle(.secondary)
            }
            .padding(12).background(Theme.chip, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        case .draft(let text):
            Text(text).font(.wink(.label)).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.chip, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        case .diff:
            EmptyView()
        case .reason(let text):
            Text(text).font(.wink(.label)).foregroundStyle(.secondary)
        case .steps(let steps):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in Text("\(index + 1). \(step)").font(.wink(.label)) }
            }
        }
    }
}

private struct ReviewCard: View {
    let item: ReviewItem
    var compact = false
    var noted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(item.gate.rawValue).font(.wink(.small).weight(.semibold))
                    .foregroundStyle(item.gate == .stuck ? Theme.amber : item.gate == .out ? Theme.accent : .secondary)
                Text("· \(item.job) · \(item.stage)").font(.wink(.small)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text(item.age).font(.wink(.small)).foregroundStyle(.secondary)
            }
            Text(item.what).font(.wink(.heading)).lineLimit(2)
            Proof(proof: item.proof)
            if noted {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cut the intro to 10 s and keep the drone shot.")
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.chip, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    Text("Goes back once with your note. Also kept for the skill Edit a Yoveo film.").font(.wink(.small)).foregroundStyle(.secondary)
                }
            }
            Answers(compact: compact)
        }
        .padding(16)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

/// What a card says after the answer: Approve moves the job on by itself.
private struct Answered: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                Text("Approved · EHL portrait: Brankica")
            }
            Text("Next stage started by itself: Fixes → Review → Export").foregroundStyle(.secondary)
        }
        .font(.wink(.label))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.raised.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

/// The small workflow file of one kind of job, as the page shows it.
private struct WorkflowPanel: View {
    private let stages = ["Select footage", "Rough cut", "Review", "Fixes", "Review", "Export"]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workflow · Yoveo film").font(.wink(.heading))
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                HStack(spacing: 8) {
                    Circle().fill(index < 2 ? Theme.accent : index == 2 ? Color.white : Theme.chip).frame(width: 8, height: 8)
                    Text(stage).font(.wink(.label)).foregroundStyle(index == 2 ? .primary : .secondary)
                    if stage == "Review" { Text("you").font(.wink(.small)).foregroundStyle(.secondary) }
                }
            }
            WinkLine()
            Text("Done: a 2–3 min film, chapters set, voice normalised, a 720p review file.").font(.wink(.small)).foregroundStyle(.secondary)
            Text("Skill: Edit a Yoveo film · file: workflows/yoveo-film.md").font(.wink(.small)).foregroundStyle(.secondary)
            Text("Limits: 20 turns, 5 min without output, then it lands here as Stopped.").font(.wink(.small)).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

struct ReviewPageBoard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mac · Review (in the side list under Tasks, with a count)").font(.wink(.label)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Review").font(.wink(.title))
                        Text("5").font(.wink(.label)).foregroundStyle(.secondary)
                        Spacer()
                        ForEach(["All", "Plans", "Results", "Going out", "Stopped"], id: \.self) { chip in
                            Text(chip).font(.wink(.small)).padding(.horizontal, 12).frame(height: 28)
                                .background(chip == "All" ? Theme.chosen : .clear, in: Capsule())
                        }
                    }
                    Text("Oldest first. One answer per card.").font(.wink(.small)).foregroundStyle(.secondary)
                    ReviewCard(item: items[0], noted: true)
                    ReviewCard(item: items[1])
                    ReviewCard(item: items[2])
                    Answered()
                }
                .padding(24)
                .frame(width: 640)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("iPhone · same list").font(.wink(.label)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Review").font(.wink(.title))
                    ReviewCard(item: items[3], compact: true)
                    ReviewCard(item: items[4], compact: true)
                    Spacer()
                }
                .padding(16)
                .frame(width: 340, height: 760)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.screen, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("A job's stages and what done means").font(.wink(.label)).foregroundStyle(.secondary)
                WorkflowPanel().frame(width: 320)
                Text("Task page: a task can be “Ready for review”; Needs You and the send cards fold into this one list.")
                    .font(.wink(.small)).foregroundStyle(.secondary).frame(width: 320, alignment: .leading)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.tile)
    }
}
