import SwiftUI

/// What Pin loads: LUT Cam's real screens (App/UI) by board name, with made-up state.
@MainActor
public enum LUTCamBoards {
    public struct Board: Sendable {
        public let name: String
        public let page: String
        public let width: CGFloat
        public let height: CGFloat
        public var id: String { name.lowercased().replacingOccurrences(of: " ", with: "-") }
    }

    public static let boards: [Board] = [
        Board(name: "Camera", page: "Camera", width: 393, height: 852),
        Board(name: "Camera quiet", page: "Camera", width: 393, height: 852),
        Board(name: "App icon directions", page: "App icon", width: 1024, height: 540),
    ]

    public static func size(_ name: String) -> CGSize {
        let b = boards.first { $0.name == name || $0.id == name }
        return CGSize(width: b?.width ?? 393, height: b?.height ?? 852)
    }

    public static func board(_ name: String) -> AnyView {
        switch name {
        case "Camera", "camera": AnyView(Phone { CameraScreen(state: CameraState()) })
        case "Camera quiet", "camera-quiet": AnyView(Phone { CameraQuietScreen(state: CameraState()) })
        case "App icon directions", "app-icon-directions": AnyView(AppIconBoard())
        default: AnyView(Text("No board \(name)").foregroundStyle(.white))
        }
    }
}

/// A phone frame for a board: the status bar (9:41) and the home bar, so the screen reads as on the phone.
private struct Phone<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("9:41").font(.system(size: 17, weight: .semibold))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
                .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .frame(height: 54)
            content
            Capsule().fill(.white).frame(width: 140, height: 5).frame(height: 34)
        }
        .frame(width: 393, height: 852)
        .background(LC.Colour.canvas)
        .environment(\.colorScheme, .dark)
    }
}

@_cdecl("pin_board")
public func pinBoard(_ name: UnsafePointer<CChar>) -> UnsafeMutableRawPointer {
    MainActor.assumeIsolated {
        let view = UnsafeMutablePointer<AnyView>.allocate(capacity: 1)
        view.initialize(to: LUTCamBoards.board(String(cString: name)))
        return UnsafeMutableRawPointer(view)
    }
}
