import Foundation
import SwiftData

@Model final class AppProfile {
    var name: String; var age: Int; var sexRaw: String; var heightCM: Double; var currentKG: Double; var goalKG: Double
    var targetDate: Date; var activityRaw: String; var unitRaw: String; var goalRaw: String
    var calorieTarget: Int; var proteinTarget: Int; var stepTarget: Int; var waterTargetLiters: Double
    var onboarded: Bool
    init(name: String = "", age: Int = 30, sex: Sex = .female, heightCM: Double = 165, currentKG: Double = 70,
         goalKG: Double = 65, targetDate: Date = .now, activity: ActivityLevel = .moderate,
         units: UnitSystem = .imperial, goal: GoalMode = .maintain, calorieTarget: Int = 1900,
         proteinTarget: Int = 110, stepTarget: Int = 10_000, waterTargetLiters: Double = 1.9,
         onboarded: Bool = false) {
        self.name = name; self.age = age; self.sexRaw = sex.rawValue; self.heightCM = heightCM; self.currentKG = currentKG
        self.goalKG = goalKG; self.targetDate = targetDate; self.activityRaw = String(activity.rawValue)
        self.unitRaw = units.rawValue; self.goalRaw = goal.rawValue; self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget; self.stepTarget = stepTarget; self.waterTargetLiters = waterTargetLiters
        self.onboarded = onboarded
    }
    var units: UnitSystem {
        get { UnitSystem(rawValue: unitRaw) ?? .imperial }
        set { unitRaw = newValue.rawValue }
    }
    var goal: GoalMode {
        get { GoalMode(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }
    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .female }
        set { sexRaw = newValue.rawValue }
    }
    /// Stored as the multiplier's string form ("1.55"); there was no way to read it back.
    var activity: ActivityLevel {
        get { Double(activityRaw).flatMap(ActivityLevel.init(rawValue:)) ?? .moderate }
        set { activityRaw = String(newValue.rawValue) }
    }
}

@Model final class ExerciseEntity {
    @Attribute(.unique) var name: String; var summary: String; var tips: String; var isCustom: Bool
    init(_ name: String, summary: String, tips: [String], isCustom: Bool = false) { self.name = name; self.summary = summary; self.tips = tips.joined(separator: "\n"); self.isCustom = isCustom }
}
@Model final class TemplateEntity {
    var name: String; var weekday: Int; var exerciseNames: [String]; var defaultSets: Int; var repRange: String
    init(name: String, weekday: Int = 0, exerciseNames: [String] = [], defaultSets: Int = 3, repRange: String = "8–12") { self.name = name; self.weekday = weekday; self.exerciseNames = exerciseNames; self.defaultSets = defaultSets; self.repRange = repRange }
}
@Model final class WorkoutEntity {
    var date: Date; var name: String; var completed: Bool; var isCardio: Bool; var durationMinutes: Double
    var distanceKM: Double?; var incline: Double?; var speedKPH: Double?; var calories: Double?; var averageHeartRate: Double?; var notes: String
    @Relationship(deleteRule: .cascade, inverse: \SessionExerciseEntity.workout) var exercises: [SessionExerciseEntity]
    init(date: Date = .now, name: String, completed: Bool = false, isCardio: Bool = false, durationMinutes: Double = 0, exercises: [SessionExerciseEntity] = []) { self.date = date; self.name = name; self.completed = completed; self.isCardio = isCardio; self.durationMinutes = durationMinutes; self.notes = ""; self.exercises = exercises }
}
@Model final class SessionExerciseEntity {
    var name: String; var order: Int
    /// Per-exercise note for this session ("felt heavy", "seat 4").
    var notes: String = ""
    var workout: WorkoutEntity?
    @Relationship(deleteRule: .cascade, inverse: \SetEntity.exercise) var sets: [SetEntity]
    init(name: String, order: Int, sets: [SetEntity], notes: String = "") { self.name = name; self.order = order; self.sets = sets; self.notes = notes }
}
@Model final class SetEntity {
    var order: Int; var weightKG: Double; var reps: Int
    /// Ticked off in the session. Drives the rest timer, volume, and PR checks.
    var completed: Bool = false
    var isWarmup: Bool = false
    /// Rate of perceived exertion, 6–10, optional.
    var rpe: Int?
    var exercise: SessionExerciseEntity?
    init(order: Int, weightKG: Double = 0, reps: Int = 0, completed: Bool = false, isWarmup: Bool = false, rpe: Int? = nil) {
        self.order = order; self.weightKG = weightKG; self.reps = reps; self.completed = completed; self.isWarmup = isWarmup; self.rpe = rpe
    }
}
@Model final class FoodEntity {
    var name: String; var brand: String; var barcode: String?; var calories100: Double; var protein100: Double; var carbs100: Double; var fat100: Double; var servingGrams: Double; var favorite: Bool; var useCount: Int; var lastUsed: Date?
    init(name: String, brand: String = "", barcode: String? = nil, calories100: Double, protein100: Double, carbs100: Double, fat100: Double, servingGrams: Double = 100) { self.name = name; self.brand = brand; self.barcode = barcode; self.calories100 = calories100; self.protein100 = protein100; self.carbs100 = carbs100; self.fat100 = fat100; self.servingGrams = servingGrams; self.favorite = false; self.useCount = 0 }
}
@Model final class FoodLogEntity {
    var date: Date; var mealRaw: String; var foodName: String; var grams: Double; var calories: Double; var protein: Double; var carbs: Double; var fat: Double
    init(date: Date, meal: Meal, food: FoodEntity, grams: Double) { self.date = date; self.mealRaw = meal.rawValue; self.foodName = food.name; self.grams = grams; let scale = grams / 100; self.calories = food.calories100 * scale; self.protein = food.protein100 * scale; self.carbs = food.carbs100 * scale; self.fat = food.fat100 * scale }
    /// Restores a log with the macros it was originally saved with.
    init(date: Date, mealRaw: String, foodName: String, grams: Double, calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.date = date; self.mealRaw = mealRaw; self.foodName = foodName; self.grams = grams
        self.calories = calories; self.protein = protein; self.carbs = carbs; self.fat = fat
    }
}
@Model final class SavedMealEntity { var name: String; var itemData: Data; init(name: String, items: [FoodSnapshot]) { self.name = name; self.itemData = (try? JSONEncoder().encode(items)) ?? Data() } }
@Model final class WaterEntity { var date: Date; var liters: Double; init(date: Date = .now, liters: Double) { self.date = date; self.liters = liters } }
@Model final class SupplementEntity { var name: String; var order: Int; init(name: String, order: Int = 0) { self.name = name; self.order = order } }
@Model final class SupplementCheckEntity { var date: Date; var supplementName: String; init(date: Date = .now, name: String) { self.date = date; self.supplementName = name } }
@Model final class WeightEntity { var date: Date; var kilograms: Double; var source: String; init(date: Date = .now, kilograms: Double, source: String = "Manual") { self.date = date; self.kilograms = kilograms; self.source = source } }
@Model final class ActivityEntity {
    var date: Date; var steps: Double; var activeCalories: Double; var basalCalories: Double?; var averageHeartRate: Double?
    init(date: Date, steps: Double, activeCalories: Double, basalCalories: Double? = nil, averageHeartRate: Double? = nil) {
        self.date = date; self.steps = steps; self.activeCalories = activeCalories
        self.basalCalories = basalCalories; self.averageHeartRate = averageHeartRate
    }
}
@Model final class PhotoSetEntity { var date: Date; var front: String; var side: String; var back: String; var isDemo: Bool; init(date: Date = .now, front: String, side: String, back: String, isDemo: Bool = false) { self.date = date; self.front = front; self.side = side; self.back = back; self.isDemo = isDemo } }

extension DailyScoreIndex {
    /// The index built from the app's rows. Shared by Today (score, streak)
    /// and the calendar (one ring per day).
    init(profile: AppProfile, logs: [FoodLogEntity], workouts: [WorkoutEntity], activities: [ActivityEntity],
         waters: [WaterEntity], checks: [SupplementCheckEntity], supplementCount: Int) {
        let targets = Targets(calories: Double(profile.calorieTarget), protein: Double(profile.proteinTarget),
                              steps: Double(profile.stepTarget), waterLiters: profile.waterTargetLiters)
        let food: [(date: Date, calories: Double, protein: Double)] = logs.map { (date: $0.date, calories: $0.calories, protein: $0.protein) }
        let completed: [Date] = workouts.filter(\.completed).map(\.date)
        let steps: [(date: Date, steps: Double)] = activities.map { (date: $0.date, steps: $0.steps) }
        let water: [(date: Date, liters: Double)] = waters.map { (date: $0.date, liters: $0.liters) }
        let checked: [Date] = checks.map(\.date)
        self.init(targets: targets, supplementCount: supplementCount, food: food, completedWorkouts: completed,
                  steps: steps, water: water, supplementChecks: checked)
    }
}
