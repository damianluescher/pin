import SwiftUI

// Pin inside Wink (25 Nov 2026, Damian: "this side panel is so tough, also seeing Claude's cursor actively working on each
// page, this is exactly what I want for Pin ... rather have it inside of Wink"; reference: Claude's desktop app, a Claude
// Design board beside the chat). Design only: a chat on the left, the side panel on the right with a live-board canvas,
// Buddy's own cursor where it is working, a comment pin, the canvas tools at the foot, the panel's New menu open.

private let spGreen = Theme.accent

/// A small live Wink screen on the canvas: the real board scaled down, with its name above.
private struct SPScreen: View {
    let name: String
    let board: String
    var width: CGFloat = 300
    var height: CGFloat = 192
    var lit = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(name).font(.wink(.small)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.wink(.small)).foregroundStyle(.secondary)
            }
            WinkBoards.board(board)
                .frame(width: 1280, height: 820)
                .scaleEffect(width / 1280, anchor: .topLeading)
                .frame(width: width, height: height, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(lit ? spGreen : Theme.border, lineWidth: lit ? 2 : 1))
                .allowsHitTesting(false)
        }
        .frame(width: width)
    }
}

/// Buddy's cursor: an arrow in Wink green with its name in a pill, the way Claude shows "Claude" on its board.
private struct SPCursor: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "cursorarrow").font(.system(size: 22, weight: .semibold)).foregroundStyle(spGreen)
                .shadow(color: .black.opacity(0.6), radius: 2)
            Text("Buddy").font(.wink(.small).weight(.semibold)).foregroundStyle(.black)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(spGreen, in: Capsule())
                .offset(x: 14, y: -4)
        }
    }
}

private struct SPPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            // Head: what is open, and the panel's own buttons (New, wide, close).
            HStack(spacing: 8) {
                Image(systemName: "square.on.square").foregroundStyle(spGreen)
                Text("Wink · Live boards").font(.wink(.label))
                Image(systemName: "chevron.down").font(.wink(.small)).foregroundStyle(.secondary)
                Spacer()
                ForEach(["plus", "arrow.up.left.and.arrow.down.right", "sidebar.right"], id: \.self) { icon in
                    Image(systemName: icon).font(.wink(.label)).foregroundStyle(.secondary).frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 16).frame(height: 52)
            // Second line: page, grid or one screen, run, share.
            HStack(spacing: 8) {
                Text("Chat").font(.wink(.label))
                Image(systemName: "chevron.down").font(.wink(.small)).foregroundStyle(.secondary)
                HStack(spacing: 2) {
                    Image(systemName: "square.grid.2x2").frame(width: 28, height: 24).background(Theme.chosen, in: RoundedRectangle(cornerRadius: 6))
                    Image(systemName: "square").frame(width: 28, height: 24)
                }
                .font(.wink(.small)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "play").foregroundStyle(.secondary)
                Text("Run").font(.wink(.label)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).frame(height: 40)
            Rectangle().fill(Theme.line).frame(height: 1)
            // The canvas: the app's real screens; Buddy works on the middle one.
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    for x in stride(from: 0, through: size.width, by: 24) {
                        for y in stride(from: 0, through: size.height, by: 24) {
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.08)))
                        }
                    }
                }
                HStack(alignment: .top, spacing: 24) {
                    SPScreen(name: "Chat", board: "mac-chat")
                    SPScreen(name: "Tasks", board: "window-tasks", lit: true)
                }
                .padding(.leading, 32).padding(.top, 120)
                SPScreen(name: "Review", board: "window-review").padding(.leading, 32).padding(.top, 360)
                // Buddy's cursor on the Tasks screen, with what it is doing.
                SPCursor().padding(.leading, 470).padding(.top, 230)
                Text("Moving the date chip next to the title").font(.wink(.small)).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.raised, in: Capsule())
                    .padding(.leading, 356).padding(.top, 330)
                // His comment on the Chat screen.
                ZStack {
                    Circle().fill(Color.white).frame(width: 24, height: 24)
                    Text("D").font(.wink(.small).weight(.semibold)).foregroundStyle(.black)
                }
                .padding(.leading, 200).padding(.top, 210)
                // The New menu, open under +.
                VStack(alignment: .leading, spacing: 2) {
                    Text("New").font(.wink(.small)).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)
                    menuRow("square.on.square", "Live boards", "your apps' real screens", .init(red: 0.24, green: 0.84, blue: 0.52))
                    menuRow("macwindow", "Computer", "watch Buddy use your Mac", .init(red: 0.55, green: 0.62, blue: 1))
                    menuRow("globe", "Browser", "a page in ego lite", .init(red: 0.6, green: 0.6, blue: 0.6))
                    menuRow("doc.text", "File", "a doc, picture or video", .init(red: 0.95, green: 0.7, blue: 0.3))
                }
                .padding(.bottom, 8)
                .frame(width: 260)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
                .padding(.leading, 524).padding(.top, 4)
                // Tools at the foot: select, hand, comment, text, frame; Ask Buddy; zoom.
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(Array(["cursorarrow", "hand.raised", "bubble.left", "textformat", "number"].enumerated()), id: \.offset) { index, icon in
                            Image(systemName: icon).font(.wink(.label))
                                .foregroundStyle(index == 0 ? Color.black : Color.primary)
                                .frame(width: 36, height: 36)
                                .background(index == 0 ? spGreen : .clear, in: RoundedRectangle(cornerRadius: 10))
                        }
                        Text("Ask Buddy").font(.wink(.label)).padding(.horizontal, 12).frame(height: 36)
                            .background(Theme.chosen, in: RoundedRectangle(cornerRadius: 10))
                        Text("37 %").font(.wink(.small)).foregroundStyle(.secondary).padding(.horizontal, 8)
                    }
                    .padding(6)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.035))
        }
        .background(Theme.tile)
    }

    private func menuRow(_ icon: String, _ name: String, _ note: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(.wink(.label))
                Text(note).font(.wink(.small)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12).frame(height: 46)
        .background(name == "Live boards" ? Theme.chosen : .clear, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 6)
    }
}

/// The chat beside the panel: his ask and Buddy's answer with the board card it opened.
private struct SPChat: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Wink").font(.wink(.title)).padding(.top, 52)
            HStack { Spacer()
                Text("Move the date on the Tasks screen next to the title, and show me while you do it.")
                    .font(.wink(.body)).padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.chosen, in: RoundedRectangle(cornerRadius: 16)).frame(maxWidth: 420, alignment: .trailing)
            }
            HStack(spacing: 12) {
                Image(systemName: "square.on.square").foregroundStyle(spGreen)
                    .frame(width: 36, height: 36).background(Theme.chosen, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wink · Live boards").font(.wink(.label))
                    Text("Open beside the chat · Buddy is working on Tasks").font(.wink(.small)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12).background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))
            Text("On it. You can watch my cursor on the Tasks board; I'll rebuild the screen when the date sits beside the title.")
                .font(.wink(.body))
            Spacer()
            HStack {
                Text("Reply").font(.wink(.body)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "arrow.up").font(.wink(.label)).foregroundStyle(.black).frame(width: 32, height: 32).background(Color.white, in: Circle())
            }
            .padding(.horizontal, 16).frame(height: 56)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.border, lineWidth: 1))
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
    }
}

/// The whole Mac window: Wink's folded icon strip, the chat, the side panel.
struct SidePanelBoard: View {
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 16) {
                BuddyFace(size: 26, working: true).padding(.top, 52)
                ForEach(["square.and.pencil", "bubble.left", "checklist", "checkmark.seal", "repeat", "clock"], id: \.self) {
                    Image(systemName: $0).font(.wink(.label)).foregroundStyle(.secondary).frame(height: 28)
                }
                Spacer()
            }
            .frame(width: 80).background(Theme.tile)
            .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1) }
            SPChat().frame(width: 560)
            Rectangle().fill(Theme.line).frame(width: 1)
            SPPanel()
        }
        .frame(width: 1440, height: 900)
        .environment(\.colorScheme, .dark)
    }
}
