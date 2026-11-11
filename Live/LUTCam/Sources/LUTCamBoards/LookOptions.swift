// Two ways to change the look on the photo page, as options for Damian (Pin 11 Nov, comment m66tev6d: "not sure
// about the way you can change the look overall ... dont know how"). Board-only until he picks one.
import SwiftUI

/// Option A: the photo itself in every look, small, with the film's name under it (like picking a print).
struct LookThumbStrip: View {
    var picked = Look.all.firstIndex { $0.id == "ektar-100" } ?? 0
    var body: some View {
        Color.clear.overlay(alignment: .leading) { row }.clipped()
    }

    private var row: some View {
        // A plain row (a ScrollView draws blank on Pin's canvas); the app would scroll it.
        HStack(spacing: LC.Space.s) {
                ForEach(Array(Look.all.enumerated()), id: \.offset) { i, look in
                    VStack(spacing: LC.Space.xs) {
                        Fill(image: LCArt.image(.viewfinder)).look(look)
                            .frame(width: LC.Size.tile * 3 / 4, height: LC.Size.tile * 3 / 4)
                            .clipShape(RoundedRectangle(cornerRadius: LC.Radius.thumb, style: .continuous))
                            .overlay {
                                if i == picked {
                                    RoundedRectangle(cornerRadius: LC.Radius.thumb, style: .continuous).strokeBorder(Color.white, lineWidth: 2)
                                }
                            }
                        Text(look.name).font(LC.Text.label).lineLimit(1).fixedSize()
                            .foregroundStyle(i == picked ? LC.Colour.primary : LC.Colour.secondary)
                    }
                }
            }
            .padding(.horizontal, LC.Space.edge - LC.Space.cameraEdge)
            .fixedSize()
    }
}

/// Option B: swipe left or right on the photo to change the look; its name shows on the picture for a moment. The
/// space under the photo holds the look's strength and grain instead of the cans.
struct LookSwipePage: View {
    var body: some View {
        PhotoViewScreen(picture: AnyView(picture), title: "Portra 400", tool: .look,
                        control: AnyView(StrengthRows(strength: 1, grain: 1)))
    }

    private var picture: some View {
        ZStack {
            Fill(image: LCArt.image(.viewfinder)).look(Look.named("portra-400"))
            VStack(spacing: LC.Space.s) {
                Spacer()
                Text("PORTRA 400").font(LC.Text.mono).foregroundStyle(LC.Colour.primary)
                    .padding(.horizontal, LC.Space.pill).frame(minHeight: LC.Size.pair)
                    .liquidGlass(Capsule(), fallback: LC.Colour.glassDark)
                HStack(spacing: LC.Space.xs) {
                    ForEach(0..<Look.all.count, id: \.self) { i in
                        Circle().fill(i == 2 ? Color.white : Color.white.opacity(0.4)).frame(width: LC.Size.dot, height: LC.Size.dot)
                    }
                }
                .padding(.bottom, LC.Space.m)
            }
        }
    }
}
