import SwiftUI
import CoreLocation
@_exported import UserNotifications
@_exported import AppKit
import AppKit

// iPhone-only calls in 10's screens, given a Mac meaning so the same code compiles unchanged.
typealias UIImage = NSImage

extension Image {
    init(uiImage: NSImage) { self.init(nsImage: uiImage) }
}

extension ToolbarPlacement {
    static var navigationBar: ToolbarPlacement { .automatic }
}

enum TenDebug {
    static func start(model: AppModel, repo: Repository) {}
    static func armAlarmSoon(_ alarm: TenAlarm) {}
}

final class UIApplication {
    static let shared = UIApplication()
    static let openSettingsURLString = "x-apple.systempreferences:"
    var isIdleTimerDisabled = false
    func open(_ url: URL) {}
}

final class UIImpactFeedbackGenerator {
    enum Style { case light, medium, heavy }
    init(style: Style) {}
    func impactOccurred() {}
    func prepare() {}
}

final class UINotificationFeedbackGenerator {
    enum FeedbackType { case success, warning, error }
    func notificationOccurred(_ type: FeedbackType) {}
    func prepare() {}
}

/// Exercise clips and pictures come straight from the app's folder.
enum VideoCatalog {
    private static let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("tools/noop2/StrandiOS/Ten/Clips")
    static func clipURL(_ exerciseID: String) -> URL? { existing(exerciseID, "mp4") }
    static func posterURL(_ exerciseID: String) -> URL? { existing(exerciseID, "jpg") }
    private static func existing(_ id: String, _ ext: String) -> URL? {
        let url = folder.appendingPathComponent(id).appendingPathExtension(ext)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

/// The clip's still picture. A board does not need a video running: three of them would make a page lag.
struct TenDemoClip: View {
    let exerciseID: String
    var isPaused = false
    var body: some View { TenPoster(exerciseID: exerciseID) }
}

/// The map, drawn. A board asks no map server for anything and no one for the location, and looks the same every time.
struct TenRouteMap: View {
    let points: [CLLocationCoordinate2D]
    var followsUser = false

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.06)))
            var streets = Path()
            for (from, to) in [((-0.1, 0.1), (1.1, 0.42)), ((-0.1, 0.62), (1.1, 0.34)), ((0.25, -0.1), (0.2, 1.1)), ((0.62, -0.1), (0.56, 1.1)), ((0.9, -0.1), (0.8, 1.1)), ((-0.1, 0.86), (1.1, 1.0))] {
                streets.move(to: CGPoint(x: from.0 * size.width, y: from.1 * size.height))
                streets.addLine(to: CGPoint(x: to.0 * size.width, y: to.1 * size.height))
            }
            context.stroke(streets, with: .color(Color(white: 0.17)), lineWidth: 5)
            let route = points.count >= 2 ? points : Fixtures.route(metres: 4820, secondsPerKm: [332], startMs: 0).map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            guard let south = route.map(\.latitude).min(), let north = route.map(\.latitude).max(),
                  let west = route.map(\.longitude).min(), let east = route.map(\.longitude).max(), north > south, east > west else { return }
            let usable = CGSize(width: size.width * 0.86, height: size.height * 0.5)
            var line = Path()
            for (index, point) in route.enumerated() {
                let spot = CGPoint(x: size.width * 0.07 + usable.width * (point.longitude - west) / (east - west),
                                   y: size.height * 0.14 + usable.height * (north - point.latitude) / (north - south))
                if index == 0 { line.move(to: spot) } else { line.addLine(to: spot) }
            }
            context.stroke(line, with: .color(TenColor.white), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        .accessibilityLabel("Route map")
    }
}

/// Boards never ask for notification permission or schedule anything: this stands in for the system's centre.
final class UNUserNotificationCenter {
    private static let shared = UNUserNotificationCenter()
    static func current() -> UNUserNotificationCenter { shared }
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {}
    func add(_ request: UNNotificationRequest) {}
    func removePendingNotificationRequests(withIdentifiers: [String]) {}
}

extension View {
    /// The Mac has no full-screen cover: on a board it simply fills the board.
    func fullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        overlay { if isPresented.wrappedValue { content() } }
    }

    /// A Mac sheet would open on Pin's window and block the canvas: on a board it comes up inside the board.
    /// The screens close themselves with the system's dismiss, which only works inside something presented: pushing
    /// the content on its own small stack gives it that, and its dismiss pops this stack.
    fileprivate func boardSheet<Item, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)?, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        overlay {
            if let value = item.wrappedValue {
                BoardSheet(close: { item.wrappedValue = nil; onDismiss?() }) {
                    NavigationStack {
                        Color.clear.navigationDestination(isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil; onDismiss?() } })) {
                            content(value)
                        }
                    }
                }
            }
        }
    }
}

// Named by item type: a generic one has the same signature as the system's and the compiler cannot choose.
// That also leaves `sheet(isPresented:)`, used only for Strap's device list: it stays a real Mac sheet with its Done button.
extension View {
    func sheet<Content: View>(item: Binding<Exercise?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Exercise) -> Content) -> some View {
        boardSheet(item: item, onDismiss: onDismiss, content: content)
    }
    func sheet<Content: View>(item: Binding<TenSleepDetailsView.Sheet?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (TenSleepDetailsView.Sheet) -> Content) -> some View {
        boardSheet(item: item, onDismiss: onDismiss, content: content)
    }
}

/// A phone sheet's shape: the screen dimmed behind it, a press there closes it.
private struct BoardSheet<Content: View>: View {
    let close: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.5).onTapGesture(perform: close)
            content()
                .background(TenColor.raised)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
                .padding(.top, 60)
        }
    }
}
