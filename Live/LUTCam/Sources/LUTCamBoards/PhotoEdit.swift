import SwiftUI

/// Design for a small editor in the photo view (Damian, Pin 9 Nov: "rather than just having the ability to choose the
/// look it should have a small built in editor for exposure wb and format"). The kept unprocessed file is developed
/// again with the new exposure and white balance BEFORE the film look, like in a darkroom; format re-crops.
/// Board only until Damian says yes; then it moves into the app.
enum EditTool: String, CaseIterable { case look = "Look", exposure = "Exposure", white = "White balance", format = "Format" }

struct PhotoEditBoard: View {
    var tool: EditTool = .exposure

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Cancel").font(LC.Text.body).foregroundStyle(LC.Colour.secondary)
                Spacer()
                Text("Edit").font(LC.Text.bodyStrong).foregroundStyle(LC.Colour.primary)
                Spacer()
                Text("Save").font(LC.Text.bodyStrong).foregroundStyle(LC.Colour.primary)
            }
            .padding(.top, LC.Space.s)
            picture.padding(.top, LC.Space.m)
            control.frame(height: 120).padding(.top, LC.Space.l)
            Spacer(minLength: 0)
            tabs.padding(.bottom, LC.Space.m)
        }
        .padding(.horizontal, LC.Space.edge)
        .background(LC.Colour.canvas)
    }

    private var picture: some View {
        ZStack {
            Fill(image: LCArt.image(.viewfinder))
                .look(Look.named("portra-400"))
                .brightness(tool == .exposure ? 0.06 : 0)
                .colorMultiply(tool == .white ? Color(red: 1, green: 0.94, blue: 0.86) : .white)
            if tool == .format { FormatMask(ratio: 2.0 / 3.0) }
        }
        .frame(height: 470)
        .clipShape(RoundedRectangle(cornerRadius: LC.Radius.viewfinder, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text("Portra 400").font(LC.Text.label).foregroundStyle(.white)
                .padding(.horizontal, LC.Space.s).frame(height: 26)
                .background(Capsule().fill(Color.black.opacity(0.5))).padding(LC.Space.m)
        }
    }

    @ViewBuilder private var control: some View {
        switch tool {
        case .look:
            CanCarousel(selected: 1, withUnprocessed: true)
        case .exposure:
            dial(value: "+0.4 EV", note: "From the unprocessed file, before the look")
        case .white:
            VStack(spacing: LC.Space.m) {
                dial(value: "5 600 K", note: nil)
                HStack {
                    Text("Tint").font(LC.Text.label).foregroundStyle(LC.Colour.secondary)
                    Spacer()
                    Text("+4").font(LC.Text.mono).foregroundStyle(LC.Colour.primary)
                }
                HStack(spacing: LC.Space.s) {
                    chip("As shot", on: false); chip("Daylight", on: true); chip("Cloudy", on: false); chip("Tungsten", on: false)
                }
            }
        case .format:
            VStack(spacing: LC.Space.m) {
                HStack(spacing: LC.Space.xs) {
                    ForEach(FilmFormat.allCases, id: \.self) { f in chip(f.rawValue, on: f == .f35) }
                }
                Text("Drag the picture to place the crop").font(LC.Text.label).foregroundStyle(LC.Colour.secondary)
            }
        }
    }

    private func dial(value: String, note: String?) -> some View {
        VStack(spacing: LC.Space.s) {
            Text(value).font(LC.Text.mono).foregroundStyle(LC.Colour.accent)
            Ruler().frame(height: LC.Size.ruler)
            if let note { Text(note).font(LC.Text.label).foregroundStyle(LC.Colour.secondary) }
        }
    }

    private func chip(_ t: String, on: Bool) -> some View {
        Text(t).font(LC.Text.label).lineLimit(1).fixedSize()
            .foregroundStyle(on ? Color.black : LC.Colour.primary)
            .padding(.horizontal, LC.Space.s + 2).frame(height: 32)
            .background(Capsule().fill(on ? Color.white : LC.Colour.card))
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(EditTool.allCases, id: \.self) { t in
                VStack(spacing: 6) {
                    Image(systemName: icon(t)).font(.system(size: 20, weight: .medium))
                    Text(t.rawValue).font(LC.Text.label).lineLimit(1).fixedSize()
                }
                .foregroundStyle(t == tool ? LC.Colour.primary : LC.Colour.secondary)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) {
                    if t == tool { Circle().fill(LC.Colour.accent).frame(width: 5, height: 5).offset(y: -10) }
                }
            }
        }
        .frame(height: 64)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LC.Colour.card))
    }

    private func icon(_ t: EditTool) -> String {
        switch t {
        case .look: "camera.filters"
        case .exposure: "plusminus.circle"
        case .white: "thermometer.sun"
        case .format: "crop"
        }
    }
}

/// The editor directly in the photo page (Damian, Pin 10 Nov on Edit look: "it should be directly in this edit
/// page"): no separate Edit page and no Cancel/Save. Under the picture four small tabs; Look shows the cans, the
/// others their dial. Every change is kept at once and can be changed again later (the unprocessed file stays).
struct PhotoEditInline: View {
    var tool: EditTool = .look

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RoundIcon(symbol: "chevron.left")
                Spacer()
                Text(tool == .look ? "Portra 400" : tool.rawValue).font(LC.Text.bodyStrong).foregroundStyle(LC.Colour.primary)
                Spacer()
                RoundIcon(symbol: "info")
            }
            ZStack {
                Fill(image: LCArt.image(.viewfinder))
                    .look(Look.named("portra-400"))
                    .brightness(tool == .exposure ? 0.06 : 0)
                    .colorMultiply(tool == .white ? Color(red: 1, green: 0.94, blue: 0.86) : .white)
                if tool == .format { FormatMask(ratio: 2.0 / 3.0) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: LC.Radius.viewfinder, style: .continuous))
            .padding(.top, LC.Space.m)
            control.frame(height: 150).padding(.top, LC.Space.l)
            tabs.padding(.top, LC.Space.m)
            HStack {
                RoundIcon(symbol: "square.and.arrow.up")
                Spacer()
                RoundIcon(symbol: "arrow.down.doc")
                Spacer()
                RoundIcon(symbol: "trash")
            }
            .padding(.horizontal, LC.Space.l)
            .padding(.vertical, LC.Space.m)
        }
        .padding(.horizontal, LC.Space.edge)
        .background(LC.Colour.canvas)
    }

    @ViewBuilder private var control: some View {
        switch tool {
        case .look: CanCarousel(selected: 1, withUnprocessed: true, spacing: LC.Space.m)
        case .exposure: dial("+0.4 EV")
        case .white: dial("5 600 K")
        case .format:
            HStack(spacing: LC.Space.xs) {
                ForEach(FilmFormat.allCases, id: \.self) { f in
                    Text(f.rawValue).font(LC.Text.mono).lineLimit(1).fixedSize()
                        .foregroundStyle(f == .f35 ? Color.black : LC.Colour.primary)
                        .padding(.horizontal, LC.Space.pill).frame(height: LC.Size.pair)
                        .background(Capsule().fill(f == .f35 ? Color.white : .clear))
                }
            }
        }
    }

    private func dial(_ value: String) -> some View {
        VStack(spacing: LC.Space.s) {
            Text(value).font(LC.Text.label.monospacedDigit()).foregroundStyle(LC.Colour.accentText)
            Ruler().frame(height: LC.Size.ruler)
        }
    }

    /// Four small text tabs, the chosen one white with a red dot under it.
    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(EditTool.allCases, id: \.self) { t in
                VStack(spacing: LC.Space.xs) {
                    Text(t == .white ? "WB" : t.rawValue).font(LC.Text.label)
                        .foregroundStyle(t == tool ? LC.Colour.primary : LC.Colour.secondary)
                    Circle().fill(t == tool ? LC.Colour.accent : .clear).frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity, minHeight: LC.Size.control)
            }
        }
    }
}
