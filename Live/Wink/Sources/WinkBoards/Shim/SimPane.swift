import SwiftUI

/// New · A running app beside the chat, the way the Claude app has it (Damian, 2 Nov 2026: "you can even click through the simulation ... i want the same
/// thing inside of wink"). A design for now: it lives here in Pin until he says yes, then it moves to wink2's App folder. In the real one the picture is
/// the simulator's own screen, a click is a tap, a drag a swipe and his keys go to the app; here it shows a picture of the app.
struct SimPane: View {
    enum State { case running, building, starting }
    var state = State.running
    var picture: String
    var name = "10"
    var device = "iPhone 17 Pro"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                WinkChip {
                    Text(name)
                    Text(device).foregroundStyle(.secondary)
                    Image(systemName: "chevron.down").foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                WinkMenuIcon(name: "Run again", icon: "arrow.clockwise")
                WinkMenuIcon(name: "Home", icon: "house")
                WinkMenuIcon(name: "Close", icon: "xmark")
            }
            .foregroundStyle(.secondary)
            .padding(.leading, 16).padding(.trailing, 8)
            .frame(height: Theme.bar)
            .padding(.top, 20)
            phone
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var phone: some View {
        ZStack {
            if let image = NSImage(contentsOfFile: picture) {
                Image(nsImage: image).resizable().scaledToFit()
                    .opacity(state == .running ? 1 : 0.25)
            }
            if state != .running {
                HStack(spacing: 8) {
                    WinkSpinner(size: 14)
                    Text(state == .building ? "Building…" : "Starting the simulator…").font(.wink(.label))
                }
            }
        }
        .aspectRatio(402.0 / 874.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.screen, style: .continuous))
        .padding(6)
        .background(Color.black, in: RoundedRectangle(cornerRadius: Theme.Radius.screen + 6, style: .continuous))
    }
}

/// The chat and the pane beside it, in the place of a file's side pane.
struct SimPaneBoard: View {
    var state = SimPane.State.running
    var picture: String
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 0) {
            Sidebar().frame(width: Theme.side)
            Detail().background(Theme.canvas)
            SimPane(state: state, picture: picture)
                .frame(width: 440)
                .background(Theme.sidebar)
        }
        .background(Theme.tile)
    }
}

/// The chat before it is open: Preview in its bar, beside Output.
struct SimChipBoard: View {
    var body: some View {
        Root().overlay(alignment: .topTrailing) {
            WinkChip {
                Image(systemName: "iphone")
                Text("Preview")
            }
            .foregroundStyle(.primary)
            .padding(.top, 32).padding(.trailing, 40)
        }
    }
}
