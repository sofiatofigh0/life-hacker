import XCTest
@testable import WellnessCore

final class ProgramCatalogTests: XCTestCase {
    func testEveryProgramExerciseExistsInTheCatalog() {
        for program in ProgramCatalog.all {
            for day in program.days {
                for exercise in day.exercises {
                    XCTAssertNotNil(ExerciseCatalog.definition(named: exercise.name), "\(day.name): \(exercise.name) is not in the exercise catalog")
                    XCTAssertGreaterThan(exercise.sets, 0, exercise.name)
                    XCTAssertFalse(exercise.reps.isEmpty, exercise.name)
                }
            }
        }
    }

    func testFiveDayProgramShape() {
        let program = ProgramCatalog.glutesAndPosture
        XCTAssertEqual(program.days.count, 5)
        XCTAssertEqual(Set(program.days.map(\.suggestedWeekday)).count, 5, "each day has its own weekday")
        XCTAssertTrue(program.days.allSatisfy { (1...7).contains($0.suggestedWeekday) })
        let hipThrust = program.days[1].exercises.first { $0.name == "Hip Thrust" }
        XCTAssertEqual(hipThrust?.sets, 4)
        XCTAssertEqual(hipThrust?.reps, "8–12")
    }

    func testMobilityGroupIsPopulated() {
        XCTAssertGreaterThanOrEqual(ExerciseCatalog.exercises(in: .mobility).count, 6)
        for name in ["Wall Slide", "Doorway Pec Stretch", "Chin Tuck", "Band External Rotation", "Cable Y-Raise",
                     "Cross-Body Cable Triceps Extension", "Single-Leg Leg Press", "Cable Diagonal Kickback",
                     "Glute-Biased Back Extension", "Neutral-Grip Lat Pulldown", "Cable Romanian Deadlift"] {
            XCTAssertNotNil(ExerciseCatalog.definition(named: name), "missing \(name)")
        }
    }
}
