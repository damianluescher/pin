import SwiftUI

// Two options for a new side menu (20 Nov 2026, Damian in voice mode: "the left menu is just a bit too cluttered ... remove
// some elements ... more separation in between ... update the Wink to Buddy and have it on the top left instead of below.
// Overall the whole menu needs a whole new redesign"). Both: Buddy is the first thing at the top left (bean, name, its
// latest line), the Buddy card at the foot and the wordmark go, fewer pieces, more room between groups, the black design
// with one Wink-green accent. Words stay (no icon-only rows). Design only.

private struct SMChat: Identifiable {
    let id = UUID()
    let name: String
    var working = false
    var news = false
    var pinned = false
    var open = false
}

private let smChats: [SMChat] = [
    SMChat(name: "Portfolio", pinned: true),
    SMChat(name: "New York", pinned: true),
    SMChat(name: "Money", pinned: true),
    SMChat(name: "Wink", working: true),
    SMChat(name: "Plan: our own mymind inside Wink", news: true, open: true),
    SMChat(name: "LUT Cam: contrast (auto switch)", news: true),
    SMChat(name: "Tasks: afternoon"),
    SMChat(name: "Projects: one list to keep track"),
    SMChat(name: "BBZ English: Juxtaposition"),
]

private struct SMMark: View {
    let chat: SMChat
    var body: some View {
        if chat.working { WinkSpinner(size: 12) }
        else if chat.news { Circle().fill(Theme.accent).frame(width: 7, height: 7) }
    }
}

private struct SMRow: View {
    let chat: SMChat
    var body: some View {
        HStack(spacing: 10) {
            Text(chat.name).lineLimit(1)
            Spacer(minLength: 8)
            SMMark(chat: chat)
        }
        .font(.wink(.label))
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(chat.open ? Theme.chosen : .clear, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
    }
}

/// The new head: Buddy instead of the wordmark. The bean, "Buddy", its latest line; the fold button at the right.
private struct SMBuddyHead: View {
    var compact = false
    var body: some View {
        HStack(spacing: 12) {
            BuddyFace(size: compact ? 30 : 36, working: false)
                .overlay(alignment: .topTrailing) { Circle().fill(Theme.accent).frame(width: 8, height: 8).offset(x: 1, y: -1) }
            VStack(alignment: .leading, spacing: 2) {
                Text("Buddy").font(.wink(.heading))
                Text("Got it, I'll check your mail").font(.wink(.small)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "sidebar.left").font(.wink(.label)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
    }
}

private struct SMSection: View {
    let title: String
    var body: some View {
        Text(title).font(.wink(.small).weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.bottom, 6)
    }
}

private struct SMProfile: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("D").font(.wink(.small).weight(.semibold)).frame(width: 28, height: 28).winkEdge(14)
            Text("Damian").font(.wink(.label))
            Spacer()
            Image(systemName: "gearshape").foregroundStyle(.secondary)
        }
        .font(.wink(.label))
        .padding(.horizontal, 12)
    }
}

// MARK: Option A: one quiet column

/// A: Buddy at the top, then New chat and Search as two plain lines, the four pages as one tight group, then the smChats in
/// two groups (Pinned, Recent). The foot is only his name and Settings.
private struct SMOptionA: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SMBuddyHead().padding(.top, 44)
            VStack(spacing: 2) {
                line("New chat", icon: "square.and.pencil", hint: "⌘N")
                line("Search", icon: "magnifyingglass", hint: "⌘K")
            }
            .padding(.top, 28)
            VStack(spacing: 2) {
                line("Tasks", icon: "checklist", count: "70")
                line("Review", icon: "checkmark.seal", count: "1", lit: true)
                line("Automations", icon: "clock")
                line("Agents", icon: "dot.radiowaves.left.and.right")
            }
            .padding(.top, 28)
            VStack(alignment: .leading, spacing: 2) {
                SMSection(title: "Pinned")
                ForEach(smChats.filter(\.pinned)) { SMRow(chat: $0) }
            }
            .padding(.top, 32)
            VStack(alignment: .leading, spacing: 2) {
                SMSection(title: "Recent")
                ForEach(smChats.filter { !$0.pinned }) { SMRow(chat: $0) }
            }
            .padding(.top, 32)
            Spacer(minLength: 16)
            SMProfile().padding(.bottom, 24)
        }
        .padding(.horizontal, 12)
    }

    private func line(_ name: String, icon: String, count: String? = nil, hint: String? = nil, lit: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(.secondary)
            Text(name)
            Spacer()
            if let count { Text(count).foregroundStyle(lit ? Theme.accent : .secondary).font(.wink(.small)).monospacedDigit() }
            if let hint { Text(hint).font(.wink(.small)).foregroundStyle(.secondary) }
        }
        .font(.wink(.label))
        .padding(.horizontal, 12)
        .frame(height: 34)
    }
}

// MARK: Option B: Buddy as home, the pages as tiles

/// B: Buddy at the top with New chat beside it; under it the four pages as a 2×2 of small tiles with their counts (words
/// kept); search sits over the smChats it searches; the smChats are one list, pinned first with a small pin. The foot is gone:
/// his name and Settings move into Buddy's head menu.
private struct SMOptionB: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                SMBuddyHead(compact: true)
                Image(systemName: "square.and.pencil").font(.wink(.label)).foregroundStyle(.primary)
                    .frame(width: 32, height: 32).winkEdge(16).padding(.trailing, 12)
            }
            .padding(.top, 44)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow { tile("Tasks", icon: "checklist", count: "70"); tile("Review", icon: "checkmark.seal", count: "1", lit: true) }
                GridRow { tile("Automations", icon: "clock"); tile("Agents", icon: "dot.radiowaves.left.and.right") }
            }
            .padding(.horizontal, 12)
            .padding(.top, 28)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                Text("Search chats").foregroundStyle(.secondary)
                Spacer()
                Text("⌘K").font(.wink(.small)).foregroundStyle(.secondary)
            }
            .font(.wink(.label))
            .padding(.horizontal, 12).frame(height: 34)
            .winkEdge(17)
            .padding(.horizontal, 12)
            .padding(.top, 32)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(smChats) { chat in
                    HStack(spacing: 8) {
                        if chat.pinned { Image(systemName: "pin.fill").font(.wink(.small)).foregroundStyle(.secondary).frame(width: 12) }
                        SMRow(chat: chat).padding(.leading, chat.pinned ? -8 : 0)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            Spacer()
        }
    }

    private func tile(_ name: String, icon: String, count: String? = nil, lit: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary)
                Spacer()
                if let count { Text(count).font(.wink(.small)).foregroundStyle(lit ? Theme.accent : .secondary).monospacedDigit() }
            }
            Text(name).font(.wink(.label))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .winkEdge(Theme.Radius.row)
    }
}

/// A side menu beside an empty black chat, the Mac window as it would look; and the iPhone drawer with the same menu.
private struct SMFrame<Menu: View>: View {
    let title: String
    let note: String
    @ViewBuilder var menu: () -> Menu
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.wink(.title))
            Text(note).font(.wink(.label)).foregroundStyle(.secondary).frame(width: 1000, alignment: .leading)
            HStack(alignment: .top, spacing: 40) {
                HStack(spacing: 0) {
                    menu().frame(width: Theme.side).frame(maxHeight: .infinity).background(Theme.tileTop)
                        .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1) }
                    VStack(spacing: 20) {
                        Spacer()
                        WinkFace(width: 44)
                        Text("Good afternoon, Damian").winkDisplay()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity).background(Color.black)
                }
                .frame(width: 900, height: 860)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .winkEdge(12)
                menu().frame(width: 330, height: 760).background(Theme.tileTop)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.screen, style: .continuous))
                    .winkEdge(Theme.Radius.screen)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.04))
        .environment(\.colorScheme, .dark)
    }
}

struct SideMenuBoard: View {
    let option: String
    var body: some View {
        if option == "a" {
            SMFrame(title: "Side menu A · one quiet column",
                  note: "Buddy replaces the wordmark at the top left; its card at the foot goes. New chat and Search become two plain lines, the four pages one tight group, chats in Pinned and Recent. 28 to 32 points between groups. Foot: only your name and Settings.") { SMOptionA() }
        } else {
            SMFrame(title: "Side menu B · Buddy as home, pages as tiles",
                  note: "Buddy at the top left with New chat beside it. Tasks, Review, Automations and Agents as four small tiles with their counts (words kept). Search sits right above the chats; one chat list, pinned first with a pin. No foot at all: your name and Settings move into Buddy's menu.") { SMOptionB() }
        }
    }
}
