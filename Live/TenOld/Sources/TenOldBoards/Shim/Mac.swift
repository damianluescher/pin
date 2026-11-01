import SwiftUI
import Combine
import AVFoundation
@_exported import UserNotifications
@_exported import AppKit

// iPhone-only calls in Ten's screens, given a Mac meaning so the same code compiles unchanged.

/// What one board pretends about the world. Read while its own screens are worked out, see BoardScene.
struct BoardEnv {
    /// The boards' pretend today: Tuesday of a fixed week, so they look the same on any real day.
    static let tuesday = day(2026, 10, 27)
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Foundation.Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()
    }
    var now = tuesday
    /// The app's own debug launch arguments, per board.
    var args: [String] = []
    /// A player's clock ticks this often, then holds still. Nil: it just runs.
    var ticks: TickBudget?
    @TaskLocal static var current = BoardEnv()
}

final class TickBudget {
    private var left: Int
    init(_ left: Int) { self.left = left }
    func take() -> Bool {
        guard left > 0 else { return false }
        left -= 1
        return true
    }
}

extension Date { static var now: Date { BoardEnv.current.now } }

enum CommandLine { static var arguments: [String] { BoardEnv.current.args } }

/// The player's second hand, which a board can hold still.
enum Timer {
    struct Ticks {
        let every: TimeInterval, loop: RunLoop, mode: RunLoop.Mode
        func autoconnect() -> AnyPublisher<Date, Never> {
            let budget = BoardEnv.current.ticks
            return Foundation.Timer.publish(every: every, on: loop, in: mode).autoconnect()
                .filter { _ in budget?.take() ?? true }.eraseToAnyPublisher()
        }
    }
    static func publish(every: TimeInterval, on loop: RunLoop, in mode: RunLoop.Mode) -> Ticks { Ticks(every: every, loop: loop, mode: mode) }
}

/// iPhone type sizes; the Mac's are smaller.
extension Font {
    static var largeTitle: Font { .system(size: 34) }
    static var title: Font { .system(size: 28) }
    static var title2: Font { .system(size: 22) }
    static var title3: Font { .system(size: 20) }
    static var headline: Font { .system(size: 17, weight: .semibold) }
    static var body: Font { .system(size: 17) }
    static var subheadline: Font { .system(size: 15) }
    static var footnote: Font { .system(size: 13) }
    static var caption: Font { .system(size: 12) }
    static var caption2: Font { .system(size: 11) }
}

typealias UIImage = NSImage
extension Image { init(uiImage: NSImage) { self.init(nsImage: uiImage) } }
extension ToolbarPlacement { static var navigationBar: ToolbarPlacement { .automatic } }

final class UIApplication {
    static let shared = UIApplication()
    var isIdleTimerDisabled = false
}

final class UIImpactFeedbackGenerator {
    enum Style { case light }
    init(style: Style) {}
    func impactOccurred() {}
    func prepare() {}
}

final class UINotificationFeedbackGenerator {
    enum FeedbackType { case success }
    func notificationOccurred(_ type: FeedbackType) {}
    func prepare() {}
}

/// No sound session on a Mac board. The sounds are not in Pin's bundle either, so nothing ever plays.
final class AVAudioSession {
    enum Category { case playback }
    enum Mode { case `default` }
    struct CategoryOptions: OptionSet { let rawValue: Int; static let mixWithOthers = CategoryOptions(rawValue: 1) }
    static func sharedInstance() -> AVAudioSession { AVAudioSession() }
    func setCategory(_ category: Category, mode: Mode, options: CategoryOptions) throws {}
    func setActive(_ active: Bool) throws {}
}

/// Boards never ask for notification permission or schedule anything.
final class UNUserNotificationCenter {
    private static let shared = UNUserNotificationCenter()
    static func current() -> UNUserNotificationCenter { shared }
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {}
    func add(_ request: UNNotificationRequest) {}
    func removePendingNotificationRequests(withIdentifiers: [String]) {}
}

/// Pictures and clips come straight from the app's folder, read only.
enum VideoCatalog {
    private static let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("tools/phone-renew/src/Ten/Clips")
    static func clipURL(_ exerciseID: String) -> URL? { existing(exerciseID, "mp4") }
    static func posterURL(_ exerciseID: String) -> URL? { existing(exerciseID, "jpg") }
    private static func existing(_ id: String, _ ext: String) -> URL? {
        let url = folder.appendingPathComponent(id).appendingPathExtension(ext)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

/// The clip's still picture: a page of running videos would lag.
struct DemoClipView: View {
    let exerciseID: String
    var isPaused = false
    var body: some View { ExerciseThumb(exerciseID: exerciseID) }
}

/// The export button's look with nothing behind it: a board shares nothing.
struct BoardShareLink<Item, Preview, Label: View>: View {
    let label: Label
    init(item: Item, preview: Preview, @ViewBuilder label: () -> Label) { self.label = label() }
    var body: some View { label }
}

// MARK: Things that open inside the board

/// Tells the tab bar to step aside for a sheet or a full-screen screen.
struct BoardHidesTabs: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

/// Inside a small stack of its own, so the screen's real dismiss works: it pops this stack.
struct BoardPresented<Content: View>: View {
    @Binding var isOpen: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            Color.clear.navigationDestination(isPresented: $isOpen, destination: content)
        }
    }
}

extension View {
    /// The Mac has no full-screen cover: it fills the board.
    func fullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        overlay {
            if isPresented.wrappedValue {
                BoardPresented(isOpen: Binding(get: { isPresented.wrappedValue }, set: { isPresented.wrappedValue = $0; if !$0 { onDismiss?() } }), content: content)
                    .safeAreaPadding(.top, BoardMetrics.top).safeAreaPadding(.bottom, BoardMetrics.bottom)
                    .ignoresSafeArea()
                    .preference(key: BoardHidesTabs.self, value: true)
            }
        }
    }

    /// A Mac sheet would open on Pin's window: here it comes up inside the board.
    func boardSheet<Content: View>(isPresented: Binding<Bool>, top: CGFloat, @ViewBuilder content: @escaping () -> Content) -> some View {
        overlay {
            if isPresented.wrappedValue { BoardSheet(isOpen: isPresented, top: top, content: content) }
        }
    }

    func sheet<Content: View>(item: Binding<Exercise?>, @ViewBuilder content: @escaping (Exercise) -> Content) -> some View {
        boardSheet(isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }), top: BoardMetrics.tallSheetTop) {
            if let exercise = item.wrappedValue { content(exercise) }
        }
    }

    func boardToolbar<Items: View>(title: String, @ViewBuilder items: () -> Items) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            ZStack {
                Text(title).font(.headline).foregroundStyle(Color.tenInk).lineLimit(1).padding(.horizontal, 90)
                items()
            }
            .buttonStyle(.plain)
            .frame(height: 60)
            .padding(.horizontal, 12)
            .background(Color.tenField)
        }
    }

    func boardTabItem<Item: View>(@ViewBuilder _ item: () -> Item) -> some View {
        containerValue(\.boardTabItem, AnyView(item()))
    }

    func boardAlert<Actions: View, Message: View>(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> Actions, @ViewBuilder message: () -> Message) -> some View {
        overlay { if isPresented.wrappedValue { BoardAlert(title: title, isOpen: isPresented, addsCancel: false, actions: actions(), message: message()) } }
    }

    /// The phone adds Cancel to an alert whose buttons have none.
    func boardAlertWithCancel<Actions: View, Message: View>(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> Actions, @ViewBuilder message: () -> Message) -> some View {
        overlay { if isPresented.wrappedValue { BoardAlert(title: title, isOpen: isPresented, addsCancel: true, actions: actions(), message: message()) } }
    }
}

enum BoardMetrics {
    static let top: CGFloat = 62, bottom: CGFloat = 35, tabs: CGFloat = 84, tallSheetTop: CGFloat = 62
}

/// A phone sheet's shape: the screen dimmed behind it, a press there closes it.
struct BoardSheet<Content: View>: View {
    @Binding var isOpen: Bool
    let top: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.25).onTapGesture { isOpen = false }
            BoardPresented(isOpen: $isOpen, content: content)
                .background(Color.tenField)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34))
                .padding(.top, top)
        }
        .ignoresSafeArea()
        .preference(key: BoardHidesTabs.self, value: true)
    }
}

enum BoardPlacement { case topBarLeading, confirmationAction }

struct BoardToolbarItem<Content: View>: View {
    let placement: BoardPlacement
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, placement == .confirmationAction ? 12 : 0)
            .background(Capsule().fill(Color.tenCard))
            .foregroundStyle(Color.tenInk)
            .frame(maxWidth: .infinity, alignment: placement == .topBarLeading ? .leading : .trailing)
    }
}

extension ContainerValues { @Entry var boardTabItem: AnyView? = nil }

/// The phone's floating tab bar, standing in for the Mac's TabView. Pages stay alive under each other, as on the phone.
struct BoardTabView<Content: View>: View {
    @Binding var selection: Int
    @ViewBuilder let content: () -> Content
    @State private var tabsHidden = false

    init(selection: Binding<Int>, @ViewBuilder content: @escaping () -> Content) {
        _selection = selection
        self.content = content
    }

    var body: some View {
        Group(subviews: content()) { pages in
            ZStack {
                ForEach(pages) { page in
                    let shown = page.containerValues.tag(for: Int.self) == selection
                    page.opacity(shown ? 1 : 0).allowsHitTesting(shown)
                }
            }
            .safeAreaPadding(.bottom, BoardMetrics.tabs)
            .onPreferenceChange(BoardHidesTabs.self) { tabsHidden = $0 }
            .overlay(alignment: .bottom) {
                if !tabsHidden {
                    HStack(spacing: 0) {
                        ForEach(pages) { page in
                            let tag = page.containerValues.tag(for: Int.self) ?? 0
                            Button { selection = tag } label: {
                                page.containerValues.boardTabItem
                                    .labelStyle(BoardTabLabel())
                                    .frame(width: 86, height: 50)
                                    .background(Capsule().fill(tag == selection ? Color.tenField : .clear))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .foregroundStyle(Color.tenInk)
                    .padding(4)
                    .background(Capsule().fill(Color.tenCard).shadow(color: .black.opacity(0.08), radius: 10, y: 2))
                    .padding(.bottom, 21)
                }
            }
        }
    }
}

private struct BoardTabLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 3) {
            configuration.icon.font(.system(size: 18, weight: .medium)).symbolVariant(.fill)
            configuration.title.font(.system(size: 10, weight: .semibold))
        }
    }
}

/// The phone's alert, inside the board.
struct BoardAlert<Actions: View, Message: View>: View {
    let title: String
    @Binding var isOpen: Bool
    let addsCancel: Bool
    let actions: Actions
    let message: Message

    /// As on the phone, a press closes the alert, unless the button's own action already did.
    private func close() { DispatchQueue.main.async { if isOpen { isOpen = false } } }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(Color.tenInk)
                    message.font(.subheadline).foregroundStyle(.secondary)
                }
                Group(subviews: actions) { buttons in
                    if addsCancel {
                        VStack(spacing: 8) {
                            ForEach(buttons) { $0 }
                            Button("Cancel", role: .cancel) {}
                        }
                    } else {
                        HStack(spacing: 8) { ForEach(buttons.reversed()) { $0 } }
                    }
                }
                .buttonStyle(BoardAlertButton())
                .simultaneousGesture(TapGesture().onEnded { close() })
            }
            .padding(20)
            .frame(width: 320)
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color.tenCard))
        }
        .ignoresSafeArea()
    }
}

private struct BoardAlertButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(configuration.role == .destructive ? Color.red : Color.tenInk)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Capsule().fill(Color.tenField))
            .contentShape(Capsule())
    }
}
