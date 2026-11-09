import SwiftUI

/// App icon options in the app's current language (black, 4Roll can, red #C8291F, square viewfinder), 9 Nov 2026.
/// Board only; the chosen one moves into the app (Icon Composer layers) after Damian picks.
enum IconOption: String, CaseIterable, Identifiable {
    case nightScreen = "A · Dark picture, red dot"
    case photo = "B · A real photo"
    case graphite = "C · Graphite frame, red ring"
    case greyGlass = "D · Grey picture, red in the glass"
    case warmFilm = "E · Warm film picture"
    case mono = "F · All mono, red dot"
    var id: String { rawValue }
}

/// Frame and lens, Damian's pick, with red only as a small accent (9 Nov: "to much red for the logo but the design
/// principle or idea in itself i like, just the execution").
struct IconOptionView: View {
    let option: IconOption
    var side: CGFloat = 220
    private var r: CGFloat { side * 0.2237 }
    private let red = LC.Colour.accent

    var body: some View {
        ZStack {
            frame
            picture
                .clipShape(RoundedRectangle(cornerRadius: side * 0.12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.black.opacity(0.3), Color.white.opacity(0.4)], startPoint: .top, endPoint: .bottom), lineWidth: side * 0.006))
                .padding(side * 0.1)
            if option == .nightScreen || option == .mono {
                Circle().fill(red).frame(width: side * 0.07).position(x: side * 0.26, y: side * 0.26)
            }
            cleanLens(d: side * 0.5, ring: option == .graphite, glass: glass)
                .offset(x: side * 0.2, y: side * 0.2)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }

    @ViewBuilder private var frame: some View {
        if option == .graphite {
            LinearGradient(colors: [Color(white: 0.24), Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
        } else {
            LinearGradient(colors: [Color(white: 0.98), Color(white: 0.86)], startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder private var picture: some View {
        switch option {
        case .nightScreen:
            LinearGradient(colors: [Color(white: 0.16), Color(white: 0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .photo:
            Fill(image: Sample.photo(10)).saturation(0.85)
        case .graphite:
            Fill(image: Sample.photo(2)).saturation(0.8).brightness(-0.05)
        case .greyGlass:
            LinearGradient(colors: [Color(white: 0.55), Color(white: 0.3), Color(white: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .warmFilm:
            LinearGradient(colors: [Color(red: 0.25, green: 0.22, blue: 0.2), Color(red: 0.62, green: 0.5, blue: 0.4), Color(red: 0.92, green: 0.78, blue: 0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mono:
            LinearGradient(colors: [Color(white: 0.85), Color(white: 0.6)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var glass: [Color] {
        switch option {
        case .greyGlass: [Color(red: 1, green: 0.5, blue: 0.42), red, Color(red: 0.12, green: 0.01, blue: 0.02)]
        case .mono: [Color(white: 0.5), Color(white: 0.2), Color(white: 0.03)]
        default: [Color(red: 0.3, green: 0.4, blue: 0.8), Color(red: 0.18, green: 0.1, blue: 0.4), Color(red: 0.03, green: 0.02, blue: 0.1)]
        }
    }

    private func cleanLens(d: CGFloat, ring: Bool = false, glass: [Color]? = nil) -> some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color.white, Color(white: 0.78)], startPoint: .top, endPoint: .bottom))
            Circle().fill(Color(white: 0.08)).padding(d * 0.09)
            if ring { Circle().strokeBorder(red, lineWidth: d * 0.025).padding(d * 0.16) }
            Circle().fill(Color(white: 0.15)).padding(d * 0.2)
            Circle().fill(RadialGradient(colors: glass ?? [Color(red: 0.3, green: 0.4, blue: 0.85), Color(red: 0.2, green: 0.1, blue: 0.45), Color(red: 0.03, green: 0.02, blue: 0.1)],
                                         center: UnitPoint(x: 0.42, y: 0.38), startRadius: 0, endRadius: d * 0.24))
                .padding(d * 0.28)
            Ellipse().fill(Color.white.opacity(0.5)).frame(width: d * 0.11, height: d * 0.06).rotationEffect(.degrees(-28))
                .offset(x: -d * 0.06, y: -d * 0.08).blur(radius: d * 0.006)
        }
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(0.35), radius: d * 0.05, y: d * 0.03)
    }
}

/// The six options, each large and at home-screen sizes, plus each on a home screen row of other icons.
struct IconOptionsBoard: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 48), count: 3), spacing: 56) {
            ForEach(IconOption.allCases) { o in
                VStack(spacing: 20) {
                    IconOptionView(option: o, side: 220)
                    HStack(spacing: 18) {
                        IconOptionView(option: o, side: 60)
                        IconOptionView(option: o, side: 40)
                        IconOptionView(option: o, side: 29)
                    }
                    Text(o.rawValue).font(LC.Text.headline).foregroundStyle(.white)
                }
            }
        }
        .padding(56)
        .frame(width: 1100, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(white: 0.1))
    }
}
