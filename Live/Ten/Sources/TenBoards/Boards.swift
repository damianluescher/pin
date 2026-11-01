import SwiftUI

/// What Pin loads: the app's live screens by name, with the objects they expect around them.
@MainActor
public enum TenBoards {
    public static let names = ["Today", "Sleep", "Train", "Settings"]

    private static let model = AppModel()
    private static let repo = Repository()
    private static let profile = ProfileStore()
    private static let shell = TenShell()
    private static let alarm = TenAlarm()
    private static let session = TenSession()
    private static let health = HealthKitBridge()
    private static let store = TenStore()

    public static func board(_ name: String) -> AnyView {
        let screen: AnyView
        switch name {
        case "Sleep": screen = AnyView(TenSleepView())
        case "Train": screen = AnyView(TenTrainView())
        case "Settings": screen = AnyView(TenSettingsRootView())
        default: screen = AnyView(TenTodayView())
        }
        return AnyView(
            screen
                .environmentObject(model).environmentObject(model.live).environmentObject(repo)
                .environmentObject(profile).environmentObject(shell).environmentObject(alarm)
                .environmentObject(session).environmentObject(health).environment(store)
                .overlay(alignment: .bottom) {
                    TenTabBar(selection: .constant(TenShell.Tab.allCases.first { $0.title == name } ?? .today))
                        .padding(.bottom, TenTabBarMetrics.bottom)
                }
                .preferredColorScheme(.dark).tint(TenColor.white)
                .frame(width: 393, height: 852)
                .background(TenColor.black)
                .clipped()
        )
    }
}

/// Pin's way in: a live board by name, as a pointer to its view. Pin owns the pointer afterwards.
@_cdecl("pin_board")
public func pinBoard(_ name: UnsafePointer<CChar>) -> UnsafeMutableRawPointer {
    MainActor.assumeIsolated {
        let view = UnsafeMutablePointer<AnyView>.allocate(capacity: 1)
        view.initialize(to: TenBoards.board(String(cString: name)))
        return UnsafeMutableRawPointer(view)
    }
}
