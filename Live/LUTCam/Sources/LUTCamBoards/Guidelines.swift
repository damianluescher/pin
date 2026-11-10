import SwiftUI

/// LUT Cam's design guidelines as a Pin board (Damian, 9 Nov 2026: "make a guidelines page for the design so we always
/// stay consistent"). Everything shown is drawn from the app's own tokens (App/UI/Design.swift, App/UI/Pages/Kit.swift)
/// and components, so the page cannot drift from the app. Written rules: ~/tools/lutcam/design/GUIDELINES.md.
struct GuidelinesBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 56) {
            VStack(alignment: .leading, spacing: 8) {
                Text("LUT Cam guidelines").font(.system(size: 44, weight: .black)).foregroundStyle(.white)
                Text("Every value here comes from the app's code. Change a value there, never on one screen.")
                    .font(LC.Text.body).foregroundStyle(LC.Colour.secondary)
            }
            section("Rules") { rules }
            section("Colour") { colours }
            section("Type") { type }
            section("Spacing") { spacing }
            section("Corners") { corners }
            section("Controls") { controls }
            section("Film cans") { cans }
        }
        .padding(64)
        .frame(width: 1200, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.black)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title.uppercased()).font(LC.Text.label).foregroundStyle(LC.Colour.secondary)
            content()
        }
    }

    // MARK: Rules

    private let ruleList: [(String, String)] = [
        ("Image first", "The picture and its film look are the product. Everything else stays quiet: black, few controls."),
        ("Film stocks only", "Looks are real stocks simulated from their data (spektrafilm). No old-phone or made-up filters."),
        ("Not a film-roll app", "No frame counters, rolls, \"developing\" or expiry dates. Shooting experience and image quality."),
        ("Unprocessed always kept", "Every photo keeps its unprocessed sensor file; any look can be changed later, Pure always first."),
        ("One red, one job", "#ED3329 only, for what is live, new or costs money: the value you change, new photos, prices, switches on. Never a big area."),
        ("Round picture", "The picture has 28 corners, 12 from the screen edge, like 4Roll."),
        ("Shutter where Apple's is", "Anchored to the bottom, centre 86 pt above the screen edge, 72 pt, solid white, nothing inside. The lens is a 24 mm glass pill beside the flip button."),
        ("Glass on the picture", "Controls over or next to the picture are Liquid Glass on the phone: top buttons, flip, notices, the format chip (Pin shows a plain fill). No edge print, no helper lines."),
        ("4Roll language", "Black canvas, #1C1C1E cards, heavy white titles, grey second lines, full-width buttons, the 4Roll film can."),
        ("Feel it", "Haptics everywhere: a tick per 0.1 EV and a stronger one at each stop, a firm tap on the shutter, a click on lens, look and format, a double tap on focus lock, a buzz on warnings."),
        ("Few words", "Short, plain, in Damian's voice. No helper sentences for obvious things."),
        ("One scale", "Only the sizes, gaps, corners and colours on this page. A new value is added here first."),
    ]

    private var rules: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible())], alignment: .leading, spacing: 24) {
            ForEach(ruleList, id: \.0) { r in
                VStack(alignment: .leading, spacing: 6) {
                    Text(r.0).font(LC.Text.headline).foregroundStyle(.white)
                    Text(r.1).font(LC.Text.body).foregroundStyle(LC.Colour.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: LC.Radius.card, style: .continuous).fill(LC.Colour.card))
            }
        }
    }

    // MARK: Colour

    private var colours: some View {
        HStack(alignment: .top, spacing: 20) {
            swatch(LC.Colour.canvas, "Canvas", "#000000", "Every screen", border: true)
            swatch(LC.Colour.card, "Card", "#1C1C1E", "Cards, sheets, tiles")
            swatch(LC.Colour.primary, "Primary", "#FFFFFF", "Titles, values, icons")
            swatch(LC.Colour.secondary, "Secondary", "#999999", "Second lines, labels")
            swatch(LC.Colour.accent, "The one red", "#ED3329", "Live, new, price")
            swatch(Color.white, "Shutter", "#FFFFFF", "Clean white circle")
        }
    }

    private func swatch(_ c: Color, _ name: String, _ hex: String, _ job: String, border: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(c).frame(height: 110)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(border ? 0.2 : 0), lineWidth: 1))
            Text(name).font(LC.Text.bodyStrong).foregroundStyle(.white)
            Text(hex).font(LC.Text.label).foregroundStyle(LC.Colour.secondary)
            Text(job).font(LC.Text.label).foregroundStyle(LC.Colour.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Type

    private var type: some View {
        VStack(alignment: .leading, spacing: 0) {
            typeRow("Title", "LC.Text.title · large title 34 bold", "Settings", LC.Text.title)
            typeRow("Headline", "LC.Text.headline · title 2, 22 bold", "Kodak Portra 400", LC.Text.headline)
            typeRow("Body", "LC.Text.body · 17 (semibold for buttons)", "Your photos never leave your phone.", LC.Text.body)
            typeRow("Label", "LC.Text.label · 15 medium, controls and grey lines", "Before you shoot", LC.Text.label)
            typeRow("Mono", "LC.Text.mono · SF Mono 15 medium, every number", "−0.7 EV · 24 mm · 3:2", LC.Text.mono, red: true)
        }
        .background(RoundedRectangle(cornerRadius: LC.Radius.card, style: .continuous).fill(LC.Colour.card))
    }

    private func typeRow(_ name: String, _ token: String, _ sample: String, _ font: Font, red: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(LC.Text.bodyStrong).foregroundStyle(.white)
                Text(token).font(LC.Text.label).foregroundStyle(LC.Colour.secondary)
            }
            .frame(width: 360, alignment: .leading)
            Text(sample).font(font).foregroundStyle(red ? LC.Colour.accentText : .white)
            Spacer()
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    // MARK: Spacing and corners

    private var spacing: some View {
        HStack(alignment: .bottom, spacing: 40) {
            ForEach([("xs", LC.Space.xs), ("s", LC.Space.s), ("sm", LC.Space.sm), ("m", LC.Space.m), ("edge", LC.Space.edge), ("l", LC.Space.l), ("xl", LC.Space.xl), ("xxl", LC.Space.xxl)], id: \.0) { n, v in
                VStack(alignment: .leading, spacing: 10) {
                    Rectangle().fill(LC.Colour.accent.opacity(0.8)).frame(width: v * 4, height: v * 4)
                    Text("\(n) · \(Int(v))").font(LC.Text.bodyStrong).foregroundStyle(.white)
                }
            }
            Spacer()
            Text("4-pt steps. Screen edge 20. Under a screen title 24.\nCloser means belongs: more room above a heading than under it.\nControls: 36 on the picture, 44 to tap, 52 rows and buttons.")
                .font(LC.Text.body).foregroundStyle(LC.Colour.secondary).fixedSize(horizontal: false, vertical: true).frame(width: 380, alignment: .leading)
        }
    }

    private var corners: some View {
        HStack(spacing: 40) {
            ForEach([("Viewfinder", LC.Radius.viewfinder), ("Thumbnail", LC.Radius.thumb), ("Button", LC.Radius.button), ("Card", LC.Radius.card)], id: \.0) { n, r in
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: r, style: .continuous).fill(LC.Colour.card).frame(width: 140, height: 110)
                    Text("\(n) · \(Int(r))").font(LC.Text.bodyStrong).foregroundStyle(.white)
                }
            }
            Spacer()
        }
    }

    // MARK: Components

    private var controls: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .center, spacing: 40) {
                item("Ghost icons in the picture") { GhostBar(state: CameraState()).frame(width: 320).background(Color(white: 0.3)) }
                item("Glass button 36") { GlassButton { Image(systemName: "arrow.triangle.2.circlepath") }.frame(width: LC.Size.pair) }
                item("Notice") { Notice(symbol: "checkmark.circle.fill", text: "Saved to Photos") }
                item("Focus ring") { FocusRing().frame(width: 90, height: 60) }
                item("Switch") { Switch(on: true) }
                item("Price") { PricePill(text: "$19.99") }
            }
            HStack(alignment: .center, spacing: 40) {
                item("Shutter 72, clean white") {
                    ShutterDisc()
                }
                item("Lens pill + flip") {
                    HStack(spacing: LC.Space.l) {
                        GhostBar(state: CameraState())
                    }
                    .padding(10).background(Color(white: 0.3))
                }
                item("Film button") {
                    Image(systemName: "film.stack").font(.system(size: LC.Size.icon, weight: .medium)).foregroundStyle(.white)
                        .frame(width: LC.Size.filmButton.width, height: LC.Size.filmButton.height)
                        .background(RoundedRectangle(cornerRadius: LC.Radius.thumb, style: .continuous).fill(LC.Colour.card))
                        .overlay(alignment: .topTrailing) { Circle().fill(LC.Colour.accent).frame(width: LC.Size.dot, height: LC.Size.dot).offset(x: LC.Space.xs, y: -LC.Space.xs) }
                }
                item("Exposure ruler · faint band") {
                    VStack(spacing: 8) {
                        Text("−0.7 EV").font(LC.Text.mono).foregroundStyle(LC.Colour.accentText)
                        Ruler().frame(width: 360, height: LC.Size.ruler)
                    }
                }
            }
            HStack(spacing: 24) {
                item("Primary button") { WideButton(title: "Continue").frame(width: 300) }
                item("Button in a card") { WideButton(title: "Got it", primary: false).frame(width: 300).padding(16)
                        .background(RoundedRectangle(cornerRadius: LC.Radius.card, style: .continuous).fill(LC.Colour.card)) }
                item("Row") {
                    Card { Row(label: "Grid") { Switch(on: true) }; Row(label: "Format", last: true) { Value(text: "4:3") } }.frame(width: 340)
                }
            }
        }
    }

    private var cans: some View {
        HStack(alignment: .bottom, spacing: 40) {
            ForEach(CanStock.all, id: \.self) { s in
                VStack(spacing: 12) {
                    Canister(stock: s, height: 180)
                    Text("\(s.name) \(s.speed)").font(LC.Text.bodyStrong).foregroundStyle(.white)
                }
            }
            VStack(spacing: 12) {
                SideCan(stock: .portra).scaleEffect(2.4).frame(width: 70, height: 140)
                Text("In the camera").font(LC.Text.bodyStrong).foregroundStyle(.white)
            }
            Spacer()
        }
    }

    private func item<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            c()
            Text(label).font(LC.Text.label).foregroundStyle(LC.Colour.secondary)
        }
    }
}
