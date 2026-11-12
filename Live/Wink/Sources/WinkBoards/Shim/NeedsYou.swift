import SwiftUI

// Boards for "needs you" (12 Nov 2026). Damian: "why didnt you note me that mymind was waiting on permission from me regarding
// location, you're not having an overview over my wink, this is a big issue". A permission prompt waited 6 minutes under the same
// white dot as "new"; Buddy heard nothing; a macOS box (location) is not seen by Wink at all. Design only: none of this is in wink2
// until he says yes. Wink's own pieces, made-up rows.

private struct NeedRow: View {
    let title: String
    var asks: String? = nil
    var mark: Mark = .none
    enum Mark { case none, needs, new, working, waiting }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).lineLimit(1)
                if let asks { Text(asks).font(.wink(.small)).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer(minLength: 8)
            switch mark {
            case .needs: Circle().fill(Theme.amber).frame(width: 8, height: 8)
            case .new: Circle().fill(.white).frame(width: 8, height: 8)
            case .working: WinkSpinner(size: 12, working: true)
            case .waiting: WinkSpinner(size: 12)
            case .none: EmptyView()
            }
        }
        .font(.wink(.label))
        .padding(.horizontal, 12)
        .padding(.vertical, asks == nil ? 0 : 8)
        .frame(minHeight: Theme.menuRow)
    }
}

private struct GroupName: View {
    let name: String
    var body: some View {
        Text(name).font(.wink(.label).weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.top, Theme.Room.list).padding(.bottom, 4)
    }
}

/// The side list with Needs You: amber for "he must click or answer", with what it asks under the name; white stays "new".
private struct NeedsList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                WinkFace(width: 30)
                Text("wink").font(.winkMark).foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 12).padding(.top, 40).padding(.bottom, 12)
            GroupName(name: "Needs You")
            NeedRow(title: "mymind sprint: App building", asks: "Allow: delete its work folder · 2 min", mark: .needs)
            NeedRow(title: "ego lite: test the AI browser", asks: "Mac box: Location access · 1 min", mark: .needs)
            NeedRow(title: "Film test A: LUT Cam", asks: "Says it waits, nothing runs · 4 min", mark: .needs)
            GroupName(name: "Pinned")
            NeedRow(title: "Launch film", mark: .working)
            NeedRow(title: "mymind worker: New York", mark: .waiting)
            NeedRow(title: "Brand colours", mark: .new)
            NeedRow(title: "Trip to Lisbon")
            GroupName(name: "Today")
            NeedRow(title: "Reply to the landlord")
            NeedRow(title: "Newsletter draft")
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                legend(AnyView(Circle().fill(Theme.amber).frame(width: 8, height: 8)), "Needs your click or answer")
                legend(AnyView(WinkSpinner(size: 12, working: true)), "Working")
                legend(AnyView(WinkSpinner(size: 12)), "Waiting on its own job")
                legend(AnyView(Circle().fill(.white).frame(width: 8, height: 8)), "Something new")
            }
            .font(.wink(.small)).foregroundStyle(.secondary)
            .padding(12)
        }
        .frame(width: Theme.side)
        .background(Theme.tile)
    }

    private func legend(_ mark: AnyView, _ words: String) -> some View {
        HStack(spacing: 8) { mark.frame(width: 12); Text(words) }
    }
}

/// Buddy's chat with the lines the engine sends: one per prompt, about a minute after it starts waiting, never again.
private struct BuddyLines: View {
    private let lines: [(String, String)] = [
        ("Check-in · waiting: mymind sprint: App building needs your click: allow deleting its work folder.",
         "mymind's sprint wants to delete its work folder and waits on you. Open it and press Allow, or tell me \"allow\"."),
        ("Check-in · waiting: a Mac box asks for Location access while ego lite: test the AI browser is stuck on a step.",
         "A Mac box is open asking for your location, and the ego lite test is stuck on it. Click Allow or Don't Allow on the box."),
        ("Check-in · stuck: Film test A: LUT Cam said it waits for the render, but nothing runs for 4 min.",
         "Film test A says it waits for the render, but nothing is running. I nudged it to check and carry on."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            TopBar(title: "Buddy") { EmptyView() }
            VStack(alignment: .leading, spacing: 24) {
                ForEach(lines, id: \.0) { line in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(line.0).font(.wink(.small)).foregroundStyle(.secondary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
                        Text(line.1)
                    }
                }
                Text("No AI watches for this: the engine checks every few seconds, so it costs nothing while nothing waits. One line per prompt, never repeated.")
                    .font(.wink(.small)).foregroundStyle(.secondary)
            }
            .font(.wink(.body))
            .winkColumn()
            Spacer()
        }
        .background(Theme.canvas)
    }
}

struct NeedsYouBoard: View {
    var body: some View {
        HStack(spacing: 0) {
            NeedsList()
            BuddyLines()
        }
    }
}
