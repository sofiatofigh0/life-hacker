import XCTest
@testable import WellnessCore

final class InsightsTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let today = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14, a Tuesday

    private func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))! }

    // MARK: Streak

    func testStreakCountsTodayWhenItQualifies() {
        let scores: [Date: Double] = [day(0): 0.9, day(-1): 0.8, day(-2): 0.75, day(-3): 0.2]
        let streak = Streak.consecutiveDays(scoreForDay: { scores[$0] ?? 0 }, threshold: 0.7, today: today, calendar: calendar)
        XCTAssertEqual(streak, 3)
    }

    func testStreakSurvivesAnInProgressToday() {
        // Today is only 0.3 so far; yesterday and the day before qualify.
        let scores: [Date: Double] = [day(0): 0.3, day(-1): 0.8, day(-2): 0.9, day(-3): 0.1]
        let streak = Streak.consecutiveDays(scoreForDay: { scores[$0] ?? 0 }, threshold: 0.7, today: today, calendar: calendar)
        XCTAssertEqual(streak, 2)
    }

    func testStreakZeroWhenNothingQualifies() {
        XCTAssertEqual(Streak.consecutiveDays(scoreForDay: { _ in 0 }, threshold: 0.7, today: today, calendar: calendar), 0)
    }

    // MARK: Weeks

    func testWeekWindowsAreContiguousAndSevenDays() {
        let this = WeekWindow.current(containing: today, calendar: calendar)
        let last = this.previous
        XCTAssertEqual(this.end.timeIntervalSince(this.start), 7 * 86_400, accuracy: 3_600)
        XCTAssertEqual(last.end, this.start)
        XCTAssertTrue(this.contains(today))
        XCTAssertFalse(last.contains(today))
        XCTAssertTrue(last.contains(day(-7)))
    }

    // MARK: Aggregates

    func testMeanIsNilForNoData() {
        XCTAssertNil(Aggregate.mean([]))
        XCTAssertEqual(Aggregate.mean([1, 2, 3]), 2)
    }

    func testDailyTotalsSumWithinADay() {
        let entries: [(date: Date, value: Double)] = [
            (day(0).addingTimeInterval(3_600), 0.25), (day(0).addingTimeInterval(7_200), 0.5), (day(-1), 0.35)
        ]
        let totals = Aggregate.dailyTotals(entries, calendar: calendar)
        XCTAssertEqual(totals[day(0)]!, 0.75, accuracy: 0.0001)
        XCTAssertEqual(totals[day(-1)]!, 0.35, accuracy: 0.0001)
        XCTAssertEqual(totals.count, 2)
    }

    // MARK: Pace, volume, greeting

    func testPaceFormatting() {
        XCTAssertEqual(Pace.format(minutes: 30, distance: 5, unit: "km"), "6:00 /km")
        XCTAssertEqual(Pace.format(minutes: 27.5, distance: 5, unit: "km"), "5:30 /km")
        XCTAssertEqual(Pace.format(minutes: 26.6, distance: 3.1, unit: "mi"), "8:35 /mi")
        XCTAssertNil(Pace.format(minutes: 0, distance: 5, unit: "km"))
        XCTAssertNil(Pace.format(minutes: 30, distance: 0, unit: "km"))
    }

    func testVolumeIgnoresUnperformedSets() {
        XCTAssertEqual(Volume.total(sets: [(60, 10), (60, 0), (65, 8)]), 1_120)
        XCTAssertEqual(Volume.estimatedOneRepMax(weightKG: 100, reps: 1), 100)
        XCTAssertEqual(Volume.estimatedOneRepMax(weightKG: 60, reps: 10), 80, accuracy: 0.001)
    }

    func testGreeting() {
        XCTAssertEqual(Greeting.text(hour: 8, name: "Sofia"), "Good morning, Sofia")
        XCTAssertEqual(Greeting.text(hour: 14, name: ""), "Good afternoon")
        XCTAssertEqual(Greeting.text(hour: 19, name: nil), "Good evening")
        XCTAssertEqual(Greeting.text(hour: 2, name: "  "), "Hello")
    }

    // MARK: Daily score index

    func testDailyScoreIndexBucketsByDayAndScoresLikeTheCalculator() {
        let targets = DailyScoreIndex.Targets(calories: 2_000, protein: 100, steps: 10_000, waterLiters: 2)
        let index = DailyScoreIndex(
            calendar: calendar, targets: targets, supplementCount: 2,
            food: [(date: day(0).addingTimeInterval(8 * 3_600), calories: 1_000, protein: 60),
                   (date: day(0).addingTimeInterval(19 * 3_600), calories: 1_000, protein: 40)],
            completedWorkouts: [day(0).addingTimeInterval(18 * 3_600)],
            steps: [(date: day(0), steps: 10_000)],
            water: [(date: day(0), liters: 1), (date: day(0).addingTimeInterval(60), liters: 1)],
            supplementChecks: [day(0), day(0)])
        XCTAssertEqual(index.score(on: today), 1, accuracy: 0.0001)
        XCTAssertEqual(index.score(on: day(-1)), 0, accuracy: 0.0001)
        XCTAssertTrue(index.hasData(on: today))
        XCTAssertFalse(index.hasData(on: day(-1)))

        let expected = CompletionCalculator.score(index.input(for: today))
        XCTAssertEqual(index.score(on: today), expected)
    }

    func testDailyScoreIndexWithNoSupplementsCountsAsComplete() {
        let targets = DailyScoreIndex.Targets(calories: 2_000, protein: 100, steps: 10_000, waterLiters: 2)
        let index = DailyScoreIndex(calendar: calendar, targets: targets, supplementCount: 0,
                                    food: [], completedWorkouts: [], steps: [], water: [], supplementChecks: [])
        XCTAssertEqual(index.input(for: today).supplementFraction, 1)
        XCTAssertEqual(index.score(on: today), 0.05, accuracy: 0.0001)
    }
}
