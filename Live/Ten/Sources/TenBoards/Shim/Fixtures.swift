import Foundation
import CoreLocation
import StrandAnalytics
import StrandDesign
import WhoopProtocol
import WhoopStore

/// The made-up account the boards show. No real data of his: change these to see a screen with other numbers.
@MainActor
enum Fixtures {
    static func key(_ back: Int) -> String {
        Repository.localDayKey(Repository.logicalDay(Date()).addingTimeInterval(-Double(back) * 86_400))
    }

    /// Stored Effort (0-100) for a number on the 0-21 strain scale the screens show.
    static func effort(_ strain: Double) -> Double { strain / 0.21 }

    static func days(recovery: Double = 74) -> [DailyMetric] {
        (0..<14).reversed().compactMap { back in
            let today = back == 0
            let row: [String: Any] = [
                "day": key(back), "totalSleepMin": today ? 462 : back == 1 ? 418 : 440 - back, "efficiency": 91,
                "deepMin": today ? 96 : 88, "remMin": today ? 112 : 100, "lightMin": today ? 254 : 230,
                "disturbances": 6, "restingHr": today ? 52 : 54 + back % 3, "avgHrv": today ? 68 : 60 - back % 5,
                "recovery": today ? recovery : back == 1 ? 66 : 70 - back % 7, "strain": effort(8.4),
                "exerciseCount": 1, "respRateBpm": today ? 14.2 : 14.0,
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: row) else { return nil }
            return try? JSONDecoder().decode(DailyMetric.self, from: data)
        }
    }

    /// Sleep score per night, the last seven averaging 79.
    static func sleepScores() -> [(day: String, value: Double)] {
        [(7, 78), (6, 84), (5, 72), (4, 52), (3, 88), (2, 84), (1, 82), (0, 91)].map { (key($0.0), Double($0.1)) }
    }

    static func stress() -> [(day: String, value: Double)] { [(key(1), 0.9), (key(0), 0.8)] }

    // MARK: Nights

    /// A clock time on the morning of a logical day, or on the evening before it.
    private static func time(back: Int, hour: Int, minute: Int, eveningBefore: Bool = false) -> Int {
        let base = Repository.logicalDay(Date()).addingTimeInterval(-Double(back + (eveningBefore ? 1 : 0)) * 86_400)
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        return Int(date.timeIntervalSince1970)
    }

    private static func session(back: Int, onset: (Int, Int), wake: (Int, Int)) -> CachedSleepSession {
        CachedSleepSession(startTs: time(back: back, hour: onset.0, minute: onset.1, eveningBefore: true),
                           endTs: time(back: back, hour: wake.0, minute: wake.1), efficiency: 91, restingHr: 52,
                           avgHrv: 68, stagesJSON: nil)
    }

    static let lastNight: (back: Int, onset: (Int, Int), wake: (Int, Int)) = (0, (23, 14), (7, 12))
    static func sleeps(onlyYesterday: Bool = false, bedAt: (Int, Int)? = nil) -> [CachedSleepSession] {
        let yesterday = session(back: 1, onset: bedAt ?? (23, 40), wake: (7, 5))
        if onlyYesterday { return [yesterday] }
        return [yesterday, session(back: 0, onset: bedAt ?? lastNight.onset, wake: lastNight.wake)]
    }

    static func night(for session: CachedSleepSession) -> Night {
        // Last night is the longer one; each night has its own stage totals.
        let isLastNight = session.endTs > time(back: 1, hour: 12, minute: 0)
        let stages = isLastNight ? Stages(awake: 16, rem: 112, light: 254, deep: 96) : Stages(awake: 12, rem: 100, light: 230, deep: 88)
        let plan: [(SleepStage, Double)] = [
            (.light, 20), (.deep, 36), (.light, 30), (.rem, 22), (.awake, 3), (.light, 34), (.deep, 34), (.light, 32),
            (.rem, 26), (.awake, 4), (.light, 40), (.deep, 26), (.light, 36), (.rem, 28), (.awake, 4), (.light, 46), (.rem, 36), (.awake, 5),
        ]
        let scale = Double(session.endTs - session.startTs) / plan.reduce(0) { $0 + $1.1 }
        var at = 0.0
        let segments = plan.map { stage, minutes -> SleepInterval in
            defer { at += minutes * scale }
            return SleepInterval(stage: stage, start: at, end: at + minutes * scale)
        }
        return Night(session: session, stages: stages, realSegments: segments)
    }

    // MARK: Vitals

    static func vitals(somethingOff: Bool) -> [BodyVitalReading] {
        func trail(_ base: Double, _ swing: Double, last: Double) -> [Double] {
            (0..<13).map { base + swing * 0.5 * sin(Double($0) * 0.9) } + [last]
        }
        func reading(_ key: String, _ unit: String, _ value: Double, _ band: VitalBands.Band, _ base: Double, _ swing: Double,
                     _ format: @escaping (Double) -> String) -> BodyVitalReading {
            BodyVitalReading(key: key, unit: unit, value: value, format: format,
                             banding: VitalBands.Result(band: band, basis: .personal, nights: 14),
                             sparkline: trail(base, swing, last: value))
        }
        let whole: (Double) -> String = { String(Int($0.rounded())) }
        let tenth: (Double) -> String = { String(format: "%.1f", $0) }
        return [
            reading("rhr", "bpm", somethingOff ? 64 : 52, somethingOff ? .outOfRange : .inRange, 52, 1.5, whole),
            reading("hrv", "ms", somethingOff ? 41 : 68, somethingOff ? .outOfRange : .inRange, 66, 4, whole),
            reading("resp", "", somethingOff ? 14.8 : 14.2, .inRange, 14.2, 0.2, tenth),
            reading("spo2", "%", 97, .inRange, 97, 0.5, whole),
            reading("skin", "°C", somethingOff ? 0.2 : 0.1, .inRange, 0.1, 0.1) { String(format: "%+.1f", $0) },
        ]
    }

    /// A day's heart rate for the Stress curve: calm, with its peak in the afternoon.
    static func heartRateDay() -> [HRSample] {
        let start = time(back: 0, hour: 6, minute: 0)
        return stride(from: 0, to: 14 * 3600, by: 10).map { second in
            let hour = Double(second) / 3600
            let peak = 34 * exp(-pow(hour - 8.3, 2) / 1.2) + 14 * exp(-pow(hour - 11.5, 2) / 0.8)
            return HRSample(ts: start + second, bpm: Int(62 + peak + 3 * sin(hour * 3)))
        }
    }

    // MARK: Training

    /// A lap drawn to look like a run; `metres` sets how long it is.
    static func route(metres: Double, secondsPerKm: [Double], startMs: Int64) -> [WorkoutRoutePoint] {
        let shape: [(Double, Double)] = [(0.1, 0.72), (0.14, 0.32), (0.38, 0.28), (0.55, 0.12), (0.8, 0.1), (0.95, 0.42), (0.68, 0.5), (0.58, 0.74), (0.36, 0.72), (0.34, 0.9), (0.1, 0.72)]
        var legs: [Double] = []
        for (a, b) in zip(shape, shape.dropFirst()) { legs.append(hypot(b.0 - a.0, b.1 - a.1)) }
        let perimeter = legs.reduce(0, +)
        let scale = metres / perimeter // Metres per shape unit.
        let origin = CLLocationCoordinate2D(latitude: 47.37, longitude: 8.54) // Made up, not a place he runs.
        let metresPerLat = 111_320.0, metresPerLon = 111_320.0 * cos(origin.latitude * .pi / 180)
        var points: [WorkoutRoutePoint] = []
        var walked = 0.0, seconds = 0.0
        let step = 25.0
        var leg = 0, intoLeg = 0.0
        while walked <= metres, leg < legs.count {
            let t = legs[leg] > 0 ? intoLeg / legs[leg] : 0
            let x = shape[leg].0 + (shape[leg + 1].0 - shape[leg].0) * t
            let y = shape[leg].1 + (shape[leg + 1].1 - shape[leg].1) * t
            points.append(WorkoutRoutePoint(lat: origin.latitude - y * scale / metresPerLat, lon: origin.longitude + x * scale / metresPerLon,
                                            accuracyM: 5, tMs: startMs + Int64(seconds * 1000)))
            let km = min(Int(walked / 1000), secondsPerKm.count - 1)
            seconds += secondsPerKm[km] * step / 1000
            walked += step
            intoLeg += step / scale
            while leg < legs.count, intoLeg >= legs[leg] {
                intoLeg -= legs[leg]
                leg += 1
            }
        }
        return points
    }

    static let splits: [Double] = [344, 336, 328, 321, 319, 332, 334, 337, 340, 338, 335]
    static let zoneSeconds: [Double] = [250, 1120, 1450, 500, 60]

    static func zonesJSON(duration: Double) -> String? { TenZones.json(seconds: zoneSeconds, duration: duration) }

    private static var monday: Date { PlanCalendar.monday(of: .now, calendar: .current) }
    private static func inWeek(_ day: Int, hour: Int = 7, minute: Int = 12) -> Int {
        let date = Calendar.current.date(byAdding: .day, value: day, to: monday) ?? monday
        return Int((Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date).timeIntervalSince1970)
    }

    /// This week's long run, with its route saved where the real screens read it (Pin's own settings, not the app's).
    static func savedRun() -> WorkoutRow {
        let start = inWeek(3)
        let points = route(metres: 10_200, secondsPerKm: splits, startMs: Int64(start) * 1000)
        let polyline = RouteMath.encode(points.map { RouteMath.LatLng($0.lat, $0.lon) })
        RouteStore.store(WorkoutRoute(polyline: polyline, distanceM: 10_200, points: points), startTs: start, sport: TenSession.runSport)
        return WorkoutRow(startTs: start, endTs: start + 3380, sport: TenSession.runSport, source: "my-whoop", durationS: 3380,
                          energyKcal: 612, avgHr: 148, maxHr: 176, strain: effort(11.2), distanceM: 10_200,
                          zonesJSON: zonesJSON(duration: 3380), notes: nil, steps: nil)
    }

    static func weekRows() -> [WorkoutRow] {
        let shortRun = inWeek(1)
        let upperB = inWeek(2, hour: 18, minute: 0)
        return [
            savedRun(),
            WorkoutRow(startTs: upperB, endTs: upperB + 1440, sport: TenSession.planSport, source: "my-whoop", durationS: 1440, energyKcal: 240, avgHr: 131,
                       maxHr: 160, strain: effort(9.6), distanceM: nil, zonesJSON: nil, notes: nil, steps: nil),
            WorkoutRow(startTs: shortRun, endTs: shortRun + 2700, sport: TenSession.runSport, source: "my-whoop", durationS: 2700, energyKcal: 480, avgHr: 145,
                       maxHr: 170, strain: effort(9.2), distanceM: 8_200, zonesJSON: nil, notes: nil, steps: nil),
        ]
    }

    static func log(_ id: String, _ title: String, minutes: Int = 26, date: Date, startTs: Int? = nil) -> SessionLog {
        SessionLog(date: date, workoutID: id, title: title, minutes: minutes, muscles: [], completedBlocks: 20, totalBlocks: 20,
                   workSeconds: minutes * 30, workoutStartTs: startTs)
    }

    /// Upper A done on Monday, three sessions the week before: Lower A is next, the streak reads 4.
    static func weekHistory() -> [SessionLog] {
        let lastWeek = Calendar.current.date(byAdding: .day, value: -3, to: monday) ?? monday
        return [
            log("upper-a", "Upper A", date: monday.addingTimeInterval(8 * 3600)),
            log("upper-b", "Upper B", minutes: 24, date: lastWeek, startTs: inWeek(2, hour: 18, minute: 0)),
            log("lower-b", "Lower B", minutes: 25, date: lastWeek),
            log("upper-c", "Upper C", date: lastWeek),
        ]
    }

    /// Eight weeks of sessions for Progress: 35 of them, 910 minutes.
    static func longHistory() -> [SessionLog] {
        let names = [("lower-a", "Lower A"), ("upper-b", "Upper B"), ("lower-b", "Lower B"), ("upper-c", "Upper C"), ("lower-c", "Lower C"), ("upper-a", "Upper A")]
        var logs = [log("lower-a", "Lower A", date: monday.addingTimeInterval(8 * 3600))]
        for (weeksBack, count) in [3, 6, 5, 6, 4, 6, 4].enumerated() {
            let week = Calendar.current.date(byAdding: .day, value: 1 - (weeksBack + 1) * 7, to: monday) ?? monday
            for index in 0..<count {
                let (id, title) = names[(index + 1) % names.count]
                let minutes = logs.count == 1 ? 24 : logs.count == 2 ? 25 : logs.count == 3 ? 29 : 26
                logs.append(log(id, title, minutes: minutes, date: week.addingTimeInterval(Double(index) * 3600)))
            }
        }
        return logs
    }

    static func samples(bpm: Int, seconds: Int) -> [HRSample] {
        let now = Int(Date().timeIntervalSince1970)
        return stride(from: seconds, to: 0, by: -5).map { HRSample(ts: now - $0, bpm: bpm) }
    }
}

/// A store's own memory instead of a settings file, so a board never writes anywhere and never shares a value.
final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    init() { super.init(suiteName: nil)! }
    override func object(forKey key: String) -> Any? { values[key] }
    override func data(forKey key: String) -> Data? { values[key] as? Data }
    override func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
    override func set(_ value: Bool, forKey key: String) { values[key] = value }
    override func set(_ value: Int, forKey key: String) { values[key] = value }
    override func removeObject(forKey key: String) { values[key] = nil }
}
