import Foundation
import SwiftData

/// Version 1 of the on-disk schema.
///
/// **When you change a model, do this — not a plain edit:**
/// 1. Copy the *current* model definitions into a `AureliaSchemaV1` namespace so
///    the old shape survives (SwiftData needs both shapes to migrate between them).
/// 2. Add `AureliaSchemaV2` with the new shape and a bumped `versionIdentifier`.
/// 3. Add a `MigrationStage` to `AureliaMigrationPlan.stages` describing the move.
///
/// Additive changes — a new optional property, a new model — are handled by
/// SwiftData's lightweight migration and need only a `.lightweight` stage.
/// Renames, type changes, and required properties without defaults need
/// `.custom`, or the store will fail to open.
///
/// Note: `AppProfile.demoMode` is no longer read (demo mode moved to
/// UserDefaults so it can switch containers), but the column stays so V1 is
/// unchanged. Remove it in V2.
enum AureliaSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [AppProfile.self, ExerciseEntity.self, TemplateEntity.self, WorkoutEntity.self,
         SessionExerciseEntity.self, SetEntity.self, FoodEntity.self, FoodLogEntity.self,
         SavedMealEntity.self, WaterEntity.self, SupplementEntity.self, SupplementCheckEntity.self,
         WeightEntity.self, ActivityEntity.self, PhotoSetEntity.self]
    }
}

/// The ordered history of schema versions. SwiftData walks this to bring an
/// older store forward to the current one.
enum AureliaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AureliaSchemaV1.self] }

    /// One stage per version-to-version hop. Empty while there is only V1.
    static var stages: [MigrationStage] { [] }
}

enum Persistence {
    static let schema = Schema(versionedSchema: AureliaSchemaV1.self)

    /// A human-readable version string, recorded in every export.
    static var schemaVersionString: String {
        let v = AureliaSchemaV1.versionIdentifier
        return "\(v.major).\(v.minor).\(v.patch)"
    }

    /// Opens the real store, migrating if needed.
    ///
    /// If it cannot be opened, this falls back to an in-memory container and
    /// returns the error rather than crashing or deleting anything. That matters:
    /// the store file is the only copy of the user's history, so a failed
    /// migration must leave it untouched on disk for recovery. The previous
    /// `try!` turned any schema mismatch into a launch crash loop.
    @MainActor
    static func makeContainer() -> (container: ModelContainer, failure: String?) {
        do {
            let container = try ModelContainer(for: schema, migrationPlan: AureliaMigrationPlan.self)
            seedExerciseLibrary(into: container)
            return (container, nil)
        } catch {
            let scratch = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // An in-memory container has no store to conflict with, so this
            // cannot realistically fail; if it did there would be nothing to run.
            let fallback = try! ModelContainer(for: schema, configurations: scratch)
            return (fallback, String(describing: error))
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
        DemoData.seed(into: container)
        return container
    }

    /// The built-in exercise list, inserted once. `ExerciseEntity.name` is unique,
    /// so re-running is harmless.
    @MainActor
    private static func seedExerciseLibrary(into container: ModelContainer) {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<ExerciseEntity>())) ?? 0
        guard count == 0 else { return }
        for (name, summary, tips) in SeedData.exercises {
            context.insert(ExerciseEntity(name, summary: summary, tips: tips))
        }
        try? context.save()
    }
}
