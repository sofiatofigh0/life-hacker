import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Reads every SwiftData model into the plain-value `AureliaExport` defined in
/// WellnessCore, and writes it as JSON.
enum ExportService {
    /// Builds a snapshot of the whole database.
    static func snapshot(context: ModelContext) throws -> AureliaExport {
        func all<T: PersistentModel>(_ type: T.Type) throws -> [T] {
            try context.fetch(FetchDescriptor<T>())
        }

        let profile = try all(AppProfile.self).first.map {
            ProfileRecord(name: $0.name, age: $0.age, sex: $0.sexRaw, heightCM: $0.heightCM,
                          currentKG: $0.currentKG, goalKG: $0.goalKG, targetDate: $0.targetDate,
                          activity: $0.activityRaw, units: $0.unitRaw, goal: $0.goalRaw,
                          calorieTarget: $0.calorieTarget, proteinTarget: $0.proteinTarget,
                          stepTarget: $0.stepTarget, waterTargetLiters: $0.waterTargetLiters,
                          onboarded: $0.onboarded, demoMode: $0.demoMode)
        }

        let workouts = try all(WorkoutEntity.self).map { workout in
            WorkoutRecord(
                date: workout.date, name: workout.name, completed: workout.completed,
                isCardio: workout.isCardio, durationMinutes: workout.durationMinutes,
                distanceKM: workout.distanceKM, incline: workout.incline, speedKPH: workout.speedKPH,
                calories: workout.calories, averageHeartRate: workout.averageHeartRate,
                notes: workout.notes,
                exercises: workout.exercises.sorted { $0.order < $1.order }.map { exercise in
                    WorkoutExerciseRecord(
                        exerciseName: exercise.name,
                        sets: exercise.sets.sorted { $0.order < $1.order }
                            .map { ExerciseSetRecord(weightKG: $0.weightKG, reps: $0.reps) })
                })
        }

        return AureliaExport(
            schemaVersion: Persistence.schemaVersionString,
            profile: profile,
            templates: try all(TemplateEntity.self).map {
                TemplateRecord(name: $0.name, weekday: $0.weekday, exerciseNames: $0.exerciseNames,
                               defaultSets: $0.defaultSets, repRange: $0.repRange)
            },
            workouts: workouts,
            foods: try all(FoodEntity.self).map {
                FoodRecord(name: $0.name, brand: $0.brand, barcode: $0.barcode,
                           calories100: $0.calories100, protein100: $0.protein100,
                           carbs100: $0.carbs100, fat100: $0.fat100, servingGrams: $0.servingGrams,
                           favorite: $0.favorite, useCount: $0.useCount, lastUsed: $0.lastUsed)
            },
            foodLogs: try all(FoodLogEntity.self).map {
                FoodLogRecord(date: $0.date, meal: $0.mealRaw, foodName: $0.foodName, grams: $0.grams,
                              calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat)
            },
            water: try all(WaterEntity.self).map { WaterRecord(date: $0.date, liters: $0.liters) },
            supplements: try all(SupplementEntity.self).map { SupplementRecord(name: $0.name, order: $0.order) },
            supplementChecks: try all(SupplementCheckEntity.self).map {
                SupplementCheckRecord(date: $0.date, supplementName: $0.supplementName)
            },
            weights: try all(WeightEntity.self).map {
                WeightRecord(date: $0.date, kilograms: $0.kilograms, source: $0.source)
            },
            activity: try all(ActivityEntity.self).map {
                ActivityRecord(date: $0.date, steps: $0.steps, activeCalories: $0.activeCalories,
                               basalCalories: $0.basalCalories, averageHeartRate: $0.averageHeartRate)
            },
            photoSets: try all(PhotoSetEntity.self).map {
                PhotoSetRecord(date: $0.date, front: $0.front, side: $0.side, back: $0.back, isDemo: $0.isDemo)
            },
            customExercises: try all(ExerciseEntity.self).filter(\.isCustom).map {
                CustomExerciseRecord(name: $0.name, summary: $0.summary, tips: $0.tips.components(separatedBy: "\n"))
            })
    }

    /// Writes the snapshot to a temporary file and returns it for sharing.
    static func writeFile(context: ModelContext) throws -> (url: URL, records: Int) {
        let export = try snapshot(context: context)
        let data = try AureliaExport.makeEncoder().encode(export)

        let stamp = Date.now.formatted(.iso8601.year().month().day()
            .dateSeparator(.dash).timeSeparator(.omitted).time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Aurelia-Export-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return (url, export.recordCount)
    }
}

/// A file ready to hand to the share sheet. `Identifiable` so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
    let records: Int
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
