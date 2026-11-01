import SwiftUI
import AppKit

/// What Pin loads: Ten's real screens by board id, each with its own store and made-up data, kept in memory only.
@MainActor
enum TenBoards {
    private struct Spec {
        var env = BoardEnv()
        var setup: (TenStore) -> Void = { _ in }
        var content: (TenStore) -> AnyView = { _ in AnyView(RootView()) }
        /// The phone's clock and battery in white, on a black screen.
        var onBlack = false
    }

    private static let sunday = BoardEnv.day(2026, 11, 1)
    private static let wednesday = BoardEnv.day(2026, 10, 28)

    private static func spec(_ board: String) -> Spec {
        switch board {
        // Week
        case "week-today": return Spec()
        case "week-monday-done": return Spec(setup: { Fixtures.done($0, ["upper-a"]) })
        case "week-sunday-still-open":
            return Spec(env: BoardEnv(now: sunday), setup: { Fixtures.done($0, ["upper-b", "lower-b", "upper-c", "lower-c"]) })
        case "week-rest-day-all-done":
            return Spec(env: BoardEnv(now: sunday), setup: { Fixtures.done($0, Fixtures.allWorkouts) })
        // Wednesday's card by making Wednesday today: which day is selected is the view's own.
        case "week-upcoming-day": return Spec(env: BoardEnv(now: wednesday))
        case "week-settings":
            return Spec(env: BoardEnv(now: wednesday), content: { _ in AnyView(WithSheet(top: 415) { RootView() } sheet: { SettingsSheet() }) })
        case "week-unfinished-session":
            return Spec(setup: {
                Fixtures.done($0, ["upper-a"])
                $0.resume = ResumeState(workoutID: "lower-a", index: 3, phase: "work", phaseTotal: 40, completedSteps: 3, elapsed: 310, workSeconds: 120, savedAt: .now)
            })
        // Workout: the app's own debug way in.
        case "workout-today": return Spec(env: BoardEnv(args: ["-preview-detail=3"]))
        case "workout-upcoming-day-locked": return Spec(env: BoardEnv(args: ["-preview-detail=4"]))
        case "workout-exercise-sheet":
            return Spec(env: BoardEnv(args: ["-preview-detail=3"]), content: { _ in
                AnyView(WithSheet(top: BoardMetrics.tallSheetTop) { RootView() } sheet: { Fixtures.exercise("bulgarian-split-squat").map(ExerciseDetailSheet.init) })
            })
        // Player: opened the way the app reopens a stopped session.
        case "player-timed-set": return player("lower-a", elapsed: 1, ticks: 4)
        case "player-reps-set": return player("upper-a", elapsed: 5)
        case "player-paused", "player-end-workout": return player("upper-a", elapsed: 11)
        case "player-end-workout-partial": return player("lower-a", elapsed: 268, done: 1, ticks: 4)
        case "player-rest":
            var rest = player("upper-a", elapsed: 300, phase: "rest", total: 45, done: 1, ticks: 4)
            rest.onBlack = true
            return rest
        case "player-complete", "player-complete-rated":
            return player("upper-a", elapsed: 0, args: ["-preview-summary"])
        // Library
        case "library-all", "library-pull-up-bar-and-back", "library-no-matches":
            return Spec(env: BoardEnv(args: ["-preview-library"]))
        case "library-exercise-sheet": return librarySheet()
        case "library-exercise-sheet-harder":
            return librarySheet(setup: {
                $0.toggleFavorite("pull-up")
                $0.tune("pull-up", by: 1)
            })
        // Progress
        case "progress-empty": return Spec(env: BoardEnv(args: ["-preview-progress"]))
        case "progress-with-history", "progress-history-scrolled":
            return Spec(env: BoardEnv(args: ["-preview-progress"]), setup: { $0.history = Fixtures.longHistory() })
        default: return Spec()
        }
    }

    private static func librarySheet(setup: @escaping (TenStore) -> Void = { _ in }) -> Spec {
        Spec(env: BoardEnv(args: ["-preview-library"]), setup: setup, content: { _ in
            AnyView(WithSheet(top: BoardMetrics.tallSheetTop) { RootView() } sheet: { Fixtures.exercise("pull-up").map(ExerciseDetailSheet.init) })
        })
    }

    private static func player(_ id: String, elapsed: Int, phase: String = "work", total: Int = 0, done: Int = 0, ticks: Int = 0, args: [String] = []) -> Spec {
        Spec(env: BoardEnv(args: args, ticks: TickBudget(ticks)), content: { store in
            guard let workout = store.workout(id: id) else { return AnyView(EmptyView()) }
            let resume = ResumeState(workoutID: id, index: 0, phase: phase, phaseTotal: total, completedSteps: done,
                                     elapsed: elapsed, workSeconds: 0, savedAt: .now)
            return AnyView(PlayerBoard(workout: workout, steps: store.steps(for: workout), resume: resume))
        })
    }

    static func board(_ name: String) -> AnyView {
        let spec = spec(name)
        let screen: AnyView = BoardEnv.$current.withValue(spec.env) {
            let store = TenStore(defaults: MemoryDefaults(), now: spec.env.now)
            spec.setup(store)
            return AnyView(
                spec.content(store)
                    .safeAreaPadding(.top, BoardMetrics.top)
                    .environment(store)
                    .tint(Color.tenInk)
                    .environment(\.colorScheme, .light)
                    .overlay(alignment: .top) { PhoneStatusBar(onBlack: spec.onBlack) }
            )
        }
        return AnyView(BoardScene(env: spec.env, content: screen).frame(width: 402, height: 874).clipped())
    }
}

/// A board that shows a sheet the view opens from its own private state: the real sheet, over the real screen.
private struct WithSheet<Screen: View, Sheet: View>: View {
    let top: CGFloat
    @ViewBuilder let screen: () -> Screen
    @ViewBuilder let sheet: () -> Sheet
    @State private var open = true

    var body: some View {
        screen().boardSheet(isPresented: $open, top: top, content: sheet)
    }
}

/// The player fills the board. When its real Done or End closes it, the app's home is underneath.
private struct PlayerBoard: View {
    let workout: Workout
    let steps: [SessionStep]
    let resume: ResumeState
    @State private var open = true

    var body: some View {
        if open {
            BoardPresented(isOpen: $open) { PlayerView(workout: workout, steps: steps, resume: resume) }
                .safeAreaPadding(.bottom, BoardMetrics.bottom)
        } else {
            RootView()
        }
    }
}

/// The board's own window content: its keyboard shortcuts stay out of Pin, it never takes the keyboard, and everything
/// SwiftUI works out for it happens with this board's pretend date and arguments.
private struct BoardScene: NSViewRepresentable {
    let env: BoardEnv
    let content: AnyView

    final class Host: NSHostingView<AnyView> {
        var env = BoardEnv()
        override var acceptsFirstResponder: Bool { false }
        override func performKeyEquivalent(with event: NSEvent) -> Bool { false }
        override func layout() { BoardEnv.$current.withValue(env) { super.layout() } }
        override func updateConstraints() { BoardEnv.$current.withValue(env) { super.updateConstraints() } }
        override func viewWillDraw() { BoardEnv.$current.withValue(env) { super.viewWillDraw() } }
        override func viewDidMoveToWindow() { BoardEnv.$current.withValue(env) { super.viewDidMoveToWindow() } }
    }

    func makeNSView(context: Context) -> Host {
        let host = Host(rootView: AnyView(EmptyView()))
        host.env = env
        host.sizingOptions = []
        host.appearance = NSAppearance(named: .aqua)
        BoardEnv.$current.withValue(env) { host.rootView = content }
        return host
    }

    func updateNSView(_ host: Host, context: Context) {}
}

/// The phone's top edge, as the design boards draw it.
private struct PhoneStatusBar: View {
    let onBlack: Bool

    var body: some View {
        HStack {
            Text("9:41").font(.system(size: 17, weight: .semibold)).frame(width: 90)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 15, weight: .semibold)).frame(width: 90)
        }
        .foregroundStyle(onBlack ? Color.white : Color.tenInk)
        .padding(.horizontal, 12)
        .frame(height: 54)
        .overlay { Capsule().fill(.black).frame(width: 126, height: 37) }
        .allowsHitTesting(false)
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
