import Foundation
import SwiftData

/// The inverse of `ExportService`: reads an `AureliaExport` JSON file back
/// into the store.
///
/// Semantics are deliberately simple and predictable: **replace**. Every
/// user-entered row is deleted and the file's rows are inserted. The built-in
/// exercise library is not touched (it is re-seeded from the catalog anyway);
/// custom exercises come from the file. Progress photo *files* are not in the
/// export — the rows are restored and will show the images if the files are
/// still in the app's Documents directory (same device), or a placeholder if not.
enum ImportService {
    enum ImportError: LocalizedError {
        case unreadable, unsupportedVersion(Int), empty
        var errorDescription: String? {
            switch self {
            case .unreadable: return "That file isn't an Aurelia export."
            case .unsupportedVersion(let v): return "This export is format version \(v); this app reads version \(AureliaExport.currentFormatVersion)."
            case .empty: return "The export contains no records."
            }
        }
    }

    /// Parses and validates without changing anything.
    static func preview(url: URL) throws -> AureliaExport {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let export: AureliaExport
        do { export = try AureliaExport.makeDecoder().decode(AureliaExport.self, from: data) }
        catch { throw ImportError.unreadable }
        guard export.formatVersion <= AureliaExport.currentFormatVersion else { throw ImportError.unsupportedVersion(export.formatVersion) }
        guard export.recordCount > 0 else { throw ImportError.empty }
        return export
    }

    /// Replaces all user data with the export's contents.
    @MainActor
    static func restore(_ export: AureliaExport, context: ModelContext) throws {
        try deleteUserData(context: context)

        if let p = export.profile {
            let profile = AppProfile(name: p.name, age: p.age, sex: Sex(rawValue: p.sex) ?? .female, heightCM: p.heightCM,
                                     currentKG: p.currentKG, goalKG: p.goalKG, targetDate: p.targetDate,
                                     activity: Double(p.activity).flatMap(ActivityLevel.init(rawValue:)) ?? .moderate,
                                     units: UnitSystem(rawValue: p.units) ?? .imperial, goal: GoalMode(rawValue: p.goal) ?? .maintain,
                                     calorieTarget: p.calorieTarget, proteinTarget: p.proteinTarget, stepTarget: p.stepTarget,
                                     waterTargetLiters: p.waterTargetLiters, onboarded: p.onboarded)
            context.insert(profile)
        }
        for t in export.templates {
            context.insert(TemplateEntity(name: t.name, weekday: t.weekday, exerciseNames: t.exerciseNames, defaultSets: t.defaultSets, repRange: t.repRange))
        }
        for w in export.workouts {
            let exercises = w.exercises.enumerated().map { index, exercise in
                SessionExerciseEntity(name: exercise.exerciseName, order: index,
                                      sets: exercise.sets.enumerated().map { setIndex, set in
                                          SetEntity(order: setIndex, weightKG: set.weightKG, reps: set.reps,
                                                    completed: set.completed ?? (set.reps > 0), isWarmup: set.isWarmup ?? false, rpe: set.rpe)
                                      },
                                      notes: exercise.notes ?? "")
            }
            let workout = WorkoutEntity(date: w.date, name: w.name, completed: w.completed, isCardio: w.isCardio,
                                        durationMinutes: w.durationMinutes, exercises: exercises)
            workout.distanceKM = w.distanceKM; workout.incline = w.incline; workout.speedKPH = w.speedKPH
            workout.calories = w.calories; workout.averageHeartRate = w.averageHeartRate; workout.notes = w.notes
            context.insert(workout)
        }
        for f in export.foods {
            let food = FoodEntity(name: f.name, brand: f.brand, barcode: f.barcode, calories100: f.calories100, protein100: f.protein100,
                                  carbs100: f.carbs100, fat100: f.fat100, servingGrams: f.servingGrams)
            food.favorite = f.favorite; food.useCount = f.useCount; food.lastUsed = f.lastUsed
            context.insert(food)
        }
        for l in export.foodLogs {
            context.insert(FoodLogEntity(date: l.date, mealRaw: l.meal, foodName: l.foodName, grams: l.grams,
                                         calories: l.calories, protein: l.protein, carbs: l.carbs, fat: l.fat))
        }
        for w in export.water { context.insert(WaterEntity(date: w.date, liters: w.liters)) }
        for s in export.supplements { context.insert(SupplementEntity(name: s.name, order: s.order)) }
        for c in export.supplementChecks { context.insert(SupplementCheckEntity(date: c.date, name: c.supplementName)) }
        for w in export.weights { context.insert(WeightEntity(date: w.date, kilograms: w.kilograms, source: w.source)) }
        for a in export.activity {
            context.insert(ActivityEntity(date: a.date, steps: a.steps, activeCalories: a.activeCalories,
                                          basalCalories: a.basalCalories, averageHeartRate: a.averageHeartRate))
        }
        for p in export.photoSets { context.insert(PhotoSetEntity(date: p.date, front: p.front, side: p.side, back: p.back, isDemo: p.isDemo)) }
        for e in export.customExercises ?? [] {
            context.insert(ExerciseEntity(e.name, summary: e.summary, tips: e.tips, isCustom: true))
        }
        try context.save()
    }

    @MainActor
    private static func deleteUserData(context: ModelContext) throws {
        try context.delete(model: AppProfile.self)
        try context.delete(model: TemplateEntity.self)
        try context.delete(model: WorkoutEntity.self)          // cascades to exercises and sets
        try context.delete(model: FoodEntity.self)
        try context.delete(model: FoodLogEntity.self)
        try context.delete(model: SavedMealEntity.self)
        try context.delete(model: WaterEntity.self)
        try context.delete(model: SupplementEntity.self)
        try context.delete(model: SupplementCheckEntity.self)
        try context.delete(model: WeightEntity.self)
        try context.delete(model: ActivityEntity.self)
        try context.delete(model: PhotoSetEntity.self)
        try context.delete(model: ExerciseEntity.self, where: #Predicate<ExerciseEntity> { $0.isCustom })
        try context.save()
    }
}
