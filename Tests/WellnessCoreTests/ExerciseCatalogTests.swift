import XCTest
@testable import WellnessCore

final class ExerciseCatalogTests: XCTestCase {
    func testNamesAreUnique() {
        let names = ExerciseCatalog.all.map(\.name)
        let duplicates = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys
        XCTAssertTrue(duplicates.isEmpty, "duplicate exercise names: \(Array(duplicates))")
    }

    func testCatalogIsThorough() {
        XCTAssertGreaterThanOrEqual(ExerciseCatalog.all.count, 150)
        for group in MuscleGroup.allCases {
            XCTAssertGreaterThanOrEqual(ExerciseCatalog.exercises(in: group).count, 6, "\(group.label) is thin")
        }
        for equipment in Equipment.allCases {
            XCTAssertTrue(ExerciseCatalog.all.contains { $0.equipment == equipment }, "no \(equipment.label) exercises")
        }
    }

    func testEveryEntryHasGuidance() {
        for definition in ExerciseCatalog.all {
            XCTAssertFalse(definition.summary.isEmpty, definition.name)
            XCTAssertFalse(definition.tips.isEmpty, "\(definition.name) has no form tips")
            XCTAssertTrue(definition.tips.allSatisfy { !$0.isEmpty }, definition.name)
        }
    }

    /// The demo seeder, the legacy-fixture cleanup, and any user template refer
    /// to exercises by name. These names must never disappear or be renamed.
    func testStableNamesStillExist() {
        let required = ["Hip Thrust", "Romanian Deadlift", "Leg Press", "Hip Abduction", "Lat Pulldown", "Seated Row",
                        "Shoulder Press", "Lateral Raise", "Hamstring Curl", "Leg Extension", "Plank", "Bicep Curl", "Tricep Pushdown"]
        for name in required { XCTAssertNotNil(ExerciseCatalog.definition(named: name), "missing \(name)") }
    }

    func testLookupAndSubtitle() {
        let hipThrust = ExerciseCatalog.definition(named: "Hip Thrust")
        XCTAssertEqual(hipThrust?.muscleGroup, .glutes)
        XCTAssertEqual(hipThrust?.equipment, .barbell)
        XCTAssertEqual(hipThrust?.subtitle, "Glutes · Barbell")
        XCTAssertNil(ExerciseCatalog.definition(named: "Not An Exercise"))
    }
}
