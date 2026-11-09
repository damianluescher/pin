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
        Board(name: "Icon options", page: "App icon", width: 1100, height: 880),
        Board(name: "Guidelines", page: "Guidelines", width: 1200, height: 3480),
        Board(name: "Camera", page: "Camera", width: 393, height: 852),
        Board(name: "Look picker", page: "Camera", width: 393, height: 852),
        Board(name: "Format 6x6", page: "Camera", width: 393, height: 852),
        Board(name: "Format XPan", page: "Camera", width: 393, height: 852),
        Board(name: "Exposure", page: "Camera", width: 393, height: 852),
        Board(name: "Grid", page: "Camera", width: 393, height: 852),
        Board(name: "Histogram and zebras", page: "Camera", width: 393, height: 852),
        Board(name: "Focus lock", page: "Camera", width: 393, height: 852),
        Board(name: "Lenses", page: "Camera", width: 393, height: 852),
        Board(name: "Lens without unprocessed", page: "Camera", width: 393, height: 852),
        Board(name: "Flash on", page: "Camera", width: 393, height: 852),
        Board(name: "Saving", page: "Camera", width: 393, height: 852),
        Board(name: "Saved", page: "Camera", width: 393, height: 852),
        Board(name: "Warnings", page: "Camera", width: 393, height: 852),
        Board(name: "Landscape", page: "Camera", width: 852, height: 393),
        Board(name: "Welcome", page: "First open", width: 393, height: 852),
        Board(name: "Permissions", page: "First open", width: 393, height: 852),
        Board(name: "Permissions done", page: "First open", width: 393, height: 852),
        Board(name: "How it works", page: "First open", width: 393, height: 852),
        Board(name: "Camera not allowed", page: "First open", width: 393, height: 852),
        Board(name: "Photos not allowed", page: "First open", width: 393, height: 852),
        Board(name: "Edit look", page: "After the shot", width: 393, height: 852),
        Board(name: "Edit exposure", page: "After the shot", width: 393, height: 852),
        Board(name: "Edit white balance", page: "After the shot", width: 393, height: 852),
        Board(name: "Edit format", page: "After the shot", width: 393, height: 852),
        Board(name: "Quick review", page: "After the shot", width: 393, height: 852),
        Board(name: "Gallery", page: "After the shot", width: 393, height: 852),
        Board(name: "Gallery empty", page: "After the shot", width: 393, height: 852),
        Board(name: "Photo", page: "After the shot", width: 393, height: 852),
        Board(name: "Photo held (unprocessed)", page: "After the shot", width: 393, height: 852),
        Board(name: "Photo info", page: "After the shot", width: 393, height: 852),
        Board(name: "Looks", page: "Looks and settings", width: 393, height: 852),
        Board(name: "Settings", page: "Looks and settings", width: 393, height: 852),
        Board(name: "Unlock", page: "Unlock", width: 393, height: 852),
        Board(name: "Lock Screen", page: "Outside the app", width: 393, height: 852),
        Board(name: "Camera Control", page: "Outside the app", width: 393, height: 852),
    ]

    /// Pictures and Pin's canvas cannot draw Liquid Glass: use the plain fill.
    public static func stillRender() { LCGlass.real = false }

    public static func size(_ name: String) -> CGSize {
        let b = boards.first { $0.name == name || $0.id == name }
        return CGSize(width: b?.width ?? 393, height: b?.height ?? 852)
    }

    public static func board(_ name: String) -> AnyView {
        let n = boards.first { $0.name == name || $0.id == name }?.name ?? name
        switch n {
        case "Icon options": return AnyView(IconOptionsBoard().environment(\.colorScheme, .dark))
        case "Guidelines": return AnyView(GuidelinesBoard().environment(\.colorScheme, .dark))
        case "Camera": return AnyView(Phone { CameraScreen(state: CameraState()) })
        case "Look picker": return AnyView(Phone { LookPickerState() })
        case "Format 6x6": return AnyView(Phone { FormatState(format: .square) })
        case "Format XPan": return AnyView(Phone { FormatState(format: .pano) })
        case "Exposure": return AnyView(Phone { ExposureState() })
        case "Grid": return AnyView(Phone { GridState() })
        case "Histogram and zebras": return AnyView(Phone { ExposureAidsState() })
        case "Focus lock": return AnyView(Phone { FocusLockState() })
        case "Lenses": return AnyView(Phone { LensState() })
        case "Lens without unprocessed": return AnyView(Phone { LensState(noRaw: true) })
        case "Flash on": return AnyView(Phone { FlashState() })
        case "Saving": return AnyView(Phone { ShotState() })
        case "Saved": return AnyView(Phone { ShotState(saved: true) })
        case "Warnings": return AnyView(Phone { WarningState() })
        case "Landscape": return AnyView(LandscapeCameraScreen().environment(\.colorScheme, .dark))
        case "Welcome": return AnyView(Phone { WelcomeScreen() })
        case "Permissions": return AnyView(Phone { PermissionsScreen(allowed: 1) })
        case "Permissions done": return AnyView(Phone { PermissionsScreen(allowed: 3) })
        case "How it works": return AnyView(Phone { HowItWorksScreen() })
        case "Camera not allowed": return AnyView(Phone { DeniedScreen() })
        case "Photos not allowed": return AnyView(Phone { DeniedScreen(photos: true) })
        case "Edit look": return AnyView(Phone { PhotoEditBoard(tool: .look) })
        case "Edit exposure": return AnyView(Phone { PhotoEditBoard(tool: .exposure) })
        case "Edit white balance": return AnyView(Phone { PhotoEditBoard(tool: .white) })
        case "Edit format": return AnyView(Phone { PhotoEditBoard(tool: .format) })
        case "Quick review": return AnyView(Phone { QuickReviewScreen() })
        case "Gallery": return AnyView(Phone { GalleryScreen() })
        case "Gallery empty": return AnyView(Phone { GalleryScreen(empty: true) })
        case "Photo": return AnyView(Phone { PhotoViewScreen() })
        case "Photo held (unprocessed)": return AnyView(Phone { PhotoViewScreen(holding: true) })
        case "Photo info": return AnyView(Phone { PhotoInfoScreen() })
        case "Looks": return AnyView(Phone { MyLooksScreen() })
        case "Settings": return AnyView(Phone { SettingsScreen() })
        case "Unlock": return AnyView(Phone { UnlockScreen() })
        case "Lock Screen": return AnyView(LockScreenBoard().environment(\.colorScheme, .dark))
        case "Camera Control": return AnyView(Phone { CameraControlState() })
        default: return AnyView(Text("No board \(name)").foregroundStyle(.white))
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
        LCGlass.real = false
        let view = UnsafeMutablePointer<AnyView>.allocate(capacity: 1)
        view.initialize(to: LUTCamBoards.board(String(cString: name)))
        return UnsafeMutableRawPointer(view)
    }
}

// A mock of the iPhone Lock Screen (system UI, drawn with iOS's own sizes; not part of the app).
/// 24. Outside the app: the Lock Screen camera button opens LUT Cam; the Camera Control button changes exposure.
struct LockScreenBoard: View {
    var body: some View {
        ZStack {
            Fill(image: Sample.photo(5)).overlay(Color.black.opacity(0.25))
            VStack(spacing: 0) {
                Text("Monday 9 November").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white).padding(.top, 70)
                Text("9:41").font(.system(size: 96, weight: .bold)).foregroundStyle(.white)
                Spacer()
                HStack {
                    lockButton("flashlight.off.fill")
                    Spacer()
                    ZStack {
                        Circle().fill(Color.black.opacity(0.35)).frame(width: 50, height: 50)
                        Image(systemName: "camera.aperture").font(.system(size: 22, weight: .medium)).foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 44)
                .padding(.bottom, 44)
            }
        }
        .frame(width: 393, height: 852)
        .clipped()
    }
    private func lockButton(_ s: String) -> some View {
        Image(systemName: s).font(.system(size: 20)).foregroundStyle(.white).frame(width: 50, height: 50).background(Circle().fill(Color.black.opacity(0.35)))
    }
}

// For LUTCamProbe cans: every film stock's flat 4Roll drawing without the light (the 3D render lights it).
extension LUTCamBoards {
    @MainActor public static var flatCans: [(String, AnyView)] {
        [("pure", CanStock.pure), ("portra", .portra), ("gold", .gold), ("ektar", .ektar), ("vision", .vision)]
            .map { ($0.0, AnyView(Canister(stock: $0.1, flat: true))) }
    }
}
