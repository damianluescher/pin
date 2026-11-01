import Foundation
import WhoopStore

/// The made-up account the boards show. A good week: change these to see a screen in another state.
enum Fixtures {
    private static func key(_ back: Int) -> String {
        Repository.localDayKey(Repository.logicalDay(Date()).addingTimeInterval(-Double(back) * 86_400))
    }

    static let days: [DailyMetric] = (0..<14).reversed().compactMap { back in
        let row: [String: Any] = [
            "day": key(back), "totalSleepMin": 452 - back * 3, "efficiency": 91, "deepMin": 82, "remMin": 104, "lightMin": 266,
            "disturbances": 6, "restingHr": 52 + back % 3, "avgHrv": 74 - back % 5, "recovery": 78 - back % 7,
            "strain": 42 - back % 9, "exerciseCount": 1, "respRateBpm": 14.2,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: row) else { return nil }
        return try? JSONDecoder().decode(DailyMetric.self, from: data)
    }

    static func series(_ name: String) -> [(day: String, value: Double)] {
        let today = key(0)
        switch name {
        case "sleep_performance": return [(today, 86)]
        case "stress": return [(today, 1.2)]
        default: return []
        }
    }
}
