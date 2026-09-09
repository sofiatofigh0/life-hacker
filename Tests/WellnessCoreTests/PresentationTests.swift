import XCTest
@testable import WellnessCore

final class PresentationTests: XCTestCase {
    // MARK: Units

    func testImperialWeightRoundTrips() {
        let u = UnitSystem.imperial
        XCTAssertEqual(u.displayWeight(kilograms: 70), 154.3, accuracy: 0.05)
        XCTAssertEqual(u.kilograms(fromDisplayWeight: u.displayWeight(kilograms: 70)), 70, accuracy: 0.0001)
        XCTAssertEqual(u.formatWeight(kilograms: 70), "154.3 lb")
    }

    func testMetricWeightIsIdentity() {
        let u = UnitSystem.metric
        XCTAssertEqual(u.displayWeight(kilograms: 70), 70)
        XCTAssertEqual(u.formatWeight(kilograms: 70), "70.0 kg")
    }

    func testHeightConversion() {
        XCTAssertEqual(UnitSystem.imperial.displayHeight(centimeters: 165), 64.96, accuracy: 0.01)
        XCTAssertEqual(UnitSystem.imperial.centimeters(fromDisplayHeight: 65), 165.1, accuracy: 0.01)
        XCTAssertEqual(UnitSystem.metric.displayHeight(centimeters: 165), 165)
    }

    func testDistanceConversion() {
        XCTAssertEqual(UnitSystem.imperial.displayDistance(kilometers: 5), 3.107, accuracy: 0.001)
        XCTAssertEqual(UnitSystem.imperial.kilometers(fromDisplayDistance: 3.107), 5, accuracy: 0.001)
        XCTAssertEqual(UnitSystem.imperial.distanceUnit, "mi")
        XCTAssertEqual(UnitSystem.metric.speedUnit, "km/h")
    }

    func testWaterDisplayAndQuickAdds() {
        XCTAssertEqual(UnitSystem.metric.formatWater(liters: 1.9), "1,900 mL")
        XCTAssertEqual(UnitSystem.imperial.formatWater(liters: 1.9), "64 oz")
        XCTAssertEqual(UnitSystem.metric.waterQuickAddLabel(liters: 0.25), "+250 mL")
        XCTAssertEqual(UnitSystem.imperial.waterQuickAddLabel(liters: 0.237), "+8 oz")
        XCTAssertEqual(UnitSystem.imperial.waterQuickAdds.count, 3)
        // quick adds must round-trip through the display value cleanly
        for liters in UnitSystem.imperial.waterQuickAdds {
            let shown = UnitSystem.imperial.displayWater(liters: liters)
            XCTAssertEqual(shown.rounded(), shown, accuracy: 0.05, "quick add \(liters) L should be a round ounce count")
        }
    }

    // MARK: Labels

    func testActivityLabelsAreHumanReadable() {
        XCTAssertEqual(ActivityLevel.veryActive.label, "Very active")
        XCTAssertFalse(ActivityLevel.allCases.map(\.label).contains { $0.contains("veryActive") })
    }

    func testMealInference() {
        XCTAssertEqual(Meal.inferred(hour: 7), .breakfast)
        XCTAssertEqual(Meal.inferred(hour: 12), .lunch)
        XCTAssertEqual(Meal.inferred(hour: 16), .snacks)
        XCTAssertEqual(Meal.inferred(hour: 19), .dinner)
        XCTAssertEqual(Meal.inferred(hour: 23), .snacks)
    }

    // MARK: Legacy demo fixture matching

    func testFixtureActivityPairsMatchTheOriginalSeeder() {
        // offset 0 -> steps 7000, active 250; offset -1 -> 7379, 281
        XCTAssertTrue(LegacyDemoFixtures.isFixtureActivity(steps: 7000, activeCalories: 250))
        XCTAssertTrue(LegacyDemoFixtures.isFixtureActivity(steps: 7379, activeCalories: 281))
        XCTAssertEqual(LegacyDemoFixtures.activityPairs.count, 36)
    }

    func testRealHealthKitDayIsNotMistakenForFixture() {
        // HealthKit values are essentially never integer pairs from a 36-entry table
        XCTAssertFalse(LegacyDemoFixtures.isFixtureActivity(steps: 8412, activeCalories: 377.4))
        XCTAssertFalse(LegacyDemoFixtures.isFixtureActivity(steps: 7000, activeCalories: 251))
    }

    func testFixtureWaterAndWeight() {
        XCTAssertTrue(LegacyDemoFixtures.isFixtureWater(liters: 1.4))
        XCTAssertTrue(LegacyDemoFixtures.isFixtureWater(liters: 2.1))
        XCTAssertFalse(LegacyDemoFixtures.isFixtureWater(liters: 0.473), "a real quick-add is never a fixture")
        XCTAssertTrue(LegacyDemoFixtures.isFixtureWeight(kilograms: 70))
        XCTAssertTrue(LegacyDemoFixtures.isFixtureWeight(kilograms: 70 - 35 * 0.035))
        XCTAssertFalse(LegacyDemoFixtures.isFixtureWeight(kilograms: 69.4))
    }

    func testFixtureFood() {
        XCTAssertTrue(LegacyDemoFixtures.isFixtureFood(name: "Greek Yogurt Bowl", per100: .init(calories: 120, protein: 10, carbs: 14, fat: 3)))
        XCTAssertFalse(LegacyDemoFixtures.isFixtureFood(name: "Greek Yogurt Bowl", per100: .init(calories: 121, protein: 10, carbs: 14, fat: 3)),
                       "a user's own yogurt with different macros must survive cleanup")
        XCTAssertTrue(LegacyDemoFixtures.isFixtureFoodLog(name: "Greek Yogurt Bowl", grams: 250))
        XCTAssertFalse(LegacyDemoFixtures.isFixtureFoodLog(name: "Greek Yogurt Bowl", grams: 200))
    }
}
