import SwiftUI

// Board for Wink's voice mode (19 Nov 2026). Damian: "a mode like inside of chat gpt i press a button and then i talk to you
// directly and i can leave it on if i want to or click away". ChatGPT's behaviour in Wink's look: a voice button in the message
// box, a calm voice view with Buddy's face (listening, thinking, speaking), Mute and End, turns hands-free, interrupt by talking,
// the transcript lands in the chat, keeps going in the background, Buddy speaks up when something needs him. Local and free.
// Design only: nothing of it is in wink2 yet.

private enum VoiceState: String { case listening = "Listening", thinking = "Thinking", speaking = "Speaking" }

/// Buddy's face with soft rings that show the state: rings move with his voice while listening, a slow pulse while thinking,
/// rings move with Buddy's voice while speaking.
private struct VoiceFace: View {
    let state: VoiceState
    var size: CGFloat = 120
    var body: some View {
        ZStack {
            ForEach(0..<3) { ring in
                Circle()
                    .stroke(state == .thinking ? Color.white.opacity(0.08) : Theme.accent.opacity(0.18 - Double(ring) * 0.05), lineWidth: 2)
                    .frame(width: size * (1.25 + CGFloat(ring) * (state == .thinking ? 0.12 : 0.22)))
            }
            Circle().fill(Theme.raised).frame(width: size, height: size)
            BuddyFace(size: size * 0.6, working: state == .thinking)
        }
        .frame(width: size * 2, height: size * 2)
    }
}

private struct VoiceButtons: View {
    var muted = false
    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
                .frame(width: 56, height: 56)
                .background(muted ? Color.white : Theme.raised, in: Circle())
                .foregroundStyle(muted ? Color.black : Color.white)
            Image(systemName: "xmark")
                .frame(width: 56, height: 56)
                .background(Theme.danger, in: Circle())
                .foregroundStyle(.white)
        }
        .font(.wink(.heading))
    }
}

/// The voice view inside a chat, one state.
private struct VoiceView: View {
    let state: VoiceState
    var caption: String
    var phone = false
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            VoiceFace(state: state, size: phone ? 96 : 120)
            Text(state.rawValue).font(.wink(.label)).foregroundStyle(.secondary)
            Text(caption).font(.wink(.body)).multilineTextAlignment(.center).frame(maxWidth: phone ? 280 : 420).lineLimit(3)
            Spacer()
            VoiceButtons()
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas)
    }
}

/// The message box with the new voice button beside the mic.
private struct BoxWithVoice: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus").foregroundStyle(.secondary)
            SettingsChip(label: "Opus 5.5", logo: "agent-claude")
            Spacer()
            Image(systemName: "mic").foregroundStyle(.secondary)
            Image(systemName: "waveform")
                .frame(width: 32, height: 32)
                .background(.white, in: Circle())
                .foregroundStyle(.black)
        }
        .font(.wink(.body))
        .padding(12)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.box, style: .continuous))
    }
}

/// The chat after a voice talk: every turn as messages, his marked with a small mic, and a spoken speak-up from Buddy.
private struct VoiceTranscript: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer(minLength: 60)
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill").font(.wink(.small)).foregroundStyle(.secondary)
                    Text("What's still open from today?")
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            }
            Text("Two things: the LUT Cam film is rendered and waits for your look, and Patrick asked about the invoice.")
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(Theme.accent)
                Text("Buddy spoke up · 21:14").foregroundStyle(.secondary)
            }
            .font(.wink(.small))
            Text("Damian, the mymind sort just finished. Want me to read you the three best saves?")
            Spacer()
            BoxWithVoice()
        }
        .font(.wink(.body))
    }
}

struct VoiceModeBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 24) {
                column("1 · The button: tap the waveform in the message box") {
                    VStack { Spacer(); BoxWithVoice() }.padding(20)
                }
                column("2 · Listening: rings move with your voice") {
                    VoiceView(state: .listening, caption: "What's still open from today?")
                }
                column("3 · Thinking") {
                    VoiceView(state: .thinking, caption: "")
                }
                column("4 · Speaking: talk to interrupt") {
                    VoiceView(state: .speaking, caption: "Two things: the LUT Cam film waits for your look, and Patrick asked about the invoice.")
                }
            }
            HStack(alignment: .top, spacing: 24) {
                column("5 · After: the talk is in the chat; Buddy spoke up by itself") {
                    VoiceTranscript().padding(20)
                }
                column("6 · iPhone, switched to another app", width: 260) {
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Circle().fill(Theme.accent).frame(width: 8, height: 8)
                            Text("Buddy · listening").font(.wink(.small))
                            Spacer()
                            Text("12:04").font(.wink(.small)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16).frame(height: 36)
                        .background(Color.black, in: Capsule())
                        .padding(.top, 12)
                        Text("Another app").font(.wink(.label)).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
                column("7 · iPhone, voice mode", width: 260) {
                    VoiceView(state: .listening, caption: "Is the EHL export done?", phone: true)
                }
                column("8 · Mac, switched away: a small pill stays", width: 300) {
                    VStack {
                        HStack(spacing: 8) {
                            BuddyFace(size: 20, working: false)
                            Text("Buddy is listening").font(.wink(.small))
                            Image(systemName: "mic.fill").font(.wink(.small)).foregroundStyle(.secondary)
                            Image(systemName: "xmark").font(.wink(.small)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(Theme.raised, in: Capsule())
                        Spacer()
                    }
                    .padding(20)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.tile)
    }

    private func column<Content: View>(_ title: String, width: CGFloat = 360, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.wink(.label)).foregroundStyle(.secondary).lineLimit(2).frame(width: width, alignment: .leading)
            content()
                .frame(width: width, height: 420)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
        }
    }
}
