import Foundation

public enum UnitSystem: String, Codable, CaseIterable, Sendable { case imperial, metric }
public enum GoalMode: String, Codable, CaseIterable, Sendable { case cut, maintain, bulk }
public enum Sex: String, Codable, CaseIterable, Sendable { case female, male, other }
public enum ActivityLevel: Double, Codable, CaseIterable, Sendable {
    case sedentary = 1.2, light = 1.375, moderate = 1.55, veryActive = 1.725
}
public enum Meal: String, Codable, CaseIterable, Sendable { case breakfast, lunch, dinner, snacks }

public struct Macro: Codable, Equatable, Sendable {
    public var calories: Double; public var protein: Double; public var carbs: Double; public var fat: Double
    public init(calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.calories = calories; self.protein = protein; self.carbs = carbs; self.fat = fat
    }
    public static func + (lhs: Self, rhs: Self) -> Self {
        .init(calories: lhs.calories + rhs.calories, protein: lhs.protein + rhs.protein,
              carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat)
    }
    public func scaled(by amount: Double) -> Self {
        .init(calories: calories * amount, protein: protein * amount, carbs: carbs * amount, fat: fat * amount)
    }
}

public enum Units {
    public static func kilograms(fromPounds value: Double) -> Double { value * 0.45359237 }
    public static func pounds(fromKilograms value: Double) -> Double { value / 0.45359237 }
    public static func centimeters(fromInches value: Double) -> Double { value * 2.54 }
    public static func inches(fromCentimeters value: Double) -> Double { value / 2.54 }
    public static func liters(fromFluidOunces value: Double) -> Double { value * 0.0295735295625 }
    public static func fluidOunces(fromLiters value: Double) -> Double { value / 0.0295735295625 }
    public static func kilometers(fromMiles value: Double) -> Double { value * 1.609344 }
    public static func miles(fromKilometers value: Double) -> Double { value / 1.609344 }
    public static func grams(fromOunces value: Double) -> Double { value * 28.349523125 }
}

public struct GoalRecommendation: Equatable, Sendable { public let calories: Int; public let proteinGrams: Int }
public enum GoalCalculator {
    public static func recommend(age: Int, sex: Sex, heightCM: Double, weightKG: Double,
                                 activity: ActivityLevel, mode: GoalMode) -> GoalRecommendation {
        let sexOffset = sex == .male ? 5.0 : (sex == .female ? -161.0 : -78.0)
        let bmr = 10 * weightKG + 6.25 * heightCM - 5 * Double(age) + sexOffset
        let adjustment = mode == .cut ? -350.0 : (mode == .bulk ? 250.0 : 0)
        let calories = max(1_200, Int((bmr * activity.rawValue + adjustment) / 10) * 10)
        let proteinMultiplier = mode == .cut ? 1.8 : 1.6
        return .init(calories: calories, proteinGrams: Int(weightKG * proteinMultiplier))
    }
    /// Targets are deliberately independent of exercise energy: calories are never "eaten back."
    public static func target(base: Int, workoutOverride: Int?, restOverride: Int?, isWorkoutDay: Bool,
                              activeCalories _: Double) -> Int {
        isWorkoutDay ? (workoutOverride ?? base) : (restOverride ?? base)
    }
}

public struct CompletionInput: Equatable, Sendable {
    public var workout: Bool; public var calories: Double; public var calorieTarget: Double
    public var protein: Double; public var proteinTarget: Double; public var steps: Double; public var stepTarget: Double
    public var waterLiters: Double; public var waterTargetLiters: Double; public var supplementFraction: Double
    public init(workout: Bool, calories: Double, calorieTarget: Double, protein: Double, proteinTarget: Double,
                steps: Double, stepTarget: Double, waterLiters: Double, waterTargetLiters: Double,
                supplementFraction: Double) {
        self.workout = workout; self.calories = calories; self.calorieTarget = calorieTarget
        self.protein = protein; self.proteinTarget = proteinTarget; self.steps = steps; self.stepTarget = stepTarget
        self.waterLiters = waterLiters; self.waterTargetLiters = waterTargetLiters; self.supplementFraction = supplementFraction
    }
}
public enum CompletionCalculator {
    public static func score(_ x: CompletionInput) -> Double {
        let calorieOK = x.calorieTarget > 0 && (0.9...1.1).contains(x.calories / x.calorieTarget)
        let value = (x.workout ? 0.30 : 0) + (calorieOK ? 0.20 : 0)
            + 0.20 * min(1, x.protein / max(1, x.proteinTarget))
            + 0.15 * min(1, x.steps / max(1, x.stepTarget))
            + 0.10 * min(1, x.waterLiters / max(0.01, x.waterTargetLiters))
            + 0.05 * min(1, max(0, x.supplementFraction))
        return min(1, max(0, value))
    }
    public static func weekly(_ days: [CompletionInput]) -> Double {
        guard !days.isEmpty else { return 0 }; return days.map(score).reduce(0, +) / Double(days.count)
    }
}

public struct FoodSnapshot: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID; public var name: String; public var brand: String?; public var barcode: String?
    public var nutrientsPer100Grams: Macro; public var servingGrams: Double?; public var isFavorite: Bool
    public init(id: UUID = UUID(), name: String, brand: String? = nil, barcode: String? = nil,
                nutrientsPer100Grams: Macro, servingGrams: Double? = nil, isFavorite: Bool = false) {
        self.id = id; self.name = name; self.brand = brand; self.barcode = barcode
        self.nutrientsPer100Grams = nutrientsPer100Grams; self.servingGrams = servingGrams; self.isFavorite = isFavorite
    }
    public func nutrients(grams: Double) -> Macro { nutrientsPer100Grams.scaled(by: grams / 100) }
}
public struct FoodLog: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID(); public var date: Date; public var meal: Meal; public var foodName: String
    public var amountGrams: Double; public var snapshot: Macro
    public init(date: Date, meal: Meal, foodName: String, amountGrams: Double, snapshot: Macro) {
        self.date = date; self.meal = meal; self.foodName = foodName; self.amountGrams = amountGrams; self.snapshot = snapshot
    }
}
public struct SavedMeal: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID(); public var name: String; public var items: [FoodLog]
    public init(name: String, items: [FoodLog]) { self.name = name; self.items = items }
    public var totals: Macro { items.map(\.snapshot).reduce(Macro(), +) }
}
public struct ExerciseSetRecord: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID(); public var weightKG: Double; public var reps: Int
    public init(weightKG: Double = 0, reps: Int = 0) { self.weightKG = weightKG; self.reps = reps }
}
public struct WorkoutExerciseRecord: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID(); public var exerciseName: String; public var sets: [ExerciseSetRecord]
    public init(exerciseName: String, sets: [ExerciseSetRecord]) { self.exerciseName = exerciseName; self.sets = sets }
}
public struct WorkoutTemplateValue: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID(); public var name: String; public var exercises: [WorkoutExerciseRecord]
    public init(name: String, exercises: [WorkoutExerciseRecord]) { self.name = name; self.exercises = exercises }
    public func session(on date: Date) -> WorkoutSessionValue { .init(date: date, name: name, exercises: exercises) }
}
public struct WorkoutSessionValue: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID(); public var date: Date; public var name: String; public var exercises: [WorkoutExerciseRecord]; public var completed = false
    public init(date: Date, name: String, exercises: [WorkoutExerciseRecord]) { self.date = date; self.name = name; self.exercises = exercises }
}
public struct WeightPoint: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID(); public var date: Date; public var kilograms: Double
    public init(date: Date, kilograms: Double) { self.date = date; self.kilograms = kilograms }
}
public enum Trends {
    public static func sevenDayAverage(_ values: [WeightPoint], through date: Date, calendar: Calendar = .current) -> Double? {
        guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: date)) else { return nil }
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let window = values.filter { $0.date >= start && $0.date < end }
        guard !window.isEmpty else { return nil }; return window.map(\.kilograms).reduce(0, +) / Double(window.count)
    }
}

public protocol NutritionProvider: Sendable { func search(_ query: String) async throws -> [FoodSnapshot]; func barcode(_ code: String) async throws -> FoodSnapshot? }
public protocol HealthProviding: Sendable { func authorize() async throws; func snapshot(for date: Date) async throws -> HealthSnapshot }
public struct HealthSnapshot: Equatable, Sendable { public var steps: Double; public var activeCalories: Double; public var basalCalories: Double?; public init(steps: Double, activeCalories: Double, basalCalories: Double? = nil) { self.steps = steps; self.activeCalories = activeCalories; self.basalCalories = basalCalories } }
