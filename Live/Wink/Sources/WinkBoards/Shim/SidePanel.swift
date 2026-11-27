import AppKit
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
//
// Three more designs, the panel showing what the AI does right now (27 Nov 2026, wink2 docs/visible-work.md, Damian: "use
// the app icon, real progress, thumbnails - not just empty text"): "new-side-panel-live-app" (an app in use),
// "new-side-panel-live-render" (a long render running), "new-side-panel-live-image" (a picture coming back). Plain words
// only, no tool names. Design only until he says yes: `StepTimeline`, the progress bar and the app tile are not in
// wink2's DESIGN.md or App/Design.swift yet and go there first when he approves.

/// Stands in for wink2's WinkPanel inside a board.
struct WinkPanel: View {
    var body: some View {
        switch ProcessInfo.processInfo.environment["BOARD_PANEL"] {
        case "empty": SidePanelEmpty()
        case "live-app": SidePanelLiveApp()
        case "live-render": SidePanelLiveRender()
        case "live-image": SidePanelLiveImage()
        default: SidePanelBoards()
        }
    }
}

/// Stands in for wink2's PinHost (in App/WinkPanel.swift, which holds Pin's canvas): Wink's model tells it where the AI
/// works on a board. Nothing follows inside a board.
@MainActor final class PinHost {
    static let shared = PinHost()
    var followCamera = true
    func name(of target: String) -> String? { target.isEmpty ? nil : target }
    func focus(app: String, screen: String?, x: Double?, y: Double?, text: String?) {}
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

/// The panel's head as WinkPanel builds it: the tabs, + for a new one, then Follow (the eye with its green dot: the panel
/// goes by itself to what the chat's AI does), Expand and hide at the right.
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
            HStack(spacing: 4) {
                Circle().fill(Theme.accent).frame(width: 6, height: 6)
                Image(systemName: "eye").font(.wink(.label)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6).frame(minWidth: 28, minHeight: 28)
            .accessibilityLabel("Following AI work")
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

// MARK: Live activity: what the AI does right now

private enum LiveApp {
    static let resolve = "/Applications/DaVinci Resolve/DaVinci Resolve.app"
    static let photoshop = "/Applications/Adobe Photoshop 2027/Adobe Photoshop 2027.app"
}

/// An app's real icon from the Mac, or a symbol when the app is not installed.
private struct AppIcon: View {
    let path: String
    let side: CGFloat
    let fallback: String
    var body: some View {
        if FileManager.default.fileExists(atPath: path) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().interpolation(.high).frame(width: side, height: side)
        } else {
            Image(systemName: fallback).font(.wink(side > 40 ? .title : .small)).foregroundStyle(.secondary).frame(width: side, height: side)
        }
    }
}

/// A 16:9 picture from the fixtures with the row's corners.
private struct LiveStill: View {
    var body: some View {
        Group {
            if let picture = NSImage(contentsOfFile: Fixtures.file("still.jpg")) {
                Image(nsImage: picture).resizable().interpolation(.high).aspectRatio(16 / 9, contentMode: .fit)
            } else {
                Rectangle().fill(Theme.chosen).aspectRatio(16 / 9, contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
    }
}

/// One thing the AI did in this turn.
private struct LiveStep: Identifiable {
    enum Icon { case symbol(String), app(String, fallback: String) }
    let icon: Icon
    let label: String
    /// The time it took, or where it stands ("Now", "62%").
    let time: String
    var active = false
    var id: String { label }
}

/// What the AI did in this turn, three rows in plain words: a small icon, the step, and at the right a green tick or the
/// turning ring with the time.
private struct StepTimeline: View {
    let steps: [LiveStep]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This turn").font(.wink(.small)).foregroundStyle(.secondary)
            ForEach(steps) { step in
                HStack(spacing: 12) {
                    Group {
                        switch step.icon {
                        case .symbol(let name): Image(systemName: name).font(.wink(.small)).foregroundStyle(.secondary)
                        case .app(let path, let fallback): AppIcon(path: path, side: 20, fallback: fallback)
                        }
                    }
                    .frame(width: 20, height: 20)
                    Text(step.label).font(.wink(.label)).foregroundStyle(step.active ? Color.primary : Color.secondary).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(step.time).font(.wink(.small)).foregroundStyle(.secondary).monospacedDigit()
                    if step.active {
                        WinkSpinner(size: 14, working: true)
                    } else {
                        Image(systemName: "checkmark").font(.wink(.small)).foregroundStyle(Theme.accent).winkGlow().frame(width: 14, height: 14)
                    }
                }
                .frame(height: 20)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

/// The frame all three share: the head with its tab, the stage in the space above, the steps of this turn at the foot.
private struct LivePanel<Stage: View>: View {
    let tab: (icon: String, name: String)
    let steps: [LiveStep]
    @ViewBuilder var stage: Stage
    var body: some View {
        VStack(spacing: 0) {
            SPHead(tabs: [tab])
            Rectangle().fill(Theme.line).frame(height: 1)
            VStack(spacing: 24) {
                stage.frame(maxWidth: .infinity, maxHeight: .infinity)
                StepTimeline(steps: steps).fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.canvas)
        }
        .background(Theme.sidebar)
    }
}

/// A green dot with a word: "Rendering", "Done".
private struct LiveDot: View {
    let word: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.accent).frame(width: 6, height: 6).winkGlow()
            Text(word).font(.wink(.small)).foregroundStyle(Theme.accent)
        }
    }
}

/// An app in use: its real icon, large, in a calm tile with a green live rim.
private struct SidePanelLiveApp: View {
    var body: some View {
        LivePanel(tab: ("film", "DaVinci Resolve"), steps: [
            LiveStep(icon: .symbol("text.bubble"), label: "Found 46 review notes", time: "4 s"),
            LiveStep(icon: .symbol("film.stack"), label: "Matched 14 clips in project", time: "9 s"),
            LiveStep(icon: .app(LiveApp.resolve, fallback: "film"), label: "Opening timeline in DaVinci Resolve", time: "Now", active: true),
        ]) {
            VStack(spacing: 24) {
                AppIcon(path: LiveApp.resolve, side: 88, fallback: "film")
                    .frame(width: 152, height: 152)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous).stroke(Theme.accent.opacity(0.5), lineWidth: 1).winkGlow())
                VStack(spacing: 8) {
                    Text("Opening your wedding project in DaVinci").font(.wink(.title)).multilineTextAlignment(.center)
                    Text("Timeline · Wedding LONG_3 v5").font(.wink(.label)).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    WinkSpinner(size: 14, working: true)
                    Text("Working · 14 s").font(.wink(.small)).foregroundStyle(.secondary).monospacedDigit()
                }
                .padding(.horizontal, 12).frame(height: 28)
                .background(Theme.chosen, in: Capsule())
            }
        }
    }
}

/// A long render running: a frame of the film, a real bar, how far and how long still.
private struct SidePanelLiveRender: View {
    private let done = 0.62
    var body: some View {
        LivePanel(tab: ("film", "Render · 62%"), steps: [
            LiveStep(icon: .symbol("paintpalette"), label: "Applied colour grade and titles", time: "18 s"),
            LiveStep(icon: .symbol("waveform"), label: "Cleaned interview audio", time: "24 s"),
            LiveStep(icon: .app(LiveApp.resolve, fallback: "film"), label: "Rendering Wedding LONG_3 v5", time: "62%", active: true),
        ]) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 12) {
                    LiveStill()
                    HStack(spacing: 8) {
                        AppIcon(path: LiveApp.resolve, side: 24, fallback: "film")
                        Text("4K · ProRes 422").font(.wink(.small)).foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        LiveDot(word: "Rendering")
                    }
                    .padding(.horizontal, 4)
                }
                .padding(12)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous).stroke(Theme.border, lineWidth: 1))
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rendering Wedding LONG_3 v5").font(.wink(.heading))
                    Capsule().fill(Theme.chosen).frame(height: 8)
                        .overlay(alignment: .leading) {
                            GeometryReader { bar in Capsule().fill(Theme.accent).frame(width: bar.size.width * done).winkGlow() }
                        }
                        .accessibilityLabel("62 percent rendered")
                    HStack {
                        Text("62%").font(.wink(.label).weight(.semibold)).monospacedDigit()
                        Spacer(minLength: 8)
                        Text("1 min 14 s left").font(.wink(.small)).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Text("Frame 4,218 of 6,804 · 2.4× realtime").font(.wink(.small)).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }
}

/// A picture coming back: which app made it, the picture large, its name and what to do with it.
private struct SidePanelLiveImage: View {
    var body: some View {
        LivePanel(tab: ("photo", "Photoshop"), steps: [
            LiveStep(icon: .symbol("photo"), label: "Loaded original portrait", time: "2 s"),
            LiveStep(icon: .app(LiveApp.photoshop, fallback: "wand.and.stars"), label: "Upscaled and retouched skin tones", time: "19 s"),
            LiveStep(icon: .symbol("square.and.arrow.down"), label: "Saved hero-portrait-v3.png", time: "Just now"),
        ]) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AppIcon(path: LiveApp.photoshop, side: 32, fallback: "photo")
                    Text("Retouching hero portrait in Photoshop").font(.wink(.label).weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 8)
                    LiveDot(word: "Done")
                }
                LiveStill()
                    .padding(8)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous).stroke(Theme.border, lineWidth: 1))
                Text("hero-portrait-v3.png · 3840 × 2160").font(.wink(.small)).foregroundStyle(.secondary).monospacedDigit()
                HStack(spacing: 8) {
                    Button("Review") {}.buttonStyle(Pill(filled: true))
                    Button("Open in Finder") {}.buttonStyle(Pill(filled: false))
                }
            }
        }
    }
}
