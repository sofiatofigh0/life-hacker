import Foundation

// MARK: - Streaks

public enum Streak {
    /// Consecutive days at or above `threshold`, counting back from `today`.
    /// Today counts if it already qualifies; otherwise the streak is measured
    /// from yesterday so an in-progress day doesn't break it.
    public static func consecutiveDays(scoreForDay: (Date) -> Double, threshold: Double, today: Date,
                                       calendar: Calendar = .current, limit: Int = 366) -> Int {
        let start = calendar.startOfDay(for: today)
        var day = scoreForDay(start) >= threshold ? start : (calendar.date(byAdding: .day, value: -1, to: start) ?? start)
        var count = 0
        while count < limit, scoreForDay(day) >= threshold {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}

// MARK: - Week windows

/// Half-open [start, end) ranges for "this week" and "last week", using the
/// calendar's own first weekday.
public struct WeekWindow: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) { self.start = start; self.end = end }

    public func contains(_ date: Date) -> Bool { date >= start && date < end }

    public static func current(containing date: Date, calendar: Calendar = .current) -> WeekWindow {
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 86_400)
        return WeekWindow(start: interval.start, end: interval.end)
    }

    public var previous: WeekWindow {
        let length = end.timeIntervalSince(start)
        return WeekWindow(start: start.addingTimeInterval(-length), end: start)
    }
}

// MARK: - Aggregates

public enum Aggregate {
    /// Mean of the values, or nil when there are none — so "no data" is never shown as 0.
    public static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// Sums values by calendar day, so per-entry logs (water taps, food rows)
    /// become daily totals before averaging.
    public static func dailyTotals(_ entries: [(date: Date, value: Double)], calendar: Calendar = .current) -> [Date: Double] {
        var totals = [Date: Double]()
        for entry in entries { totals[calendar.startOfDay(for: entry.date), default: 0] += entry.value }
        return totals
    }
}

// MARK: - Pace

public enum Pace {
    /// "5:32 /km" or "8:54 /mi". Nil when either input is missing or zero.
    public static func format(minutes: Double, distance: Double, unit: String) -> String? {
        guard minutes > 0, distance > 0 else { return nil }
        let perUnit = minutes / distance
        let whole = Int(perUnit)
        let seconds = Int(((perUnit - Double(whole)) * 60).rounded())
        if seconds == 60 { return "\(whole + 1):00 /\(unit)" }
        return "\(whole):" + String(format: "%02d", seconds) + " /\(unit)"
    }
}

// MARK: - Training volume

public enum Volume {
    /// Sum of weight × reps over sets that were actually performed (reps > 0).
    public static func total(sets: [(weightKG: Double, reps: Int)]) -> Double {
        sets.filter { $0.reps > 0 }.reduce(0) { $0 + $1.weightKG * Double($1.reps) }
    }

    /// Estimated one-rep max (Epley). Used only for ranking "best set".
    public static func estimatedOneRepMax(weightKG: Double, reps: Int) -> Double {
        guard reps > 0, weightKG > 0 else { return 0 }
        return reps == 1 ? weightKG : weightKG * (1 + Double(reps) / 30)
    }
}

// MARK: - Greeting

public enum Greeting {
    public static func text(hour: Int, name: String?) -> String {
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<17: base = "Good afternoon"
        case 17..<22: base = "Good evening"
        default: base = "Hello"
        }
        let trimmed = name?.trimmingCharacters(in: .whitespaces) ?? ""
        return trimmed.isEmpty ? base : "\(base), \(trimmed)"
    }
}

// MARK: - Daily score index

/// Buckets every log by calendar day once, so scoring a day is a dictionary
/// lookup rather than a scan of every table. Today, the calendar grid (42
/// cells) and the streak all score days; each used to filter the full row set
/// per day.
public struct DailyScoreIndex {
    public struct Targets: Equatable, Sendable {
        public var calories: Double
        public var protein: Double
        public var steps: Double
        public var waterLiters: Double
        public init(calories: Double, protein: Double, steps: Double, waterLiters: Double) {
            self.calories = calories; self.protein = protein; self.steps = steps; self.waterLiters = waterLiters
        }
    }

    private let calendar: Calendar
    private let targets: Targets
    private let supplementCount: Int
    private var calories: [Date: Double] = [:]
    private var protein: [Date: Double] = [:]
    private var steps: [Date: Double] = [:]
    private var water: [Date: Double] = [:]
    private var checks: [Date: Int] = [:]
    private var workoutDays: Set<Date> = []

    public init(calendar: Calendar = .current, targets: Targets, supplementCount: Int,
                food: [(date: Date, calories: Double, protein: Double)],
                completedWorkouts: [Date],
                steps: [(date: Date, steps: Double)],
                water: [(date: Date, liters: Double)],
                supplementChecks: [Date]) {
        self.calendar = calendar
        self.targets = targets
        self.supplementCount = supplementCount
        for entry in food {
            let day = calendar.startOfDay(for: entry.date)
            calories[day, default: 0] += entry.calories
            protein[day, default: 0] += entry.protein
        }
        for date in completedWorkouts { workoutDays.insert(calendar.startOfDay(for: date)) }
        // One activity row per day is the rule; if there are two, keep the larger.
        for entry in steps {
            let day = calendar.startOfDay(for: entry.date)
            self.steps[day] = max(self.steps[day] ?? 0, entry.steps)
        }
        for entry in water { self.water[calendar.startOfDay(for: entry.date), default: 0] += entry.liters }
        for date in supplementChecks { checks[calendar.startOfDay(for: date), default: 0] += 1 }
    }

    public func input(for date: Date) -> CompletionInput {
        let day = calendar.startOfDay(for: date)
        let fraction = supplementCount == 0 ? 1.0 : Double(checks[day] ?? 0) / Double(supplementCount)
        return CompletionInput(workout: workoutDays.contains(day),
                               calories: calories[day] ?? 0, calorieTarget: targets.calories,
                               protein: protein[day] ?? 0, proteinTarget: targets.protein,
                               steps: steps[day] ?? 0, stepTarget: targets.steps,
                               waterLiters: water[day] ?? 0, waterTargetLiters: targets.waterLiters,
                               supplementFraction: fraction)
    }

    public func score(on date: Date) -> Double { CompletionCalculator.score(input(for: date)) }

    /// True when anything at all was logged that day — used to tell "0%" from "no data".
    public func hasData(on date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return calories[day] != nil || workoutDays.contains(day) || (steps[day] ?? 0) > 0 || water[day] != nil || checks[day] != nil
    }
}
