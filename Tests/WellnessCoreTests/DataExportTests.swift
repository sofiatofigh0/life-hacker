import XCTest
@testable import WellnessCore

final class DataExportTests: XCTestCase {
    private func sample() -> AureliaExport {
        AureliaExport(
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            schemaVersion: "1.0.0",
            profile: ProfileRecord(name: "Sofia", age: 30, sex: "female", heightCM: 165, currentKG: 70,
                                   goalKG: 65, targetDate: Date(timeIntervalSince1970: 1_700_000_000),
                                   activity: "1.55", units: "imperial", goal: "cut", calorieTarget: 1800,
                                   proteinTarget: 120, stepTarget: 10_000, waterTargetLiters: 1.9,
                                   onboarded: true, demoMode: false),
            templates: [TemplateRecord(name: "Lower A", weekday: 2, exerciseNames: ["Hip Thrust"],
                                       defaultSets: 3, repRange: "8–12")],
            workouts: [WorkoutRecord(date: Date(timeIntervalSince1970: 1_699_900_000), name: "Lower A",
                                     completed: true, isCardio: false, durationMinutes: 45,
                                     distanceKM: nil, incline: nil, speedKPH: nil, calories: nil,
                                     averageHeartRate: nil, notes: "felt strong",
                                     exercises: [WorkoutExerciseRecord(exerciseName: "Hip Thrust",
                                                                       sets: [ExerciseSetRecord(weightKG: 60, reps: 10)])])],
            foods: [FoodRecord(name: "Greek Yogurt", brand: "", barcode: nil, calories100: 120,
                               protein100: 10, carbs100: 14, fat100: 3, servingGrams: 170,
                               favorite: true, useCount: 4, lastUsed: nil)],
            foodLogs: [FoodLogRecord(date: Date(timeIntervalSince1970: 1_699_900_000), meal: "breakfast",
                                     foodName: "Greek Yogurt", grams: 250, calories: 300, protein: 25,
                                     carbs: 35, fat: 7.5)],
            water: [WaterRecord(date: Date(timeIntervalSince1970: 1_699_900_000), liters: 0.473)],
            supplements: [SupplementRecord(name: "Creatine", order: 0)],
            supplementChecks: [SupplementCheckRecord(date: Date(timeIntervalSince1970: 1_699_900_000),
                                                     supplementName: "Creatine")],
            weights: [WeightRecord(date: Date(timeIntervalSince1970: 1_699_900_000), kilograms: 69.4, source: "Manual")],
            activity: [ActivityRecord(date: Date(timeIntervalSince1970: 1_699_900_000), steps: 9_412,
                                      activeCalories: 380, basalCalories: nil, averageHeartRate: 68)],
            photoSets: [PhotoSetRecord(date: Date(timeIntervalSince1970: 1_699_900_000),
                                       front: "progress-a.jpg", side: "progress-b.jpg",
                                       back: "progress-c.jpg", isDemo: false)])
    }

    func testRoundTripPreservesEverything() throws {
        let original = sample()
        let data = try AureliaExport.makeEncoder().encode(original)
        let restored = try AureliaExport.makeDecoder().decode(AureliaExport.self, from: data)
        XCTAssertEqual(original, restored)
    }

    func testDatesSurviveAsISO8601() throws {
        let data = try AureliaExport.makeEncoder().encode(sample())
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("2023-11-14T"), "dates should be human-readable ISO 8601, got: \(json.prefix(400))")
    }

    func testOptionalNumericsSurviveNil() throws {
        let data = try AureliaExport.makeEncoder().encode(sample())
        let restored = try AureliaExport.makeDecoder().decode(AureliaExport.self, from: data)
        XCTAssertNil(restored.workouts[0].distanceKM)
        XCTAssertNil(restored.activity[0].basalCalories)
        XCTAssertEqual(restored.activity[0].averageHeartRate, 68)
    }

    func testNestedWorkoutSetsSurvive() throws {
        let data = try AureliaExport.makeEncoder().encode(sample())
        let restored = try AureliaExport.makeDecoder().decode(AureliaExport.self, from: data)
        XCTAssertEqual(restored.workouts[0].exercises[0].exerciseName, "Hip Thrust")
        XCTAssertEqual(restored.workouts[0].exercises[0].sets[0].reps, 10)
        XCTAssertEqual(restored.workouts[0].exercises[0].sets[0].weightKG, 60)
    }

    func testRecordCountMatchesRowsWritten() {
        // 1 profile + 1 each of ten collections
        XCTAssertEqual(sample().recordCount, 11)
    }

    func testFormatVersionIsStamped() throws {
        let data = try AureliaExport.makeEncoder().encode(sample())
        let restored = try AureliaExport.makeDecoder().decode(AureliaExport.self, from: data)
        XCTAssertEqual(restored.formatVersion, AureliaExport.currentFormatVersion)
    }

    func testEmptyExportEncodes() throws {
        let empty = AureliaExport(schemaVersion: "1.0.0")
        let data = try AureliaExport.makeEncoder().encode(empty)
        let restored = try AureliaExport.makeDecoder().decode(AureliaExport.self, from: data)
        XCTAssertEqual(restored.recordCount, 0)
        XCTAssertNil(restored.profile)
    }
}
