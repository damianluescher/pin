import SwiftUI

// Board "New · Smoother Wink · ideas from Gemini" (20 Nov 2026, Damian: "redesign some elements inside of Wink because it
// doesn't feel convenient ... one reference would be Gemini directly ... especially animations"). Research: the Gemini app's
// May 2026 redesign (9to5Google, Android Authority, design.google "Gemini AI visual design"): a calm pill message box with
// only + / mic / Live, tools and recent pictures in one + sheet, a glow instead of a spinner that swells on send ("a sense of
// anticipation, then release"), voice inside the chat with a level-reactive pill, thinking steps out of the way. Wink keeps
// its own greys, words and pieces; only the behaviour is taken. Each row: what Wink does now, and the change running live.
// Design only.

private struct Idea {
    let n: Int
    let title: String
    let now: String
    let after: String
    let motion: String
}

private let ideas: [Idea] = [
    Idea(n: 1, title: "Answers flow in", now: "A whole answer appears at once when Claude finishes a block.",
         after: "Words fade in line by line at reading pace while it writes; the view follows gently.",
         motion: "Each word 0 → 1 opacity and 4 pt up, 30 ms apart, 0.25 s ease-out. Engine: Claude's partial messages."),
    Idea(n: 2, title: "Sending lifts", now: "The box empties and your message pops into the chat.",
         after: "Your words rise out of the box into their bubble; the box shrinks back to one line.",
         motion: "Matched move, spring 0.35 s; a light tap on iPhone."),
    Idea(n: 3, title: "A calm glow while it works", now: "A shimmering word (Working…) under the last message.",
         after: "The shimmer word stays; a soft grey glow breathes behind the box, stronger the moment you send, fading when done.",
         motion: "Swells to full in 0.4 s on send, breathes 2.4 s, fades 0.6 s at the end. Wink greys, no colours."),
    Idea(n: 4, title: "One button that knows", now: "Mic and Send side by side; Stop elsewhere; voice only in Buddy.",
         after: "Empty: mic + voice. Typing: Send morphs in. Working: Stop. In every chat.",
         motion: "Cross-scale 0.85 → 1 with fade, 0.15 s."),
    Idea(n: 5, title: "+ opens everything", now: "+ lists files; tools and skills live in other menus.",
         after: "One sheet: your recent pictures and files in a row on top (one tap to attach), then tools with one line each.",
         motion: "Sheet rises 0.25 s; the attached file flies into the box."),
    Idea(n: 6, title: "Voice grows out of the box", now: "The voice bar replaces the box in one jump.",
         after: "The box morphs into the voice pill; a glow above it follows your voice; captions in the chat.",
         motion: "Box → pill 0.3 s spring; glow height = mic level, 60 fps."),
    Idea(n: 7, title: "Things answer your touch", now: "Most buttons change colour only.",
         after: "Every button presses in a little; chats slide in from the side list instead of swapping.",
         motion: "Press 0.96 scale, 0.1 s; chat switch 12 pt slide + fade, 0.2 s; selection tap on iPhone."),
]

/// A loop clock for the live examples: 0...1 over `period` seconds.
private struct Loop<Content: View>: View {
    var period: Double = 3
    @ViewBuilder var content: (Double) -> Content
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
            content(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period)
        }
    }
}

private let sample = "The rough cut is ready. I kept the drone shot as the opener and trimmed the intro to ten seconds."

private struct FlowingText: View {
    var body: some View {
        Loop(period: 5) { t in
            let words = sample.split(separator: " ").map(String.init)
            let shown = Double(words.count) * min(t / 0.7, 1)
            WinkFlow(spacing: 4) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let k = max(0, min(1, shown - Double(index)))
                    Text(word).opacity(k).offset(y: (1 - k) * 4)
                }
            }
            .font(.wink(.label))
        }
    }
}

private struct BoxPill: View {
    var text = ""
    var height: CGFloat = Theme.control + 8
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus").foregroundStyle(.secondary)
            Text(text.isEmpty ? "Ask anything" : text).foregroundStyle(text.isEmpty ? .secondary : .primary).lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.wink(.label))
        .padding(.horizontal, 14).frame(height: height)
        .background(Theme.raised, in: Capsule())
    }
}

private struct Lift: View {
    var body: some View {
        Loop(period: 3) { t in
            let k = max(0, min(1, (t - 0.25) / 0.25))
            let eased = 1 - pow(1 - k, 3)
            ZStack(alignment: .bottom) {
                Text("Make the intro shorter").font(.wink(.label))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.chip, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: -60 * eased)
                    .opacity(t < 0.25 ? 0 : 1)
                BoxPill(text: t < 0.25 ? "Make the intro shorter" : "")
            }
            .frame(height: 110, alignment: .bottom)
        }
    }
}

private struct Glow: View {
    var body: some View {
        Loop(period: 5) { t in
            // Swell on send (0–0.08), breathe while it works, fade at the end (0.8–1).
            let swell = min(t / 0.08, 1)
            let breathe = 0.75 + 0.25 * sin(t * .pi * 2 * 2)
            let fade = t > 0.8 ? max(0, 1 - (t - 0.8) / 0.12) : 1
            let k = swell * breathe * fade
            ZStack(alignment: .bottom) {
                Ellipse().fill(Color.white.opacity(0.16 * k)).frame(height: 90).blur(radius: 30).offset(y: 20)
                VStack(alignment: .leading, spacing: 10) {
                    Text(t < 0.8 ? "Working…" : "Worked for 12 s").font(.wink(.small)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    BoxPill()
                }
            }
            .frame(height: 110, alignment: .bottom)
        }
    }
}

private struct SmartButton: View {
    var body: some View {
        Loop(period: 6) { t in
            let state = t < 0.33 ? 0 : t < 0.66 ? 1 : 2
            HStack(spacing: 8) {
                BoxPill(text: state == 1 ? "Make it shorter" : "")
                ZStack {
                    HStack(spacing: 6) {
                        Image(systemName: "mic").frame(width: 32, height: 32)
                        Image(systemName: "waveform").frame(width: 32, height: 32).background(Theme.chip, in: Circle())
                    }
                    .opacity(state == 0 ? 1 : 0).scaleEffect(state == 0 ? 1 : 0.85)
                    Image(systemName: "arrow.up").foregroundStyle(.black).frame(width: 32, height: 32).background(.white, in: Circle())
                        .opacity(state == 1 ? 1 : 0).scaleEffect(state == 1 ? 1 : 0.85)
                    Image(systemName: "stop.fill").frame(width: 32, height: 32).background(Theme.chip, in: Circle())
                        .opacity(state == 2 ? 1 : 0).scaleEffect(state == 2 ? 1 : 0.85)
                }
                .frame(width: 70)
                .animation(.snappy(duration: 0.15), value: state)
            }
            .font(.wink(.label))
            .frame(height: 110)
        }
    }
}

private struct PlusSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [Color(white: 0.3 - Double(index) * 0.04), Color(white: 0.16)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 48, height: 48)
                }
                Text("Files…").font(.wink(.small)).foregroundStyle(.secondary)
            }
            ForEach([("Skill", "Use one of your skills"), ("Research", "Look it up properly"), ("Pin board", "Design it first")], id: \.0) { tool in
                HStack(spacing: 8) { Text(tool.0).font(.wink(.label)); Text(tool.1).font(.wink(.small)).foregroundStyle(.secondary) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

private struct VoiceGrow: View {
    var body: some View {
        Loop(period: 4) { t in
            let k = max(0, min(1, (t - 0.15) / 0.12))
            let level = t > 0.3 ? 0.35 + 0.35 * abs(sin(t * 40)) * abs(sin(t * 7)) : 0
            ZStack(alignment: .bottom) {
                Ellipse().fill(Color.white.opacity(0.18 * k)).frame(width: 200, height: 30 + 70 * level).blur(radius: 24).offset(y: 10)
                ZStack {
                    BoxPill().opacity(1 - k)
                    HStack(spacing: 10) {
                        BuddyFace(size: 18, working: false)
                        Text("Listening").font(.wink(.small)).foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "mic.fill").font(.wink(.small))
                        Image(systemName: "xmark").font(.wink(.small)).foregroundStyle(.white)
                            .frame(width: 26, height: 26).background(Theme.danger, in: Circle())
                    }
                    .padding(.horizontal, 12).frame(height: Theme.control + 8)
                    .background(Theme.raised, in: Capsule())
                    .frame(width: 180 + 140 * k)
                    .opacity(k)
                }
            }
            .frame(height: 110, alignment: .bottom)
        }
    }
}

private struct Press: View {
    var body: some View {
        Loop(period: 2) { t in
            let down = t > 0.4 && t < 0.5
            HStack(spacing: 16) {
                Text("Approve").foregroundStyle(.black).padding(.horizontal, 16).frame(height: Theme.control)
                    .background(.white, in: Capsule())
                    .scaleEffect(down ? 0.96 : 1)
                    .animation(.snappy(duration: 0.1), value: down)
                Text("tap").font(.wink(.small)).foregroundStyle(.secondary).opacity(down ? 1 : 0.3)
            }
            .font(.wink(.label))
            .frame(height: 110)
        }
    }
}

private struct Example: View {
    let n: Int
    var body: some View {
        switch n {
        case 1: FlowingText().frame(height: 110, alignment: .top)
        case 2: Lift()
        case 3: Glow()
        case 4: SmartButton()
        case 5: PlusSheet()
        case 6: VoiceGrow()
        default: Press()
        }
    }
}

private struct IdeaRow: View {
    let idea: Idea
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(idea.n). \(idea.title)").font(.wink(.heading))
                Text("Now: " + idea.now).font(.wink(.small)).foregroundStyle(.secondary)
                Text("After: " + idea.after).font(.wink(.label))
                Text(idea.motion).font(.wink(.small)).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 420, alignment: .leading)
            Example(n: idea.n)
                .padding(16)
                .frame(width: 400, alignment: .bottomLeading)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
        }
        .padding(20)
        .background(Theme.raised.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

struct SmoothIdeasBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smoother Wink · seven changes, ideas from the Gemini app").font(.wink(.title))
            Text("Wink's own look and words; only how it moves and how many taps it takes. The right side of each row runs live.")
                .font(.wink(.label)).foregroundStyle(.secondary)
            ForEach(ideas, id: \.n) { IdeaRow(idea: $0) }
            Text("Not taken: Gemini's colour gradients, its model picker at the top, removing words from buttons. Mac and iPhone get the same motion; iPhone adds light taps.")
                .font(.wink(.small)).foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.tile)
    }
}
