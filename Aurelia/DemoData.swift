import Foundation
import SwiftData

/// Populates the demo container with a believable five weeks of history.
/// Only ever runs against `Persistence.makeDemoContainer()`.
enum DemoData {
    @MainActor
    static func seed(into container: ModelContainer) {
        let context = container.mainContext
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let profile = AppProfile(name: "Demo", age: 31, sex: .female, heightCM: 168, currentKG: 68.2, goalKG: 64,
                                 activity: .moderate, units: .imperial, goal: .cut, calorieTarget: 1750,
                                 proteinTarget: 125, stepTarget: 9_000, waterTargetLiters: 2.2, onboarded: true)
        context.insert(profile)
        context.insert(SupplementEntity(name: "Creatine", order: 0))
        context.insert(SupplementEntity(name: "Vitamin D", order: 1))
        context.insert(SupplementEntity(name: "Omega-3", order: 2))

        let lower = TemplateEntity(name: "Lower Body A", weekday: 2, exerciseNames: ["Hip Thrust", "Romanian Deadlift", "Leg Press", "Hip Abduction"], defaultSets: 3)
        let upper = TemplateEntity(name: "Upper Body", weekday: 4, exerciseNames: ["Lat Pulldown", "Seated Row", "Shoulder Press", "Lateral Raise"], defaultSets: 3)
        let lowerB = TemplateEntity(name: "Lower Body B", weekday: 6, exerciseNames: ["Leg Press", "Hamstring Curl", "Leg Extension", "Plank"], defaultSets: 3)
        [lower, upper, lowerB].forEach(context.insert)

        let foods: [(FoodEntity, Meal, Double)] = [
            (FoodEntity(name: "Greek Yogurt, 2%", brand: "Fage", calories100: 97, protein100: 9, carbs100: 4, fat100: 5, servingGrams: 170), .breakfast, 170),
            (FoodEntity(name: "Blueberries", calories100: 57, protein100: 0.7, carbs100: 14, fat100: 0.3, servingGrams: 100), .breakfast, 100),
            (FoodEntity(name: "Chicken Breast, grilled", calories100: 165, protein100: 31, carbs100: 0, fat100: 3.6, servingGrams: 150), .lunch, 150),
            (FoodEntity(name: "Jasmine Rice, cooked", calories100: 130, protein100: 2.7, carbs100: 28, fat100: 0.3, servingGrams: 180), .lunch, 180),
            (FoodEntity(name: "Salmon, baked", calories100: 208, protein100: 20, carbs100: 0, fat100: 13, servingGrams: 140), .dinner, 140),
            (FoodEntity(name: "Sweet Potato", calories100: 86, protein100: 1.6, carbs100: 20, fat100: 0.1, servingGrams: 200), .dinner, 200),
            (FoodEntity(name: "Protein Shake", brand: "Whey", calories100: 380, protein100: 75, carbs100: 8, fat100: 5, servingGrams: 32), .snacks, 32),
            (FoodEntity(name: "Almonds", calories100: 579, protein100: 21, carbs100: 22, fat100: 50, servingGrams: 28), .snacks, 28),
        ]
        foods.forEach { context.insert($0.0) }

        var rng = SeededGenerator(seed: 7)
        for offset in -35...0 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let noon = calendar.date(byAdding: .hour, value: 12, to: day)!
            let weekday = calendar.component(.weekday, from: day)

            // Activity: a rest-day / training-day rhythm with noise.
            let trained = [2, 4, 6].contains(weekday)
            let baseSteps: Int = trained ? 9_800 : 6_900
            let stepNoise: Int = Int(rng.next() % 2_400)
            let baseActive: Int = trained ? 420 : 260
            let activeNoise: Int = Int(rng.next() % 120)
            let basal: Double = 1_420 + Double(rng.next() % 60)
            let heartRate: Double = 66 + Double(rng.next() % 9)
            context.insert(ActivityEntity(date: day, steps: Double(baseSteps + stepNoise), activeCalories: Double(baseActive + activeNoise),
                                          basalCalories: basal, averageHeartRate: heartRate))

            // Water: three or four quick-adds.
            for _ in 0..<(3 + Int(rng.next() % 2)) {
                context.insert(WaterEntity(date: noon, liters: [0.355, 0.473, 0.5].randomElement(using: &rng)!))
            }

            // Weight: gentle downward trend with daily noise, logged most mornings.
            if rng.next() % 5 != 0 {
                let trend: Double = Double(offset) * 0.06
                let noise: Double = (Double(rng.next() % 60) - 30) / 100
                let kg: Double = 70.4 + trend + noise
                let rounded: Double = (kg * 10).rounded() / 10
                context.insert(WeightEntity(date: calendar.date(byAdding: .hour, value: 7, to: day)!, kilograms: rounded))
            }

            // Workouts on training days.
            if trained {
                let template = weekday == 2 ? lower : (weekday == 4 ? upper : lowerB)
                var exercises: [SessionExerciseEntity] = []
                for (index, name) in template.exerciseNames.enumerated() {
                    let base: Double = name == "Hip Thrust" ? 70.0 : (name.contains("Press") ? 60.0 : 25.0)
                    let progress: Double = Double(35 + offset) * 0.25
                    let weight: Double = ((base + progress) * 2).rounded() / 2
                    var sets: [SetEntity] = []
                    for setIndex in 0..<3 {
                        let reps: Int = 8 + Int(rng.next() % 4)
                        sets.append(SetEntity(order: setIndex, weightKG: weight, reps: reps))
                    }
                    exercises.append(SessionExerciseEntity(name: name, order: index, sets: sets))
                }
                let duration: Double = 48 + Double(rng.next() % 15)
                let workout = WorkoutEntity(date: calendar.date(byAdding: .hour, value: 18, to: day)!, name: template.name,
                                            completed: true, durationMinutes: duration, exercises: exercises)
                context.insert(workout)
            } else if weekday == 1 {
                let walkMinutes: Double = 40 + Double(rng.next() % 20)
                let walk = WorkoutEntity(date: calendar.date(byAdding: .hour, value: 9, to: day)!, name: "Outdoor Walking",
                                         completed: true, isCardio: true, durationMinutes: walkMinutes)
                let tenthsKM: Double = Double(rng.next() % 20) / 10
                walk.distanceKM = 4 + tenthsKM
                context.insert(walk)
            }

            // Food: most meals most days, a little variety in amounts.
            for (food, meal, grams) in foods where rng.next() % 6 != 0 {
                let jitter: Double = 0.85 + Double(rng.next() % 30) / 100
                let portion: Double = (grams * jitter).rounded()
                let mealHour: Int = [Meal.breakfast: 8, .lunch: 12, .dinner: 19, .snacks: 15][meal] ?? 12
                context.insert(FoodLogEntity(date: calendar.date(byAdding: .hour, value: mealHour, to: day)!,
                                             meal: meal, food: food, grams: portion))
                food.useCount += 1
                food.lastUsed = day
            }

            // Supplements: usually taken.
            if rng.next() % 4 != 0 {
                context.insert(SupplementCheckEntity(date: noon, name: "Creatine"))
                context.insert(SupplementCheckEntity(date: noon, name: "Vitamin D"))
            }
        }

        try? context.save()
    }

    /// Deterministic so the demo looks the same every launch.
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}

/// Finds and removes the rows the *original* demo seeder wrote into the real
/// store. It seeded the same fixed values every time, so they are recognisable
/// by exact signature (see `LegacyDemoFixtures` in WellnessCore).
///
/// This is deliberately a two-step flow — count first, delete on confirmation —
/// and matches on full signatures, never on a single field, so a user's own
/// records with a coincidentally similar value are not touched.
enum DemoCleanup {
    struct Report: Equatable {
        var foods = 0, foodLogs = 0, workouts = 0, activity = 0, water = 0, weights = 0
        var total: Int { foods + foodLogs + workouts + activity + water + weights }
        var summary: String {
            [("food", foods), ("food log", foodLogs), ("workout", workouts), ("activity day", activity), ("water", water), ("weight", weights)]
                .filter { $0.1 > 0 }
                .map { "\($0.1) \($0.0)\($0.1 == 1 ? "" : "s")" }
                .joined(separator: ", ")
        }
    }

    @MainActor
    static func scan(context: ModelContext) -> Report {
        var report = Report()
        report.foods = fixtureFoods(context).count
        report.foodLogs = fixtureFoodLogs(context).count
        report.workouts = fixtureWorkouts(context).count
        report.activity = fixtureActivity(context).count
        report.water = fixtureWater(context).count
        report.weights = fixtureWeights(context).count
        return report
    }

    @MainActor
    static func remove(context: ModelContext) throws -> Report {
        let report = scan(context: context)
        fixtureFoodLogs(context).forEach(context.delete)
        fixtureFoods(context).forEach(context.delete)
        fixtureWorkouts(context).forEach(context.delete)
        fixtureActivity(context).forEach(context.delete)
        fixtureWater(context).forEach(context.delete)
        fixtureWeights(context).forEach(context.delete)
        try context.save()
        return report
    }

    private static func all<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }
    private static func fixtureFoods(_ c: ModelContext) -> [FoodEntity] {
        all(FoodEntity.self, c).filter {
            LegacyDemoFixtures.isFixtureFood(name: $0.name, per100: Macro(calories: $0.calories100, protein: $0.protein100, carbs: $0.carbs100, fat: $0.fat100))
        }
    }
    private static func fixtureFoodLogs(_ c: ModelContext) -> [FoodLogEntity] {
        all(FoodLogEntity.self, c).filter { LegacyDemoFixtures.isFixtureFoodLog(name: $0.foodName, grams: $0.grams) }
    }
    private static func fixtureWorkouts(_ c: ModelContext) -> [WorkoutEntity] {
        all(WorkoutEntity.self, c).filter { workout in
            guard LegacyDemoFixtures.workoutNames.contains(workout.name), workout.completed, !workout.isCardio,
                  workout.exercises.count == 1, let exercise = workout.exercises.first,
                  exercise.name == LegacyDemoFixtures.workoutExercise, exercise.sets.count == 1,
                  let set = exercise.sets.first, set.reps == LegacyDemoFixtures.workoutReps else { return false }
            return true
        }
    }
    private static func fixtureActivity(_ c: ModelContext) -> [ActivityEntity] {
        all(ActivityEntity.self, c).filter {
            $0.basalCalories == nil && $0.averageHeartRate == nil
                && LegacyDemoFixtures.isFixtureActivity(steps: $0.steps, activeCalories: $0.activeCalories)
        }
    }
    private static func fixtureWater(_ c: ModelContext) -> [WaterEntity] {
        all(WaterEntity.self, c).filter { LegacyDemoFixtures.isFixtureWater(liters: $0.liters) }
    }
    private static func fixtureWeights(_ c: ModelContext) -> [WeightEntity] {
        all(WeightEntity.self, c).filter { $0.source == "Manual" && LegacyDemoFixtures.isFixtureWeight(kilograms: $0.kilograms) }
    }
}
