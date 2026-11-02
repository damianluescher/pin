import SwiftUI
import CoreLocation
import WhoopStore

/// What Pin loads: the app's real screens by name, each in its own state with its own objects, so no board can
/// change another. Only the data is made up (Shim/Fixtures.swift).
@MainActor
public enum TenBoards {
    /// Every state, by the name live.json uses. The height is the board's own when it is not a plain phone screen.
    public static func height(_ name: String) -> CGFloat { name == "Saved run" ? 1105 : 852 }

    public static func board(_ name: String) -> AnyView {
        let world = BoardWorld()
        let (screen, tab) = world.state(name)
        let height = height(name)
        // Starting a workout from a board needs these, as the app does at its root. A board that shows a session
        // already has its screen, and asking now would open that session a second time.
        let startsSessions = world.model.activeWorkout == nil
        if startsSessions { world.session.attach(model: world.model, repo: world.repo, health: world.health, store: world.store) }
        if let tab { world.shell.tab = tab }
        return AnyView(
            BoardFrame(screen: screen, home: tab, startsSessions: startsSessions, shell: world.shell, session: world.session)
                .environmentObject(world.model).environmentObject(world.model.live).environmentObject(world.repo)
                .environmentObject(world.profile).environmentObject(world.shell).environmentObject(world.alarm)
                .environmentObject(world.session).environmentObject(world.health).environment(world.store)
                .defaultAppStorage(BoardWorld.settings)
                .overlay(alignment: .top) { PhoneStatusBar() }
                .preferredColorScheme(.dark).tint(TenColor.white)
                .frame(width: 393, height: height)
                .background(TenColor.black)
                .clipped()
        )
    }
}

/// What the app's root does around a board: the tab bar really switches tab, each tab keeps its place under the others,
/// and a started workout covers the board. Its own screen stands in for its tab's first page; the other tabs start when
/// first opened, so a board holds no extra screens until they are pressed.
private struct BoardFrame: View {
    let screen: AnyView
    let home: TenShell.Tab?
    let startsSessions: Bool
    @ObservedObject var shell: TenShell
    @ObservedObject var session: TenSession
    @State private var opened: Set<TenShell.Tab> = []

    var body: some View {
        Group {
            if let home {
                ZStack {
                    TenColor.black
                    ForEach(TenShell.Tab.allCases) { tab in
                        if tab == home || tab == shell.tab || opened.contains(tab) {
                            page(tab, home: home)
                                .opacity(tab == shell.tab ? 1 : 0)
                                .allowsHitTesting(tab == shell.tab)
                                .safeAreaPadding(.top, TenLayout.headerTop)
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if shell.tabBarHiders == 0 {
                        TenTabBar(selection: $shell.tab).padding(.bottom, TenTabBarMetrics.bottom)
                    }
                }
                .onChange(of: shell.tab) { _, tab in opened.insert(tab) }
            } else {
                screen.safeAreaPadding(.top, TenLayout.headerTop)
            }
        }
        .fullScreenCover(isPresented: startsSessions ? $session.isPresented : .constant(false)) {
            TenSessionScreen()
        }
    }

    @ViewBuilder private func page(_ tab: TenShell.Tab, home: TenShell.Tab) -> some View {
        if tab == home {
            screen
        } else {
            switch tab {
            case .today: TenTodayView()
            case .sleep: TenSleepView()
            case .train: TenTrainView()
            case .settings: TenSettingsRootView()
            }
        }
    }
}

/// One board's objects and data.
@MainActor
private final class BoardWorld {
    /// The few settings the screens read straight from storage, kept apart from anything else in Pin.
    static let settings: UserDefaults = {
        let defaults = UserDefaults(suiteName: "ch.yoveo.pin.tenboards") ?? .standard
        defaults.set(true, forKey: StrapHold.movedKey)
        defaults.set(WhoopModel.whoop5mg.rawValue, forKey: "selectedWhoopModel")
        return defaults
    }()
    private static let sharedProfile = ProfileStore()

    let model = AppModel()
    let repo = Repository()
    let shell = TenShell()
    let alarm = TenAlarm(defaults: MemoryDefaults())
    let session = TenSession()
    let health = HealthKitBridge()
    let store = TenStore(defaults: MemoryDefaults())
    var profile: ProfileStore { Self.sharedProfile }
    /// The player's clock runs until it reads what the board shows, then this stops it.
    private var holding: Task<Void, Never>?

    init() {
        alarm.isOn = true
        alarm.minutes = 7 * 60
        trainWeek(Fixtures.weekHistory())
    }

    private func trainWeek(_ history: [SessionLog]) {
        let monday = PlanCalendar.monday(of: .now, calendar: .current)
        store.history = history
        store.plan = PlanState(weekStart: monday, waveWeek: 0, streakStart: Calendar.current.date(byAdding: .day, value: -7, to: monday))
    }

    private func running(_ sport: String, seconds: TimeInterval, bpm: Int, strain: Double? = nil, avgHr: Int = 0) {
        var workout = AppModel.ActiveWorkout(start: Date().addingTimeInterval(-seconds), sport: sport)
        workout.heldElapsed = seconds
        if let strain { workout.liveStrain = Fixtures.effort(strain) }
        workout.avgHr = avgHr
        model.activeWorkout = workout
        model.bpm = bpm
    }

    /// The player opened the way the app reopens a running session, at one step, then held still.
    private func player(_ workoutID: String, seconds: TimeInterval, bpm: Int, resting: Bool = false, shows: Int? = nil,
                        step: (SessionStep) -> Bool) -> AnyView {
        guard let workout = store.workout(id: workoutID) else { return AnyView(EmptyView()) }
        let steps = store.steps(for: workout)
        let index = steps.firstIndex(where: step) ?? 0
        running(TenSession.planSport, seconds: seconds, bpm: bpm)
        store.resume = ResumeState(workoutID: workoutID, index: resting ? max(index - 1, 0) : index, phase: resting ? "rest" : "work",
                                   phaseTotal: (shows ?? 0) + 1, completedSteps: index, elapsed: Int(seconds), workSeconds: 0, savedAt: .now)
        session.attach(model: model, repo: repo, health: health, store: store)
        if let engine = session.engine {
            holding = Task { [engine] in
                while !Task.isCancelled, engine.elapsed == 0 || engine.remaining > (shows ?? engine.remaining) {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                engine.stop()
            }
        }
        return AnyView(TenSessionScreen())
    }

    private func scores<Content: View>(@ViewBuilder _ content: @escaping (TenDayScores) -> Content) -> AnyView {
        let repo = repo, profile = profile, day = TenDay()
        return AnyView(Loaded(load: { await TenScoreLoader.load(day: day, repo: repo, profile: profile) }, content: content))
    }

    private func healthScreen(off: Bool) -> AnyView {
        repo.vitalsOff = off
        return AnyView(TenHealthView(summary: TenVitalsLoader.summary(day: TenDay(), repo: repo, temperatureUnit: .celsius)))
    }

    private func alarmScreen(smart: Bool) -> AnyView {
        // A 23:00 bedtime puts a cycle end at 06:45, the wake time the boards show.
        repo.sleeps = Fixtures.sleeps(bedAt: (23, 0))
        alarm.smart = smart
        alarm.attach(model: model, repo: repo)
        return AnyView(TenAlarmView())
    }

    func state(_ name: String) -> (screen: AnyView, tab: TenShell.Tab?) {
        repo.workouts = Fixtures.weekRows()
        switch name {
        // Today
        case "Today", "Today good": return (AnyView(TenTodayView()), .today)
        case "Today ok":
            repo.days = Fixtures.days(recovery: 52)
            return (AnyView(TenTodayView()), .today)
        case "Today low":
            repo.days = Fixtures.days(recovery: 28)
            repo.vitalsOff = true
            return (AnyView(TenTodayView()), .today)
        case "Today day before": return (AnyView(TenTodayView(day: TenDay(offset: 1))), .today)
        case "Today workout running":
            running("Lower A", seconds: 760, bpm: 148)
            return (AnyView(TenTodayView()), .today)
        case "Today syncing":
            model.live.backfilling = true
            model.live.syncChunksThisSession = 12
            shell.syncShown = true
            return (AnyView(TenTodayView()), .today)
        case "Today strap not connected":
            model.live.connected = false
            return (AnyView(TenTodayView()), .today)
        case "Recovery": return (scores { TenRecoveryView(day: TenDay(), scores: $0) }, .today)
        case "Strain":
            let start = Int(Date().timeIntervalSince1970) - 60
            repo.workouts = [WorkoutRow(startTs: start, endTs: start + 1560, sport: TenSession.planSport, source: "my-whoop", durationS: 1560, energyKcal: 280,
                                        avgHr: 148, maxHr: 170, strain: Fixtures.effort(6.2), distanceM: nil, zonesJSON: nil, notes: nil, steps: nil)]
            return (scores { TenStrainView(day: TenDay(), scores: $0) }, .today)
        case "Stress":
            repo.heartRate = Fixtures.heartRateDay()
            return (scores { TenStressView(day: TenDay(), scores: $0) }, .today)
        case "Health all in range": return (healthScreen(off: false), .today)
        case "Health something off": return (healthScreen(off: true), .today)
        // Sleep
        case "Sleep": return (AnyView(TenSleepView()), .sleep)
        case "Sleep night before":
            // With nothing recorded last night, the real page opens on the night before by itself.
            repo.days = Fixtures.days().dropLast()
            repo.sleeps = Fixtures.sleeps(onlyYesterday: true)
            return (AnyView(TenSleepView()), .sleep)
        case "Sleep details":
            let repo = repo, day = TenDay()
            return (AnyView(Loaded(load: {
                let night = await TenSleepLoader.night(day: day, repo: repo)
                return (night, await TenSleepLoader.numbers(day: day, night: night, repo: repo))
            }, content: { (loaded: (TenNight, TenSleepNumbers)) in
                TenSleepDetailsView(day: day, numbers: loaded.1, night: loaded.0)
            })), .sleep)
        case "Alarm smart": return (alarmScreen(smart: true), .sleep)
        case "Alarm normal": return (alarmScreen(smart: false), .sleep)
        // Train
        case "Train": return (AnyView(TenTrainView()), .train)
        case "Train done":
            let start = Int(Date().timeIntervalSince1970) - 7200
            repo.workouts.append(WorkoutRow(startTs: start, endTs: start + 1560, sport: TenSession.planSport, source: "my-whoop", durationS: 1560, energyKcal: 280,
                                            avgHr: 148, maxHr: 170, strain: Fixtures.effort(11.2), distanceM: nil, zonesJSON: nil, notes: nil, steps: nil))
            trainWeek([Fixtures.log("lower-a", "Lower A", date: .now, startTs: start)] + Fixtures.weekHistory().dropLast())
            return (AnyView(TenTrainView()), .train)
        case "Workout":
            guard let workout = store.workout(id: "lower-a") else { break }
            return (AnyView(TenWorkoutDetailView(workout: workout, canStart: true)), nil)
        case "Player timed":
            return (player("lower-a", seconds: 761, bpm: 148, shows: 36) { $0.exerciseID == "bulgarian-split-squat" && $0.position == 2 && $0.side == .left }, nil)
        case "Player reps":
            return (player("upper-a", seconds: 192, bpm: 131) { $0.exerciseID == "pull-up" && $0.position == 1 }, nil)
        case "Player strap lost":
            model.live.connected = false
            return (player("lower-a", seconds: 761, bpm: 148, shows: 36) { $0.exerciseID == "bulgarian-split-squat" && $0.position == 2 && $0.side == .left }, nil)
        case "Rest":
            return (player("lower-a", seconds: 761, bpm: 122, resting: true, shows: 41) { $0.exerciseID == "bulgarian-split-squat" && $0.position == 2 && $0.side == .left }, nil)
        case "Workout saved":
            let log = Fixtures.log("lower-a", "Lower A", date: .now)
            store.log(log)
            let start = Int(Date().timeIntervalSince1970) - 1560
            let row = WorkoutRow(startTs: start, endTs: start + 1560, sport: TenSession.planSport, source: "my-whoop", durationS: 1560, energyKcal: 280, avgHr: 148,
                                 maxHr: 170, strain: Fixtures.effort(11.2), distanceM: nil, zonesJSON: nil, notes: nil, steps: nil)
            return (AnyView(TenWorkoutSavedView(finished: TenFinishedWorkout(title: "Lower A", row: row, zoneSeconds: Fixtures.zoneSeconds, logID: log.id, isRun: false))), nil)
        case "Other workout":
            running("Cycling", seconds: 1214, bpm: 157, strain: 6.8, avgHr: 146)
            model.activeWorkout?.samples = Fixtures.samples(bpm: 146, seconds: 1214)
            return (AnyView(TenOtherSessionView(sport: "Cycling")), nil)
        case "Running":
            running(TenSession.runSport, seconds: 1600, bpm: 151, strain: 6.1)
            feedRoute(metres: 4861, seconds: 1600)
            return (AnyView(TenRunSessionView()), nil)
        case "Saved run": return (AnyView(TenSavedRunView(row: Fixtures.savedRun(), onClose: nil)), nil)
        case "Library": return (AnyView(TenLibraryView()), .train)
        case "Progress":
            trainWeek(Fixtures.longHistory())
            return (AnyView(TenProgressScreen(rows: [])), .train)
        // Settings
        case "Settings": return (AnyView(TenSettingsRootView()), .settings)
        case "Strap": return (AnyView(TenStrapView()), .settings)
        case "Zones": return (AnyView(TenZonesView()), .settings)
        case "Apple Health": return (AnyView(TenAppleHealthView()), .settings)
        case "Backup": return (AnyView(TenBackupView()), .settings)
        case "Import": return (AnyView(TenImportView()), .settings)
        default: break
        }
        return (AnyView(TenTodayView()), .today)
    }

    /// Hands the real recorder made-up fixes, so distance and pace come out of its own sums. It is stopped again
    /// at once, and Pin has no permission text, so the Mac is never asked where it is.
    private func feedRoute(metres: Double, seconds: Double) {
        let startMs = Int64((Date().timeIntervalSince1970 - seconds) * 1000)
        let points = Fixtures.route(metres: metres, secondsPerKm: [seconds / metres * 1000], startMs: startMs)
        let recorder = model.gpsRecorder
        recorder.start(startMs: startMs)
        recorder.locationManager(CLLocationManager(), didUpdateLocations: points.map {
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon), altitude: 0, horizontalAccuracy: 5,
                       verticalAccuracy: 5, timestamp: Date(timeIntervalSince1970: TimeInterval($0.tMs) / 1000))
        })
        recorder.stop()
    }
}

/// Fills a screen that takes a day's numbers as they load, the way the real page hands them over.
private struct Loaded<Value, Content: View>: View {
    let load: () async -> Value
    @ViewBuilder let content: (Value) -> Content
    @State private var value: Value?

    var body: some View {
        ZStack {
            TenColor.black
            if let value { content(value) }
        }
        .task { value = await load() }
    }
}

/// The phone's top edge, as the design boards draw it.
private struct PhoneStatusBar: View {
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
        .foregroundStyle(TenColor.white)
        .padding(.horizontal, 12)
        .frame(height: 54)
        .overlay { Capsule().fill(TenColor.black).frame(width: 126, height: 37) }
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
