import SwiftUI

// The side panel beside a chat (27 Nov 2026, Damian: "there is no screen for not compacted sideplanel please also show
// this"). The window is Wink's own `Root`: side list, chat, the panel's place and width are the real code. Only the panel's
// inside is drawn here, from Wink's pieces, under the real names `WinkPanel` and `PanelButton`: the real ones (wink2
// App/WinkPanel.swift, left out of this build in Package.swift) host Pin's canvas, a browser and the Mac's screen, none of
// which can run inside a board. The head keeps the real head's measures.
//
// Two boards: "mac-chat-side-panel-open" (Wink's live boards open in the panel) and "new-side-panel-empty"
// (BOARD_PANEL=empty), a design for the panel with nothing open: the four things it can open as a centred grid instead of
// the + menu. Design only until he says yes; the real empty state is still the line "Nothing open".

/// Stands in for wink2's WinkPanel inside a board.
struct WinkPanel: View {
    var body: some View {
        if ProcessInfo.processInfo.environment["BOARD_PANEL"] == "empty" { SidePanelEmpty() } else { SidePanelBoards() }
    }
}

/// Stands in for wink2's button in a chat's bar that opens the panel: the same icon, no action.
struct PanelButton: View {
    var body: some View { WinkMenuIcon(name: "Side panel (⌘\\)", icon: "sidebar.right") }
}

/// A small live Wink screen: the real board scaled down, its name above.
private struct SPScreen: View {
    let name: String
    let board: String
    var width: CGFloat = 184
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.wink(.small)).foregroundStyle(.secondary)
            WinkBoards.board(board)
                .frame(width: 1280, height: 820)
                .scaleEffect(width / 1280, anchor: .topLeading)
                .frame(width: width, height: width * 820 / 1280, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous).stroke(Theme.border, lineWidth: 1))
                .allowsHitTesting(false)
        }
    }
}

/// The panel's head as WinkPanel builds it: the tabs, + for a new one, Expand and hide at the right.
private struct SPHead: View {
    let tabs: [(icon: String, name: String)]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                let on = index == 0
                HStack(spacing: 6) {
                    Image(systemName: tab.icon).font(.wink(.small)).foregroundStyle(on ? Theme.accent : Color.secondary)
                    Text(tab.name).font(.wink(.label)).lineLimit(1).foregroundStyle(on ? Color.primary : Color.secondary)
                    if on { Image(systemName: "xmark").font(.wink(.small)).foregroundStyle(.secondary).frame(width: 16, height: 16) }
                }
                .padding(.horizontal, 12).frame(height: 32)
                .background(on ? Theme.chosen : .clear, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            }
            Image(systemName: "plus").font(.wink(.label)).foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(Theme.chosen, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            Spacer(minLength: 8)
            ForEach(["arrow.up.left.and.arrow.down.right", "sidebar.right"], id: \.self) { icon in
                Image(systemName: icon).font(.wink(.label)).foregroundStyle(.secondary).frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 20)
        .frame(height: 64)
    }
}

/// The panel with Wink's live boards open: real screens, small, two in a row.
private struct SidePanelBoards: View {
    private let screens = [("Chat", "mac-chat"), ("Tasks", "window-tasks"), ("Review", "window-review"), ("Settings", "window-settings-general")]
    var body: some View {
        VStack(spacing: 0) {
            SPHead(tabs: [("square.on.square", "Wink"), ("globe", "Gmail")])
            Rectangle().fill(Theme.line).frame(height: 1)
            LazyVGrid(columns: [GridItem(.fixed(184), spacing: 24), GridItem(.fixed(184))], alignment: .leading, spacing: 24) {
                ForEach(screens, id: \.1) { SPScreen(name: $0.0, board: $0.1) }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.canvas)
        }
        .background(Theme.sidebar)
    }
}

/// The panel with nothing open: what it can open, as four cards in the middle.
private struct SidePanelEmpty: View {
    private let kinds = [
        ("square.on.square", "Live boards", "Your apps' real screens"),
        ("globe", "Browser", "Open a page in ego lite"),
        ("macwindow", "Computer", "Watch Buddy use your Mac"),
        ("doc", "File", "Open a doc, picture or video"),
    ]
    var body: some View {
        VStack(spacing: 0) {
            SPHead(tabs: [("plus", "New tab")])
            Rectangle().fill(Theme.line).frame(height: 1)
            VStack(spacing: 24) {
                Text("Open something").font(.wink(.title))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(kinds, id: \.1) { kind in
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: kind.0).font(.wink(.label).weight(.medium)).foregroundStyle(Theme.accent)
                                .frame(width: Theme.control, height: Theme.control)
                                .background(Theme.chosen, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(kind.1).font(.wink(.label).weight(.semibold))
                                Text(kind.2).font(.wink(.small)).foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous).stroke(Theme.border, lineWidth: 1))
                    }
                }
                .frame(maxWidth: 464)
                Text("Or open a file or board from the chat to see it here.").font(.wink(.small)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.canvas)
        }
        .background(Theme.sidebar)
    }
}
