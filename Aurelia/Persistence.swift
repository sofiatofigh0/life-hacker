import Foundation
import SwiftData

// MARK: - Schema versions

/// Version 1: the shapes the first builds shipped with. Only the models that
/// changed in V2 are frozen here; unchanged models are shared with V2 by
/// reference. SwiftData needs the old shape to compute the migration.
///
/// Never edit these — they describe what is on disk in older installs.
enum AureliaSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [AppProfile.self, ExerciseEntity.self, TemplateEntity.self, WorkoutEntity.self,
         SessionExerciseEntity.self, SetEntity.self, FoodEntity.self, FoodLogEntity.self,
         SavedMealEntity.self, WaterEntity.self, SupplementEntity.self, SupplementCheckEntity.self,
         WeightEntity.self, ActivityEntity.self, PhotoSetEntity.self]
    }

    @Model final class AppProfile {
        var name: String; var age: Int; var sexRaw: String; var heightCM: Double; var currentKG: Double; var goalKG: Double
        var targetDate: Date; var activityRaw: String; var unitRaw: String; var goalRaw: String
        var calorieTarget: Int; var proteinTarget: Int; var stepTarget: Int; var waterTargetLiters: Double
        var onboarded: Bool; var demoMode: Bool
        init() {
            name = ""; age = 30; sexRaw = "female"; heightCM = 165; currentKG = 70; goalKG = 65; targetDate = .now
            activityRaw = "1.55"; unitRaw = "imperial"; goalRaw = "maintain"; calorieTarget = 1900; proteinTarget = 110
            stepTarget = 10_000; waterTargetLiters = 1.9; onboarded = false; demoMode = false
        }
    }
    @Model final class WorkoutEntity {
        var date: Date; var name: String; var completed: Bool; var isCardio: Bool; var durationMinutes: Double
        var distanceKM: Double?; var incline: Double?; var speedKPH: Double?; var calories: Double?; var averageHeartRate: Double?; var notes: String
        @Relationship(deleteRule: .cascade) var exercises: [SessionExerciseEntity]
        init() { date = .now; name = ""; completed = false; isCardio = false; durationMinutes = 0; notes = ""; exercises = [] }
    }
    @Model final class SessionExerciseEntity {
        var name: String; var order: Int; @Relationship(deleteRule: .cascade) var sets: [SetEntity]
        init() { name = ""; order = 0; sets = [] }
    }
    @Model final class SetEntity {
        var order: Int; var weightKG: Double; var reps: Int
        init() { order = 0; weightKG = 0; reps = 0 }
    }
}

/// Version 2 (current). Changes from V1, all additive or removals that
/// lightweight migration handles:
/// - `SetEntity`: + `completed`, `isWarmup`, `rpe`, inverse `exercise`
/// - `SessionExerciseEntity`: + `notes`, inverse `workout`
/// - `AppProfile`: − `demoMode` (demo mode lives in UserDefaults)
enum AureliaSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [AppProfile.self, ExerciseEntity.self, TemplateEntity.self, WorkoutEntity.self,
         SessionExerciseEntity.self, SetEntity.self, FoodEntity.self, FoodLogEntity.self,
         SavedMealEntity.self, WaterEntity.self, SupplementEntity.self, SupplementCheckEntity.self,
         WeightEntity.self, ActivityEntity.self, PhotoSetEntity.self]
    }
}

/// The ordered history of schema versions. SwiftData walks this to bring an
/// older store forward to the current one.
///
/// **Adding V3:** freeze the V2 shapes of any model you change into
/// `AureliaSchemaV2` (as V1 does above), define V3 with the new shapes, append
/// it to `schemas`, and add a stage. Additive changes are `.lightweight`;
/// renames, type changes, and required fields without defaults need `.custom`.
enum AureliaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AureliaSchemaV1.self, AureliaSchemaV2.self] }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: AureliaSchemaV1.self, toVersion: AureliaSchemaV2.self)]
    }
}

// MARK: - Containers

enum Persistence {
    static let schema = Schema(versionedSchema: AureliaSchemaV2.self)

    /// A human-readable version string, recorded in every export.
    static var schemaVersionString: String {
        let v = AureliaSchemaV2.versionIdentifier
        return "\(v.major).\(v.minor).\(v.patch)"
    }

    /// Opens the real store, migrating if needed.
    ///
    /// If it cannot be opened, this falls back to an in-memory container and
    /// returns the error rather than crashing or deleting anything. The store
    /// file stays on disk for recovery; `eraseStore()` is the explicit,
    /// user-confirmed way to start over.
    @MainActor
    static func makeContainer() -> (container: ModelContainer, failure: String?) {
        do {
            let container = try ModelContainer(for: schema, migrationPlan: AureliaMigrationPlan.self)
            seedExerciseLibrary(into: container)
            seedFoodStaples(into: container)
            return (container, nil)
        } catch {
            let scratch = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // An in-memory container has no store to conflict with, so this
            // cannot realistically fail; if it did there would be nothing to run.
            let fallback = try! ModelContainer(for: schema, configurations: scratch)
            return (fallback, String(describing: error))
        }
    }

    /// Deletes the on-disk store so the next launch starts empty. Only ever
    /// called from the failure banner after the user confirms.
    static func eraseStore() throws {
        let url = ModelConfiguration(schema: schema).url
        let manager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            if manager.fileExists(atPath: file.path) { try manager.removeItem(at: file) }
        }
    }

    /// A throwaway in-memory store for portfolio/demo mode.
    ///
    /// Earlier builds seeded demo rows into the *real* store and could not
    /// remove them again. Keeping demo data in its own container means
    /// toggling demo mode can never touch personal history, and "reset" is
    /// simply building a fresh one.
    @MainActor
    static func makeDemoContainer() -> ModelContainer {
        let config = ModelConfiguration("AureliaDemo", schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        seedExerciseLibrary(into: container)
        seedFoodStaples(into: container)
        DemoData.seed(into: container)
        return container
    }

    /// Inserts any `FoodCatalog` staple that is not already in the food list.
    /// Insert-only: a staple the user has edited keeps their values, because
    /// the catalog's numbers are typical figures and theirs may be from a label.
    @MainActor
    private static func seedFoodStaples(into container: ModelContainer) {
        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<FoodEntity>())) ?? []
        let names = Set(existing.filter { $0.brand.isEmpty }.map(\.name))
        var changed = false
        for staple in FoodCatalog.all where !names.contains(staple.name) {
            context.insert(FoodEntity(name: staple.name, calories100: staple.per100.calories, protein100: staple.per100.protein,
                                      carbs100: staple.per100.carbs, fat100: staple.per100.fat, servingGrams: staple.servingGrams))
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Brings the stored exercise library up to date with `ExerciseCatalog`.
    ///
    /// Runs on every launch and is cheap: new catalog entries are inserted,
    /// built-in entries get the catalog's current summary and tips, and
    /// anything the user created (`isCustom`) is left exactly as it is. This is
    /// how the library grows in an update without a schema change.
    @MainActor
    private static func seedExerciseLibrary(into container: ModelContainer) {
        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<ExerciseEntity>())) ?? []
        var byName = [String: ExerciseEntity]()
        for entity in existing { byName[entity.name] = entity }

        var changed = false
        for definition in ExerciseCatalog.all {
            if let entity = byName[definition.name] {
                guard !entity.isCustom else { continue }
                let tips = definition.tips.joined(separator: "\n")
                if entity.summary != definition.summary || entity.tips != tips {
                    entity.summary = definition.summary
                    entity.tips = tips
                    changed = true
                }
            } else {
                context.insert(ExerciseEntity(definition.name, summary: definition.summary, tips: definition.tips))
                changed = true
            }
        }
        if changed { try? context.save() }
    }
}
