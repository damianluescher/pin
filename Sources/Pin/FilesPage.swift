import AppKit
import PinCore
import SwiftUI

/// The start page: every file as a card. One click selects, a double click or Return opens, as in Finder.
struct FilesPage: View {
    @Environment(Model.self) private var model
    @State private var search = ""
    @State private var chosen: String?

    private var shown: [String] {
        search.isEmpty ? model.apps : model.apps.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        Group {
            if shown.isEmpty {
                ContentUnavailableView(search.isEmpty ? "No files" : "No results", systemImage: "doc.on.doc")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: Style.edge, alignment: .top)], alignment: .leading, spacing: Style.edge) {
                        ForEach(shown, id: \.self) { FileCard(name: $0, chosen: $chosen) }
                    }
                    .padding(Style.edge)
                }
                .contentShape(Rectangle())
                .onTapGesture { chosen = nil }
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search files")
        .background { Button("") { if let chosen { model.open(chosen) } }.keyboardShortcut(.return, modifiers: []).hidden() }
    }
}

struct FileCard: View {
    @Environment(Model.self) private var model
    let name: String
    @Binding var chosen: String?

    var body: some View {
        let screens = (try? model.store.screens(app: name)) ?? []
        let open = model.openCount(app: name)
        let isChosen = chosen == name
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.black)
                HStack(spacing: 8) {
                    ForEach(screens.prefix(3)) { screen in
                        if let version = screen.latest, let image = model.image(screen, version, app: name) {
                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                .padding(14)
            }
            .frame(height: 190)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: isChosen ? 3 : 0))
            VStack(spacing: 2) {
                Text(name).font(.body.weight(.medium)).padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 4).fill(isChosen ? Color.accentColor : .clear))
                Text(open > 0 ? "\(screens.count) boards, \(open) open" : "\(screens.count) boards").font(.caption).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .gesture(TapGesture(count: 2).onEnded { model.open(name) })
        .simultaneousGesture(TapGesture().onEnded { chosen = name })
        .contextMenu {
            Button("Open") { model.open(name) }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([model.store.home.appendingPathComponent(name)])
            }
        }
    }
}
