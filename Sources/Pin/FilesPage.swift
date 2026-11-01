import PinCore
import SwiftUI

/// The start page: every file as a card, like a design tool's dashboard.
struct FilesPage: View {
    @Environment(Model.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pin").font(Style.strong).foregroundStyle(Style.ink).padding(.horizontal, 10).padding(.bottom, Style.gap)
                Button {} label: { Label("Files", systemImage: "square.grid.2x2") }.buttonStyle(SideRow(chosen: true))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 44)
            .frame(width: 240)
            .background(Style.side)
            ScrollView {
                VStack(alignment: .leading, spacing: Style.edge) {
                    Text("Files").font(Style.title).foregroundStyle(Style.ink)
                    if model.apps.isEmpty {
                        Text("No files yet").font(Style.body).foregroundStyle(Style.grey)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: Style.edge, alignment: .top)], alignment: .leading, spacing: Style.edge) {
                        ForEach(model.apps, id: \.self) { FileCard(name: $0) }
                    }
                }
                .padding(32)
                .padding(.top, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.05))
        }
        .ignoresSafeArea()
    }
}

struct FileCard: View {
    @Environment(Model.self) private var model
    let name: String
    @State private var hovering = false

    var body: some View {
        let screens = (try? model.store.screens(app: name)) ?? []
        let open = model.openCount(app: name)
        Button { model.open(name) } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Color.black
                    HStack(spacing: 8) {
                        ForEach(screens.prefix(3)) { screen in
                            if let version = screen.latest, let image = model.image(screen, version, app: name) {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                    .padding(14)
                }
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: Style.corner))
                .overlay(RoundedRectangle(cornerRadius: Style.corner).strokeBorder(hovering ? Color.white.opacity(0.35) : Style.line))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(Style.strong).foregroundStyle(Style.ink)
                    Text(open > 0 ? "\(screens.count) boards · \(open) open" : "\(screens.count) boards").font(Style.small).foregroundStyle(Style.grey)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
