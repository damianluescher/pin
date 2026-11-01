import AppKit
import SwiftUI

/// Pin's one scale. Nothing outside this file picks a size, a gap or a colour.
enum Style {
    static let title = Font.system(size: 22, weight: .semibold)
    static let body = Font.system(size: 15)
    static let strong = Font.system(size: 15, weight: .semibold)
    static let small = Font.system(size: 13)

    static let edge: CGFloat = 24
    static let gap: CGFloat = 16
    static let tight: CGFloat = 8
    static let corner: CGFloat = 12

    static let canvas = Color.black
    static let side = Color(white: 0.09)
    static let raised = Color(white: 0.15)
    static let bubble = Color(white: 0.11)
    static let chosen = Color.white.opacity(0.10)
    static let ink = Color(white: 0.93)
    static let grey = Color(white: 0.93).opacity(0.55)
    static let accent = Color(red: 0.24, green: 0.84, blue: 0.52)
    static let line = Color.white.opacity(0.08)
}

/// The numbered pin on a board and beside its comment.
struct PinDot: View {
    let number: Int
    var chosen = false
    var body: some View {
        Text("\(number)")
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.black)
            .frame(width: 26, height: 26)
            .background(Circle().fill(chosen ? Style.accent : .white))
            .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
    }
}

/// The small round picture of who wrote something.
struct Avatar: View {
    let name: String
    var body: some View {
        Text(String(name.prefix(1)))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(name == "Damian" ? .white : .black)
            .frame(width: 22, height: 22)
            .background(Circle().fill(name == "Damian" ? Color(red: 0.42, green: 0.32, blue: 0.86) : Style.accent))
    }
}

struct PlainPill: ButtonStyle {
    var on = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Style.body.weight(.medium))
            .foregroundStyle(on ? .black : Style.ink)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(on ? Color.white : Style.raised))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

/// A row in a side list, the same everywhere.
struct SideRow: ButtonStyle {
    var chosen = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Style.body)
            .foregroundStyle(Style.ink)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(chosen || configuration.isPressed ? Style.chosen : .clear))
            .contentShape(Rectangle())
    }
}

extension Date {
    var short: String {
        if abs(timeIntervalSinceNow) < 60 { return "now" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: Date())
    }
}
