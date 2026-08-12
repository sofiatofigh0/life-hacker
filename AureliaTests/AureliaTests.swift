import XCTest
@testable import Aurelia

final class AureliaAppTests: XCTestCase {
    func testCalorieTargetIgnoresActivityEnergy() {
        XCTAssertEqual(GoalCalculator.target(base: 1800, workoutOverride: nil, restOverride: nil, isWorkoutDay: true, activeCalories: 999), 1800)
    }
}
