import Foundation

// MARK: - Unit-aware display

/// Everything is *stored* metric (kg, cm, km, litres). These helpers are the
/// single place that converts to and from what the user actually sees, so a
/// screen never has to know which system is active — it asks the profile's
/// `UnitSystem` and gets the right number and label back.
public extension UnitSystem {
    var isMetric: Bool { self == .metric }

    // Body weight
    var weightUnit: String { isMetric ? "kg" : "lb" }
    func displayWeight(kilograms: Double) -> Double { isMetric ? kilograms : Units.pounds(fromKilograms: kilograms) }
    func kilograms(fromDisplayWeight value: Double) -> Double { isMetric ? value : Units.kilograms(fromPounds: value) }
    func formatWeight(kilograms: Double, fractionDigits: Int = 1) -> String {
        displayWeight(kilograms: kilograms).formatted(.number.precision(.fractionLength(fractionDigits))) + " " + weightUnit
    }

    // Height
    var heightUnit: String { isMetric ? "cm" : "in" }
    func displayHeight(centimeters: Double) -> Double { isMetric ? centimeters : Units.inches(fromCentimeters: centimeters) }
    func centimeters(fromDisplayHeight value: Double) -> Double { isMetric ? value : Units.centimeters(fromInches: value) }

    // Distance and speed (cardio)
    var distanceUnit: String { isMetric ? "km" : "mi" }
    var speedUnit: String { isMetric ? "km/h" : "mph" }
    func displayDistance(kilometers: Double) -> Double { isMetric ? kilometers : Units.miles(fromKilometers: kilometers) }
    func kilometers(fromDisplayDistance value: Double) -> Double { isMetric ? value : Units.kilometers(fromMiles: value) }

    // Water
    var waterUnit: String { isMetric ? "mL" : "oz" }
    func displayWater(liters: Double) -> Double { isMetric ? liters * 1000 : Units.fluidOunces(fromLiters: liters) }
    func liters(fromDisplayWater value: Double) -> Double { isMetric ? value / 1000 : Units.liters(fromFluidOunces: value) }
    func formatWater(liters: Double) -> String {
        Int(displayWater(liters: liters).rounded()).formatted() + " " + waterUnit
    }
    /// Quick-add amounts that read as round numbers in each system:
    /// 250 / 350 / 500 mL, or 8 / 12 / 16 fl oz.
    var waterQuickAdds: [Double] { isMetric ? [0.25, 0.35, 0.5] : [0.237, 0.355, 0.473] }
    func waterQuickAddLabel(liters: Double) -> String { "+" + formatWater(liters: liters) }
}

public extension ActivityLevel {
    /// Human-readable label. `String(describing:)` gave "veryActive".
    var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .veryActive: return "Very active"
        }
    }
    var detail: String {
        switch self {
        case .sedentary: return "Desk work, little exercise"
        case .light: return "Light exercise 1–3 days a week"
        case .moderate: return "Moderate exercise 3–5 days a week"
        case .veryActive: return "Hard exercise 6–7 days a week"
        }
    }
}

public extension Meal {
    var label: String { rawValue.capitalized }

    /// The meal a food logged at this hour most likely belongs to, so the
    /// picker opens on the right one instead of always on Breakfast.
    static func inferred(hour: Int) -> Meal {
        switch hour {
        case ..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<17: return .snacks
        case 17..<21: return .dinner
        default: return .snacks
        }
    }
}

public extension GoalMode {
    var label: String {
        switch self {
        case .cut: return "Cut"
        case .maintain: return "Maintain / Recomp"
        case .bulk: return "Bulk"
        }
    }
}

// MARK: - Demo fixtures

/// The exact values the original demo seeder wrote into the *real* store
/// (it had no separate container). `DemoCleanup` in the app uses these
/// signatures to find and remove those rows. Kept here so the matching can be
/// tested, and so the app can never drift from the values it is looking for.
public enum LegacyDemoFixtures {
    public static let foodName = "Greek Yogurt Bowl"
    public static let foodPer100 = Macro(calories: 120, protein: 10, carbs: 14, fat: 3)
    public static let foodLogGrams = 250.0
    public static let workoutNames: Set<String> = ["Lower Body A", "Upper Body"]
    public static let workoutExercise = "Hip Thrust"
    public static let workoutReps = 10

    /// (steps, activeCalories) for each of the 36 seeded days.
    public static let activityPairs: Set<ActivityPair> = Set((-35...0).map { offset in
        ActivityPair(steps: Double(7000 + abs(offset * 379) % 6000),
                     activeCalories: Double(250 + abs(offset * 31) % 350))
    })
    public static let waterLiters: Set<Double> = Set((-35...0).map { Double(14 + abs($0) % 8) / 10 })
    public static let weightsKG: [Double] = (-35...0).map { 70 + Double($0) * 0.035 }

    public struct ActivityPair: Hashable, Sendable {
        public let steps: Double
        public let activeCalories: Double
        public init(steps: Double, activeCalories: Double) { self.steps = steps; self.activeCalories = activeCalories }
    }

    public static func isFixtureActivity(steps: Double, activeCalories: Double) -> Bool {
        activityPairs.contains(ActivityPair(steps: steps, activeCalories: activeCalories))
    }
    public static func isFixtureWater(liters: Double) -> Bool {
        waterLiters.contains { abs($0 - liters) < 0.000_1 }
    }
    public static func isFixtureWeight(kilograms: Double) -> Bool {
        weightsKG.contains { abs($0 - kilograms) < 0.000_1 }
    }
    public static func isFixtureFood(name: String, per100: Macro) -> Bool {
        name == foodName && per100 == foodPer100
    }
    public static func isFixtureFoodLog(name: String, grams: Double) -> Bool {
        name == foodName && abs(grams - foodLogGrams) < 0.000_1
    }
}
