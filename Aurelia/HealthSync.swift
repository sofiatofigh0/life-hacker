import Foundation
import Observation
import SwiftData

/// Pulls Apple Health into the local store.
///
/// This is the piece that was missing: `HealthKitService.snapshot(for:)` existed
/// but nothing ever called it, so steps and active calories were always zero
/// outside demo mode. Sync runs on launch, when the app returns to the
/// foreground, and on demand from Today and Settings.
///
/// Rules:
/// - One `ActivityEntity` per calendar day. Existing rows are updated in place;
///   duplicates from earlier builds are collapsed.
/// - Weight from Health (a scale, another app) is imported as source "Apple Health"
///   only for days with no manual entry, so a manual log always wins.
/// - Past days with no Health data at all are skipped rather than written as zeros.
@MainActor @Observable
final class HealthSync {
    static let shared = HealthSync()

    private(set) var lastSynced: Date?
    private(set) var lastError: String?
    private(set) var isSyncing = false
    /// True once the app has ever completed a sync that returned any data.
    private(set) var hasEverReceivedData = false

    static let weightSource = "Apple Health"
    static let importWorkoutsKey = "aurelia.importHealthWorkouts"
    private static let ignoredWorkoutsKey = "aurelia.ignoredHealthWorkouts"
    private let service = HealthKitService.shared

    /// Whether Health workouts are brought into the log. On by default.
    static var importsWorkouts: Bool {
        UserDefaults.standard.object(forKey: importWorkoutsKey) as? Bool ?? true
    }

    /// Imported workouts the person deleted must stay deleted on the next sync.
    static func ignoreWorkout(externalID: String) {
        var ids = Set(UserDefaults.standard.stringArray(forKey: ignoredWorkoutsKey) ?? [])
        ids.insert(externalID)
        UserDefaults.standard.set(Array(ids), forKey: ignoredWorkoutsKey)
    }

    var isAvailable: Bool { HealthKitService.isAvailable }

    /// Plain-language state of the connection, refreshed after every attempt.
    private(set) var diagnosis: String?
    private(set) var permissionAsked: Bool?

    func requestAccessAndSync(context: ModelContext) async {
        diagnosis = nil
        do { try await service.authorize() }
        catch {
            lastError = Self.explain(error)
            Haptics.warning()
            await refreshDiagnosis()
            return
        }
        await sync(context: context)
        await refreshDiagnosis()
        if lastError == nil { Haptics.success() } else { Haptics.warning() }
    }

    /// Works out why Health might look "not connected" and says so.
    func refreshDiagnosis() async {
        let state = await service.permissionState()
        switch state {
        case .unavailable:
            permissionAsked = nil
            diagnosis = "Apple Health is not available on this device."
        case .notAsked:
            permissionAsked = false
            diagnosis = "iOS never showed the Health permission sheet. This build is missing the HealthKit capability: in Xcode select the Aurelia target → Signing & Capabilities → + Capability → HealthKit, then run again."
        case .asked:
            permissionAsked = true
            if lastError != nil {
                diagnosis = nil
            } else if !hasEverReceivedData {
                diagnosis = "Permission was requested, but Health returned no steps, energy, heart rate or weight for the last 14 days. In the Health app, check your picture → Apps → Aurelia has the categories on, and that the iPhone is recording steps at all."
            } else {
                diagnosis = nil
            }
        }
    }

    private static func explain(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("entitlement") {
            return "The build has no HealthKit entitlement. In Xcode: Aurelia target → Signing & Capabilities → + Capability → HealthKit."
        }
        return text
    }

    /// Imports the last `days` days (today inclusive).
    func sync(context: ModelContext, days: Int = 14) async {
        guard isAvailable else { lastError = "Apple Health is not available on this device."; return }
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var receivedAnything = false

        do {
            for offset in 0..<days {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }

                let snapshot = try await service.snapshot(for: day)
                let heartRate = try await service.averageHeartRate(on: day)
                let hasActivity = snapshot.steps > 0 || snapshot.activeCalories > 0 || heartRate != nil
                if hasActivity { receivedAnything = true }

                // Always keep today's row current, even at zero, so the ring updates
                // the moment Health starts reporting. Skip empty past days.
                if hasActivity || offset == 0 {
                    upsertActivity(on: day, snapshot: snapshot, heartRate: heartRate, context: context)
                }

                if let mass = try await service.latestBodyMass(on: day) {
                    receivedAnything = true
                    upsertHealthWeight(on: day, kilograms: mass.kilograms, sampleDate: mass.date, context: context)
                }
            }
            if Self.importsWorkouts, let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) {
                let imported = try await importWorkouts(from: start, context: context)
                if imported > 0 { receivedAnything = true }
            }
            try context.save()
            lastSynced = .now
            lastError = nil
            if receivedAnything { hasEverReceivedData = true }
        } catch {
            Log.health.error("sync failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    // MARK: Workouts from Health

    /// Brings Apple Watch / Health workouts into the log, once each.
    ///
    /// De-duplication rules, in order:
    /// 1. Already imported (same Health UUID) → skip.
    /// 2. Deleted by the person after an earlier import → skip forever.
    /// 3. A workout logged by hand starts within 90 minutes of it → skip; the
    ///    hand-logged session is the record and the Watch one is the same event.
    /// Returns how many were added.
    private func importWorkouts(from start: Date, context: ModelContext) async throws -> Int {
        let candidates = try await service.workouts(from: start, to: .now)
        guard !candidates.isEmpty else { return 0 }
        let existing = (try? context.fetch(FetchDescriptor<WorkoutEntity>(predicate: #Predicate { $0.date >= start }))) ?? []
        let importedIDs = Set(existing.compactMap(\.externalID))
        let ignored = Set(UserDefaults.standard.stringArray(forKey: Self.ignoredWorkoutsKey) ?? [])
        let manualDates = existing.filter { $0.externalID == nil }.map(\.date)
        let window: TimeInterval = 90 * 60
        var added = 0
        for candidate in candidates where candidate.minutes >= 1 {
            if importedIDs.contains(candidate.id) || ignored.contains(candidate.id) { continue }
            if manualDates.contains(where: { abs($0.timeIntervalSince(candidate.start)) < window }) { continue }
            let workout = WorkoutEntity(date: candidate.start, name: candidate.name, completed: true,
                                        isCardio: !candidate.isStrength, durationMinutes: candidate.minutes.rounded())
            workout.externalID = candidate.id
            workout.distanceKM = candidate.distanceKM
            workout.calories = candidate.calories
            workout.averageHeartRate = try? await service.averageHeartRate(from: candidate.start, to: candidate.end)
            workout.notes = "Recorded by \(candidate.source)"
            context.insert(workout)
            added += 1
        }
        return added
    }

    // MARK: Upserts

    private func upsertActivity(on day: Date, snapshot: HealthSnapshot, heartRate: Double?, context: ModelContext) {
        let rows = activities(on: day, context: context)
        let row: ActivityEntity
        if let first = rows.first {
            row = first
            // Collapse any duplicates left by older builds.
            rows.dropFirst().forEach(context.delete)
        } else {
            row = ActivityEntity(date: day, steps: 0, activeCalories: 0)
            context.insert(row)
        }
        row.date = day
        row.steps = snapshot.steps
        row.activeCalories = snapshot.activeCalories
        row.basalCalories = snapshot.basalCalories
        row.averageHeartRate = heartRate
    }

    private func upsertHealthWeight(on day: Date, kilograms: Double, sampleDate: Date, context: ModelContext) {
        let rows = weights(on: day, context: context)
        // A manual entry for the day always wins.
        guard !rows.contains(where: { $0.source != Self.weightSource }) else { return }
        if let existing = rows.first(where: { $0.source == Self.weightSource }) {
            existing.kilograms = kilograms
            existing.date = sampleDate
        } else {
            context.insert(WeightEntity(date: sampleDate, kilograms: kilograms, source: Self.weightSource))
        }
    }

    private func activities(on day: Date, context: ModelContext) -> [ActivityEntity] {
        let (start, end) = bounds(day)
        let descriptor = FetchDescriptor<ActivityEntity>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func weights(on day: Date, context: ModelContext) -> [WeightEntity] {
        let (start, end) = bounds(day)
        let descriptor = FetchDescriptor<WeightEntity>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func bounds(_ day: Date) -> (Date, Date) {
        let start = Calendar.current.startOfDay(for: day)
        return (start, Calendar.current.date(byAdding: .day, value: 1, to: start)!)
    }
}
