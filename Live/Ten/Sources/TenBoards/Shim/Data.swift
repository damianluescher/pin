import SwiftUI
import Combine
import UniformTypeIdentifiers
import WhoopStore
import WhoopProtocol
import StrandDesign
import StrandAnalytics

// Stand-ins for the app's strap and database layer. Only data is made up here; every screen on top is 10's real code.

struct ImportedSleepFigures: Equatable {
    var performancePct: Double?
    var consistencyPct: Double?
    var needMin: Double?
    var debtMin: Double?
}

struct SourcedDailyMetric: Equatable {
    let metric: DailyMetric
    let source: String
}

struct RepositoryFreshness: Equatable, Sendable {
    var earliestDay: String?
    static let empty = RepositoryFreshness()
}

@MainActor
final class Repository: ObservableObject {
    @Published var days: [DailyMetric] = Fixtures.days
    @Published var sleeps: [CachedSleepSession] = []
    @Published var importedSleep: [String: ImportedSleepFigures] = [:]
    @Published private(set) var refreshSeq = 0
    @Published private(set) var freshness: RepositoryFreshness = .empty
    @Published private(set) var chargeBaselines: ChargeBaselines.Resolved?
    let deviceId = "my-whoop"
    var today: DailyMetric? { days.last }
    var vitalMetricRows: [SourcedDailyMetric] { [] }

    nonisolated static let appleHealthSource = "apple-health"
    nonisolated static func localDayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    nonisolated static func logicalDay(_ now: Date) -> Date { now.addingTimeInterval(-4 * 3600) }
    nonisolated static func logicalDayKey(_ now: Date) -> String { localDayKey(logicalDay(now)) }

    func refresh(days: Int = 4000) async { refreshSeq += 1 }
    func storeHandle() async -> WhoopStore? { nil }
    func checkpointForBackup() async -> Bool { true }
    func activeDeviceDisplayName() -> String? { "WHOOP" }
    func workoutRows(days: Int = 4000) async -> [WorkoutRow] { [] }
    func allSleepSessions(days: Int = 4000) async -> [CachedSleepSession] { sleeps }
    func hrSamples(from: Int, to: Int, limit: Int = 8000) async -> [HRSample] { [] }
    func rrIntervals(from: Int, to: Int, limit: Int = 8000) async -> [RRInterval] { [] }
    func gravitySamplesUnion(from: Int, to: Int, limit: Int = 200_000) async -> [GravitySample] { [] }
    func hrBuckets(from: Int, to: Int, bucketSeconds: Int = 300) async -> [HRBucket] { [] }
    func latestBattery() async -> (ts: Int, soc: Double?, charging: Bool?)? { (Int(Date().timeIntervalSince1970), 86, false) }
    func habitualMidsleepSec(days: Int = 4000) async -> Int? { nil }
    func series(key: String, source: String, days: Int = 4000, fullHistory: Bool = false) async -> [(day: String, value: Double)] { Fixtures.series(key) }
    func exploreSeries(key: String, source: String, days: Int = 4000, fullHistory: Bool = false) async -> [(day: String, value: Double)] { Fixtures.series(key) }
    func workoutZoneMinutes(from: Int, to: Int, zoneSet: HRZoneSet, source: String = "") async -> [Double]? { nil }
    func addManualNap(startTs: Int, endTs: Int) async {}
    func editSleepTimes(detectedStartTs: Int, oldEndTs: Int, storedStagesJSON: String?, newStartTs: Int, newEndTs: Int) async -> Bool { true }
}

@MainActor
final class LiveState: ObservableObject {
    @Published var connected = true
    @Published var backfilling = false
    @Published var syncChunksThisSession = 0
    @Published var lastSyncedAt: TimeInterval? = Date().timeIntervalSince1970 - 120
    @Published var batteryPct: Double? = 86
    @Published var heartRate: Int? = 64
    func exportableLogText(extraHeaderLines: [String] = []) -> String { "" }
}

@MainActor
final class AppModel: ObservableObject {
    struct ActiveWorkout: Equatable {
        let start: Date
        var sport = "Other"
        var samples: [HRSample] = []
        var liveStrain: Double = 0
        var avgHr = 0
        var peakHr = 0
        var pausedAt: Date?
        var pausedDuration: TimeInterval = 0
        var isPaused: Bool { pausedAt != nil }
        func elapsed(at now: Date = Date()) -> TimeInterval { now.timeIntervalSince(start) - pausedDuration }
    }
    let live = LiveState()
    let behavior = BehaviorStore()
    let gpsRecorder = GpsWorkoutRecorder()
    let deviceId = "my-whoop"
    @Published var activeWorkout: ActiveWorkout?
    @Published var lastWorkout: WorkoutRow?
    @Published var bpm: Int? = 64
    var whoop5Detected: Bool { false }
    @Published var whoopImportSummary: String?
    func startWorkout(sport: String = "Other") { activeWorkout = ActiveWorkout(start: Date(), sport: sport) }
    func endWorkout() { activeWorkout = nil }
    func discardWorkout() { activeWorkout = nil }
    func toggleWorkoutPause() {}
    func startRealtimeHR() {}
    func stopRealtimeHR() {}
    func applySmartAlarm() {}
    func scan(model: WhoopModel? = nil) {}
    func importWhoop(url: URL) {}
    func isImporting(_ source: DataSourceImportKind) -> Bool { false }
    func importFailed(_ source: DataSourceImportKind) -> Bool { false }
}

enum DataSourceImportKind { case whoop, appleHealth, xiaomi }

@MainActor
final class HealthKitBridge: ObservableObject {
    enum Auth { case authorized, notDetermined, denied }
    @Published var auth = Auth.authorized
    @Published var lastSync: Date? = Date()
    @Published var lastError: String?
    func requestAuthorization() async {}
    func sync() async -> Int { 0 }
    func writeBackAfterNewData() async -> Int { 0 }
}

enum FolderBackup {
    static var lastBackupMs: Int = 0
    static var autoEnabled = true
    static var hasFolder = true
    @discardableResult static func useNoopFolder() -> Bool { true }
    static func backupNow(checkpoint: @escaping () async -> Bool) async -> Bool { true }
    static func catchUpIfDue(checkpoint: @escaping () async -> Bool) async {}
}

enum StorePaths { static func strapLogDirectory() throws -> URL { FileManager.default.temporaryDirectory } }

enum FileExport {
    struct BundleEntry { let name: String; let data: Data }
    static func timestampedName(_ base: String, ext: String = "zip") -> String { base }
    static func exportBundle(entries: [BundleEntry], suggestedName: String) async -> URL? { nil }
}

enum DocumentPicker { static func importFile(_ types: [UTType]) async -> URL? { nil } }

struct DevicesView: View { var body: some View { EmptyView() } }

// Small pure rules that live inside the app's big screens, copied as they are.
enum TodayView {
    static func daySwipeDelta(dx: CGFloat) -> Int { dx > 0 ? 1 : -1 }
    static func lastScoredRecoveryDay(days: [DailyMetric], selectedDayKey: String, isToday: Bool, todayScored: Bool, isCalibrating: Bool) -> DailyMetric? {
        guard isToday, !todayScored, !isCalibrating else { return nil }
        return days.last(where: { $0.recovery != nil && $0.day < selectedDayKey })
    }
    static func freshRestScore(todayValue: Double?, lastDay: String?, lastValue: Double?, isTodaySelected: Bool, todayKey: String) -> Double? {
        todayValue ?? (isTodaySelected ? lastValue : nil)
    }
}

enum LiquidTodayView {
    static func clampedDayOffset(current: Int, delta: Int, maxOffset: Int) -> Int { min(max(0, maxOffset), max(0, current + delta)) }
    static func maxDayOffset(earliestDayKey: String?, todayKey: String) -> Int { 0 }
    enum ChargeDisplay: Equatable {
        case scored(pct: Double), carried(pct: Double, caption: String), calibrating(nights: Int), noData
        static func resolve(todayRecovery: Double?, priorScored: DailyMetric?, calibrationNights: Int?, todayKey: String) -> ChargeDisplay {
            if let todayRecovery { return .scored(pct: todayRecovery) }
            if let nights = calibrationNights { return .calibrating(nights: nights) }
            if let pct = priorScored?.recovery { return .carried(pct: pct, caption: "last night") }
            return .noData
        }
    }
}

struct StressModel {
    let score: Double
    init?(days: [DailyMetric], stored: [(day: String, value: Double)]) {
        guard let last = stored.last else { return nil }
        score = last.value
    }
}

enum DebugDataDiagnostics { static func dynamicLines(repo: Repository) async -> [String] { [] } }

enum DataBackup {
    enum ImportResult { case imported, cancelled, failure(String), restoreTooLarge(String, Int64), exported, exportedOversize }
    static func runImport() async -> ImportResult { .cancelled }
}

@MainActor
final class BehaviorStore: ObservableObject {
    @Published var smartAlarmEnabled = false
    @Published var smartAlarmMinutes = 420
}

enum PuffinExperiment {
    static let defaultsKey = "noopPuffinExperiments"
    static var stressPersonalBaselineEnabled: Bool { false }
    static var effortMethod: StrainScorer.Method { .edwards }
}

enum AvatarImage { static func downscaledJPEG(from data: Data, maxDimension: CGFloat) -> Data? { data } }
enum TestCentre {
    enum Area { case workouts }
    static func active(_ area: Area) -> Bool { false }
}
enum PuffinFrameRecorder {}

struct Stages { var awake = 0.0, rem = 0.0, light = 0.0, deep = 0.0; var asleep: Double { rem + light + deep } }

struct Night {
    let session: CachedSleepSession
    let stages: Stages
    var realSegments: [SleepInterval]? = nil
    var editTarget: CachedSleepSession? { session }
}

enum SleepModel {
    struct Metric { var series: [Double] = [] }
    static func debtNeedMin(days: [DailyMetric]) -> Double { 480 }
    static func navDays(navSessions: [CachedSleepSession]) -> [[CachedSleepSession]] { navSessions.map { [$0] } }
    static func mergeDay(_ sessions: [CachedSleepSession], habitualMidsleepSec: Int?, motionByStart: [Int: [Double]]) -> Night? { nil }
    static func consistencySeries(days: [DailyMetric], sleeps: [CachedSleepSession], importedSleep: [String: ImportedSleepFigures]) -> Metric { Metric() }
    static func sleepDebtSeries(days: [DailyMetric], importedSleep: [String: ImportedSleepFigures], napSleepMinByDay: [String: Double]) -> Metric { Metric() }
}

struct BodyVitalReading {
    let key: String
    let unit: String
    let value: Double?
    let format: (Double) -> String
    let banding: VitalBands.Result
    var sparkline: [Double]? = nil
}

enum BodyVitalSigns {
    static func readings(sourceRows: [SourcedDailyMetric], temperatureUnit: TemperatureUnit, now: Date) -> [BodyVitalReading] { [] }
}

enum DaytimeStressMode {
    static func selected(repo: Repository, startOfToday: Date, calendar: Calendar = .current, personalBaseline: Bool) async -> DaytimeStress.ScoringMode { .dayRelative }
}
