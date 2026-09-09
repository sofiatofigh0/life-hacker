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
    private let service = HealthKitService.shared

    var isAvailable: Bool { HealthKitService.isAvailable }

    func requestAccessAndSync(context: ModelContext) async {
        do { try await service.authorize() }
        catch { lastError = error.localizedDescription; return }
        await sync(context: context)
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
            try context.save()
            lastSynced = .now
            lastError = nil
            if receivedAnything { hasEverReceivedData = true }
        } catch {
            lastError = error.localizedDescription
        }
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
