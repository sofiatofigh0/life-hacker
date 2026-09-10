import XCTest
@testable import WellnessCore

final class FoodCatalogTests: XCTestCase {
    func testNamesAreUnique() {
        let names = FoodCatalog.all.map(\.name)
        let duplicates = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys
        XCTAssertTrue(duplicates.isEmpty, "duplicate food names: \(Array(duplicates))")
    }

    func testCatalogCoversEveryCategory() {
        XCTAssertGreaterThanOrEqual(FoodCatalog.all.count, 120)
        for category in FoodCategory.allCases {
            XCTAssertGreaterThanOrEqual(FoodCatalog.foods(in: category).count, 5, "\(category.label) is thin")
        }
    }

    /// A sanity check that the numbers are per 100 g: energy from macros
    /// (4/4/9) should land near the stated calories for every entry.
    func testMacrosRoughlyExplainCalories() {
        // Alcohol is 7 kcal/g and not a macro, so wine and beer are exempt.
        for food in FoodCatalog.all where !["Wine, red", "Beer"].contains(food.name) {
            let fromMacros = food.per100.protein * 4 + food.per100.carbs * 4 + food.per100.fat * 9
            let tolerance = max(30, food.per100.calories * 0.25)
            XCTAssertEqual(fromMacros, food.per100.calories, accuracy: tolerance, "\(food.name): \(fromMacros) kcal from macros vs \(food.per100.calories) stated")
        }
    }

    func testServingsArePositive() {
        for food in FoodCatalog.all {
            XCTAssertGreaterThan(food.servingGrams, 0, food.name)
            XCTAssertFalse(food.servingLabel.isEmpty, food.name)
        }
    }

    func testSnapshotFromDefinition() {
        let chicken = FoodCatalog.definition(named: "Chicken Breast, cooked")!
        let snapshot = FoodSnapshot(name: chicken.name, nutrientsPer100Grams: chicken.per100, servingGrams: chicken.servingGrams)
        XCTAssertEqual(snapshot.nutrients(grams: 120).protein, 37.2, accuracy: 0.01)
    }
}
