import SwiftUI
import AppKit

// Board for "Saves" in Wink (20 Nov 2026, Damian: "we could build our own mymind rather than rely on mymind, and also have it
// directly inside of the app"). Plan: ~/Documents/Research/own-mymind.md. One page under Review in the side list: everything he
// saves from the share sheet lands here, Buddy watches each save, writes the take and sorts the topic, and the open save shows
// where it went (playbook, built, someday). Wink's own look, not mymind's. Design only, made-up titles shaped like his saves.
// Open decision for him: a picture grid is a new piece in Wink (DESIGN.md says lists are open rows, never boxes).

private struct Save {
    let title: String
    let take: String
    let topic: String
    let kind: String      // SF Symbol for the source
    let tall: Bool
    var state = Done.placed
    var picture = false

    enum Done { case saving, watching, placed }
}

private let saves: [Save] = [
    Save(title: "Waiting for the Mac", take: "Saved on the iPhone at 21:40, goes in when Wink reaches the Mac", topic: "", kind: "iphone", tall: false, state: .saving),
    Save(title: "Reverse engineer any app with one MCP", take: "Watching the reel…", topic: "AI skills and agents", kind: "play.rectangle", tall: true, state: .watching),
    Save(title: "New York City cinematic reel", take: "Drone and street shots, 7 days, Sony FX3. Shot list for your NY trip.", topic: "New York", kind: "play.rectangle", tall: true, picture: true),
    Save(title: "Purist: the agentic canvas", take: "Design canvas agents can edit. Close to what Pin does; nothing to switch.", topic: "Tools to try", kind: "safari", tall: false),
    Save(title: "Three rules for the perfect T-shirt", take: "Fit, length at the waistband, 260 GSM. The Brando by 33mm, £35.", topic: "Clothes", kind: "play.rectangle", tall: true),
    Save(title: "GSAP animations, every framework", take: "Copy-ready scroll and text effects. Used for the portfolio hero.", topic: "Design references", kind: "safari", tall: false, picture: true),
    Save(title: "5 pillars of a skincare routine", take: "Adds a serum and a weekly exfoliant to your October routine.", topic: "Skincare and grooming", kind: "play.rectangle", tall: true),
    Save(title: "App Store screenshots that convert", take: "First screenshot sells the outcome, not the feature. In the LUT Cam store page.", topic: "App building and launch", kind: "play.rectangle", tall: false),
]

private let topics: [(String, Int)] = [("All", 525), ("New York", 88), ("Clothes", 61), ("Cinematic references", 53), ("App building", 50), ("AI skills", 49), ("AI video", 47)]

// MARK: Pieces

private struct Cover: View {
    let save: Save
    let height: CGFloat
    var body: some View {
        // The placeholder sets the size; the picture only fills it, so a wide photo never widens its column.
        Theme.raised
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if save.picture, let image = NSImage(contentsOfFile: Fixtures.file("still.jpg")) {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: save.kind).font(.wink(.title)).foregroundStyle(.tertiary)
                }
            }
            .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        .overlay(alignment: .topTrailing) {
            switch save.state {
            case .watching: WinkSpinner(size: 14, working: true).padding(8)
            case .saving: Image(systemName: "arrow.up.circle").foregroundStyle(.secondary).padding(8)
            case .placed: EmptyView()
            }
        }
    }
}

private struct SaveCard: View {
    let save: Save
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Cover(save: save, height: save.tall ? (compact ? 200 : 260) : (compact ? 110 : 150))
            Text(save.title).font(.wink(.label)).lineLimit(1)
            Text(save.take).font(.wink(.small)).foregroundStyle(.secondary).lineLimit(2)
        }
    }
}

/// Two or four calm columns, newest first (masonry: each column takes the next save).
private struct SaveGrid: View {
    let columns: Int
    var compact = false
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(0..<columns, id: \.self) { column in
                VStack(spacing: 20) {
                    ForEach(Array(saves.enumerated()).filter { $0.offset % columns == column }, id: \.offset) { SaveCard(save: $0.element, compact: compact) }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
}

private struct SearchField: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            Text("Search your saves, even what a reel says").foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: Theme.control)
        .background(Theme.raised, in: Capsule())
        .font(.wink(.label))
    }
}

private struct TopicChips: View {
    var limit = 7
    var body: some View {
        WinkFlow(spacing: 8) {
            ForEach(Array(topics.prefix(limit).enumerated()), id: \.offset) { index, topic in
                HStack(spacing: 6) {
                    Text(topic.0)
                    Text("\(topic.1)").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(index == 0 ? Theme.chosen : Color.clear, in: Capsule())
            }
        }
        .font(.wink(.small))
    }
}

/// The open save, as a pane beside the grid on the Mac.
private struct OpenSave: View {
    var compact = false
    var body: some View {
        let save = saves[2]
        VStack(alignment: .leading, spacing: 20) {
            Cover(save: save, height: compact ? 280 : 320)
            VStack(alignment: .leading, spacing: 4) {
                Text(save.title).font(.wink(.heading))
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Instagram · saved 3 h ago · New York")
                }
                .font(.wink(.small)).foregroundStyle(.secondary)
            }
            SaveBlock(title: "Buddy's take") {
                Text("Seven days of drone and street shots, graded warm, shot on a Sony FX3. Six shots fit your NY list: the Brooklyn Bridge sunrise, the rooftop at dusk.")
            }
            SaveBlock(title: "Your note") {
                Text("for the ny film, the rooftop one").padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: Theme.control, alignment: .leading)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            }
            SaveBlock(title: "Where it went") {
                HStack(spacing: 8) {
                    Image(systemName: "book").foregroundStyle(Theme.skill)
                    Text("Learned › New York playbook, shot list")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            }
            HStack {
                Text("Ask Buddy about this").foregroundStyle(.black).padding(.horizontal, 18).frame(height: Theme.control).background(.white, in: Capsule())
                Spacer()
            }
            .font(.wink(.label))
        }
        .font(.wink(.label))
    }
}

private struct SaveBlock<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.wink(.small)).foregroundStyle(.secondary)
            content
        }
    }
}

/// The iPhone share sheet: picture, title, one optional line, Save.
private struct ShareSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Cancel").foregroundStyle(.secondary)
                Spacer()
                Text("Save to Wink").font(.wink(.label).weight(.semibold))
                Spacer()
                Text("Save").foregroundStyle(.black).padding(.horizontal, 14).frame(height: 28).background(.white, in: Capsule())
            }
            .font(.wink(.label))
            HStack(alignment: .top, spacing: 12) {
                Cover(save: saves[2], height: 72).frame(width: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("New York City cinematic reel").font(.wink(.label))
                    Text("instagram.com").font(.wink(.small)).foregroundStyle(.secondary)
                }
            }
            Text("Why I saved this… (optional)").foregroundStyle(.secondary).font(.wink(.label))
                .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: Theme.field, alignment: .leading)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
            Text("Buddy watches it and sorts it. You never have to.").font(.wink(.small)).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 340)
        .background(Theme.sidebar, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}

// MARK: The board

struct SavesBoard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mac · Saves (side list, under Review), one save open").font(.wink(.label)).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 8) {
                            Text("Saves").font(.wink(.title))
                            Spacer()
                            Text("Watching 1 · 4 in the queue").font(.wink(.small)).foregroundStyle(.secondary)
                        }
                        SearchField()
                        TopicChips()
                        SaveGrid(columns: 3)
                        Spacer(minLength: 0)
                    }
                    .padding(24)
                    .frame(width: 640)
                    Theme.line.frame(width: 1)
                    OpenSave().padding(24).frame(width: 380)
                }
                .frame(height: 1000, alignment: .top)
                .clipped()
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("iPhone · Saves").font(.wink(.label)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Saves").font(.wink(.title))
                    SearchField()
                    TopicChips(limit: 4)
                    SaveGrid(columns: 2, compact: true)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(width: 340, height: 760, alignment: .top)
                .clipped()
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.screen, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("iPhone · share sheet › Wink").font(.wink(.label)).foregroundStyle(.secondary)
                ShareSheet()
                Text("iPhone · a save opened").font(.wink(.label)).foregroundStyle(.secondary).padding(.top, 20)
                OpenSave(compact: true).padding(16).frame(width: 340, height: 760, alignment: .top).clipped()
                    .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.Radius.screen, style: .continuous))
                Text("Green turning dot: Buddy is watching it. Arrow: saved on the iPhone, waiting for the Mac. No mark: done.")
                    .font(.wink(.small)).foregroundStyle(.secondary).frame(width: 340, alignment: .leading).padding(.top, 12)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.tile)
    }
}
