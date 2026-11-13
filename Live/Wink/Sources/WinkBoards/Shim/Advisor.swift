import SwiftUI

// Board for the Fable advisor (13 Nov 2026). Damian: "always opus 5.5 on medium and fable as the advisor", "can you make its also
// correctly visible like in claude code how does claude code display this advisor thingy". Claude Code shows it as a step,
// "⏺ Advising using Fable 5.2" then "⎿ ✔ Advisor has reviewed the conversation and will apply the feedback"; the advice itself
// arrives encrypted, so nobody sees it. Built on branch advisor-display of wink2; this shim only shows how it looks.

private struct AdvisorStep: View {
    let running: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("⏺").foregroundStyle(running ? Theme.accent : .secondary)
                Text("Advising using Fable 5.2").foregroundStyle(.secondary)
                if running { WinkSpinner(size: 12, working: true) }
            }
            if !running {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("⎿").foregroundStyle(.secondary)
                    Text("✔ Advisor has reviewed the conversation and will apply the feedback").foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
            }
        }
        .font(.wink(.small))
    }
}

private struct AdvisorChat: View {
    var phone = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer(minLength: phone ? 40 : 120)
                Text("Plan the new Tasks page and build it")
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            }
            AdvisorStep(running: false)
            Text("I'll keep the list as it is and add the due-date groups the advisor pointed at: Today, This week, Later.")
            AdvisorStep(running: true)
            Spacer()
            HStack(spacing: 8) {
                SettingsChip(label: "Opus 5.5", logo: "agent-claude", detail: "advised by Fable", ring: 0.3)
                Spacer()
            }
            .padding(12)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.box, style: .continuous))
        }
        .font(.wink(.body))
    }
}

private struct AdvisorSettingsAndUsage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings › General › New Chats").font(.wink(.label)).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                WinkRow("Model", detail: "For every new chat") { SettingsChip(label: "Opus 5.5", logo: "agent-claude", chevron: true) }
                WinkRow("Level") { SettingsChip(label: "Medium", chevron: true) }
                WinkRow("Advisor", detail: "Asked at the hard moments") { SettingsChip(label: "Fable", chevron: true) }
            }
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            Text("Usage (pointer on the model chip)").font(.wink(.label)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                Text("Usage").font(.wink(.heading))
                UsageRow(label: "Context", share: 0.3, note: "300k of 1M tokens")
                UsageRow(label: "Advisor", share: nil, value: "39k", note: "Fable 5.2 · tokens, not in the context")
                UsageRow(label: "5-hour limit", share: 0.42, note: "Resets at 17:00")
            }
            .padding(16)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            Text("The advice comes back encrypted from Anthropic, so Wink, like Claude Code, shows that Fable was asked and when, never what it said.")
                .font(.wink(.small)).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct AdvisorBoard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mac · a chat").font(.wink(.label)).foregroundStyle(.secondary)
                AdvisorChat().padding(24).frame(width: 520, height: 600)
                    .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("iPhone · same chat").font(.wink(.label)).foregroundStyle(.secondary)
                AdvisorChat(phone: true).padding(16).frame(width: 320, height: 600)
                    .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.screen, style: .continuous))
            }
            AdvisorSettingsAndUsage().frame(width: 360, height: 640)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.tile)
    }
}
