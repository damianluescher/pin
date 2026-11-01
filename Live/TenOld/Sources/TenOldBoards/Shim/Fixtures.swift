import Foundation

/// Made-up sessions. Nothing here is real data, and nothing is saved.
@MainActor
enum Fixtures {
    static let allWorkouts = ["upper-a", "lower-a", "upper-b", "lower-b", "upper-c", "lower-c"]

    static func exercise(_ id: String) -> Exercise? { Catalog.exercise(id) }

    /// These sessions finished this week, on the Monday.
    static func done(_ store: TenStore, _ ids: [String]) {
        store.history = ids.map { log($0, on: store.plan.weekStart.addingTimeInterval(43_200), minutes: 26) }
    }

    private static func log(_ id: String, on date: Date, minutes: Int, partial: Bool = false) -> SessionLog {
        let workout = PlanGenerator.workout(id)
        return SessionLog(date: date, workoutID: id, title: workout?.title ?? id, minutes: minutes, muscles: workout?.muscles ?? [],
                          completedBlocks: partial ? 9 : 28, totalBlocks: 28, workSeconds: minutes * 30)
    }

    /// The picture's numbers: 35 sessions, 15 in the last 30 days, the same volume the 30 days before.
    static func longHistory() -> [SessionLog] {
        let now = BoardEnv.tuesday
        func ago(_ days: Int) -> Date { now.addingTimeInterval(-Double(days) * 86_400) }
        var logs = [log("lower-a", on: ago(0), minutes: 26)]
        // Monday's session comes from an earlier mix, so This Week reads 1/6, as on the board.
        var monday = log("upper-a", on: ago(1), minutes: 25)
        monday.workoutID = "upper-a-earlier"
        logs.append(monday)
        logs.append(log("lower-c", on: ago(2), minutes: 11, partial: true))
        logs += [log("upper-c", on: ago(3), minutes: 27), log("lower-b", on: ago(4), minutes: 26), log("upper-b", on: ago(5), minutes: 24)]
        for i in 0..<9 { logs.append(log(allWorkouts[i % 6], on: ago(7 + i * 2), minutes: i == 8 ? 27 : 28)) }
        for i in 0..<20 { logs.append(log(allWorkouts[i % 6], on: ago(32 + i * 2), minutes: 26)) }
        return logs
    }
}

/// Settings that live only as long as the board.
final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    init() { super.init(suiteName: nil)! }
    override func object(forKey key: String) -> Any? { values[key] }
    override func data(forKey key: String) -> Data? { values[key] as? Data }
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
    override func set(_ value: Bool, forKey key: String) { values[key] = value }
    override func removeObject(forKey key: String) { values[key] = nil }
}
