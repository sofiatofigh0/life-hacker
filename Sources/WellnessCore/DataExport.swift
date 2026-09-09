import Foundation

/// Plain-value mirrors of the SwiftData models, used for backup/export.
///
/// These deliberately live in `WellnessCore` rather than the app target: they
/// carry no SwiftData or SwiftUI dependency, so the encoding is testable on any
/// platform. The app maps its `@Model` classes onto these and writes JSON.
///
/// `formatVersion` is the contract for anything that reads an export back.
/// Bump it whenever a field changes meaning or disappears; adding an optional
/// field does not require a bump.
public struct AureliaExport: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var exportedAt: Date
    public var schemaVersion: String
    public var profile: ProfileRecord?
    public var templates: [TemplateRecord]
    public var workouts: [WorkoutRecord]
    public var foods: [FoodRecord]
    public var foodLogs: [FoodLogRecord]
    public var water: [WaterRecord]
    public var supplements: [SupplementRecord]
    public var supplementChecks: [SupplementCheckRecord]
    public var weights: [WeightRecord]
    public var activity: [ActivityRecord]
    public var photoSets: [PhotoSetRecord]

    public init(formatVersion: Int = AureliaExport.currentFormatVersion,
                exportedAt: Date = .now,
                schemaVersion: String,
                profile: ProfileRecord? = nil,
                templates: [TemplateRecord] = [],
                workouts: [WorkoutRecord] = [],
                foods: [FoodRecord] = [],
                foodLogs: [FoodLogRecord] = [],
                water: [WaterRecord] = [],
                supplements: [SupplementRecord] = [],
                supplementChecks: [SupplementCheckRecord] = [],
                weights: [WeightRecord] = [],
                activity: [ActivityRecord] = [],
                photoSets: [PhotoSetRecord] = []) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.schemaVersion = schemaVersion
        self.profile = profile
        self.templates = templates
        self.workouts = workouts
        self.foods = foods
        self.foodLogs = foodLogs
        self.water = water
        self.supplements = supplements
        self.supplementChecks = supplementChecks
        self.weights = weights
        self.activity = activity
        self.photoSets = photoSets
    }

    /// Total rows in the export, for the confirmation the app shows the user.
    public var recordCount: Int {
        (profile == nil ? 0 : 1) + templates.count + workouts.count + foods.count + foodLogs.count
            + water.count + supplements.count + supplementChecks.count + weights.count
            + activity.count + photoSets.count
    }

    /// The encoder every export is written with. Dates are ISO 8601 so the file
    /// stays readable and unambiguous outside this app.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// The matching decoder, for reading an export back.
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public struct ProfileRecord: Codable, Equatable, Sendable {
    public var name: String, age: Int, sex: String
    public var heightCM: Double, currentKG: Double, goalKG: Double
    public var targetDate: Date, activity: String, units: String, goal: String
    public var calorieTarget: Int, proteinTarget: Int, stepTarget: Int, waterTargetLiters: Double
    public var onboarded: Bool, demoMode: Bool
    public init(name: String, age: Int, sex: String, heightCM: Double, currentKG: Double, goalKG: Double,
                targetDate: Date, activity: String, units: String, goal: String, calorieTarget: Int,
                proteinTarget: Int, stepTarget: Int, waterTargetLiters: Double, onboarded: Bool, demoMode: Bool) {
        self.name = name; self.age = age; self.sex = sex; self.heightCM = heightCM
        self.currentKG = currentKG; self.goalKG = goalKG; self.targetDate = targetDate
        self.activity = activity; self.units = units; self.goal = goal
        self.calorieTarget = calorieTarget; self.proteinTarget = proteinTarget
        self.stepTarget = stepTarget; self.waterTargetLiters = waterTargetLiters
        self.onboarded = onboarded; self.demoMode = demoMode
    }
}

public struct TemplateRecord: Codable, Equatable, Sendable {
    public var name: String, weekday: Int, exerciseNames: [String], defaultSets: Int, repRange: String
    public init(name: String, weekday: Int, exerciseNames: [String], defaultSets: Int, repRange: String) {
        self.name = name; self.weekday = weekday; self.exerciseNames = exerciseNames
        self.defaultSets = defaultSets; self.repRange = repRange
    }
}

public struct WorkoutRecord: Codable, Equatable, Sendable {
    public var date: Date, name: String, completed: Bool, isCardio: Bool, durationMinutes: Double
    public var distanceKM: Double?, incline: Double?, speedKPH: Double?
    public var calories: Double?, averageHeartRate: Double?, notes: String
    public var exercises: [WorkoutExerciseRecord]
    public init(date: Date, name: String, completed: Bool, isCardio: Bool, durationMinutes: Double,
                distanceKM: Double?, incline: Double?, speedKPH: Double?, calories: Double?,
                averageHeartRate: Double?, notes: String, exercises: [WorkoutExerciseRecord]) {
        self.date = date; self.name = name; self.completed = completed; self.isCardio = isCardio
        self.durationMinutes = durationMinutes; self.distanceKM = distanceKM; self.incline = incline
        self.speedKPH = speedKPH; self.calories = calories; self.averageHeartRate = averageHeartRate
        self.notes = notes; self.exercises = exercises
    }
}

public struct FoodRecord: Codable, Equatable, Sendable {
    public var name: String, brand: String, barcode: String?
    public var calories100: Double, protein100: Double, carbs100: Double, fat100: Double
    public var servingGrams: Double, favorite: Bool, useCount: Int, lastUsed: Date?
    public init(name: String, brand: String, barcode: String?, calories100: Double, protein100: Double,
                carbs100: Double, fat100: Double, servingGrams: Double, favorite: Bool,
                useCount: Int, lastUsed: Date?) {
        self.name = name; self.brand = brand; self.barcode = barcode; self.calories100 = calories100
        self.protein100 = protein100; self.carbs100 = carbs100; self.fat100 = fat100
        self.servingGrams = servingGrams; self.favorite = favorite; self.useCount = useCount; self.lastUsed = lastUsed
    }
}

public struct FoodLogRecord: Codable, Equatable, Sendable {
    public var date: Date, meal: String, foodName: String, grams: Double
    public var calories: Double, protein: Double, carbs: Double, fat: Double
    public init(date: Date, meal: String, foodName: String, grams: Double, calories: Double,
                protein: Double, carbs: Double, fat: Double) {
        self.date = date; self.meal = meal; self.foodName = foodName; self.grams = grams
        self.calories = calories; self.protein = protein; self.carbs = carbs; self.fat = fat
    }
}

public struct WaterRecord: Codable, Equatable, Sendable {
    public var date: Date, liters: Double
    public init(date: Date, liters: Double) { self.date = date; self.liters = liters }
}

public struct SupplementRecord: Codable, Equatable, Sendable {
    public var name: String, order: Int
    public init(name: String, order: Int) { self.name = name; self.order = order }
}

public struct SupplementCheckRecord: Codable, Equatable, Sendable {
    public var date: Date, supplementName: String
    public init(date: Date, supplementName: String) { self.date = date; self.supplementName = supplementName }
}

public struct WeightRecord: Codable, Equatable, Sendable {
    public var date: Date, kilograms: Double, source: String
    public init(date: Date, kilograms: Double, source: String) {
        self.date = date; self.kilograms = kilograms; self.source = source
    }
}

public struct ActivityRecord: Codable, Equatable, Sendable {
    public var date: Date, steps: Double, activeCalories: Double
    public var basalCalories: Double?, averageHeartRate: Double?
    public init(date: Date, steps: Double, activeCalories: Double, basalCalories: Double?, averageHeartRate: Double?) {
        self.date = date; self.steps = steps; self.activeCalories = activeCalories
        self.basalCalories = basalCalories; self.averageHeartRate = averageHeartRate
    }
}

/// Photo *files* are not embedded — only the filenames inside the app's private
/// Documents directory. Embedding several megabytes of JPEG per set would make
/// the export unusable, and the images are covered by an encrypted device backup.
public struct PhotoSetRecord: Codable, Equatable, Sendable {
    public var date: Date, front: String, side: String, back: String, isDemo: Bool
    public init(date: Date, front: String, side: String, back: String, isDemo: Bool) {
        self.date = date; self.front = front; self.side = side; self.back = back; self.isDemo = isDemo
    }
}
