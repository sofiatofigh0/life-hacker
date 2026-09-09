import Foundation
import HealthKit
import UserNotifications

// MARK: - Nutrition

struct RemoteNutritionService: NutritionProvider {
    let proxyURL: URL?

    func search(_ query: String) async throws -> [FoodSnapshot] {
        guard let proxyURL else { throw URLError(.notConnectedToInternet) }
        var components = URLComponents(url: proxyURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [.init(name: "q", value: query)]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([FoodSnapshot].self, from: data)
    }

    func barcode(_ code: String) async throws -> FoodSnapshot? {
        // Scanned codes are digits, but never interpolate untrusted input into a URL.
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/")
        components?.path += code + ".json"
        components?.queryItems = [.init(name: "fields", value: "product_name,brands,code,serving_quantity,nutriments")]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(OFFResponse.self, from: data)
        guard let p = result.product, let name = p.productName, !name.isEmpty else { return nil }
        return FoodSnapshot(
            name: name, brand: p.brands, barcode: p.code,
            nutrientsPer100Grams: .init(calories: p.nutriments?.energyKcal100g ?? 0, protein: p.nutriments?.proteins100g ?? 0,
                                        carbs: p.nutriments?.carbohydrates100g ?? 0, fat: p.nutriments?.fat100g ?? 0),
            servingGrams: p.servingQuantity)
    }

    private struct OFFResponse: Decodable { let product: Product? }
    private struct Product: Decodable {
        let productName: String?; let brands: String?; let code: String?; let servingQuantity: Double?; let nutriments: Nutriments?
        enum CodingKeys: String, CodingKey { case productName = "product_name", brands, code, servingQuantity = "serving_quantity", nutriments }
    }
    private struct Nutriments: Decodable {
        let energyKcal100g, proteins100g, carbohydrates100g, fat100g: Double?
        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g", proteins100g = "proteins_100g"
            case carbohydrates100g = "carbohydrates_100g", fat100g = "fat_100g"
        }
    }
}

// MARK: - HealthKit

/// Thin actor over one `HKHealthStore`. Reads are per-day aggregates; the
/// only write is body mass, which the user logs in the app.
actor HealthKitService: HealthProviding {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let ids: [HKQuantityTypeIdentifier] = [.stepCount, .activeEnergyBurned, .basalEnergyBurned, .heartRate, .bodyMass, .distanceWalkingRunning]
        let read = Set(ids.compactMap(HKObjectType.quantityType(forIdentifier:))).union([HKObjectType.workoutType()])
        let share = Set([HKObjectType.quantityType(forIdentifier: .bodyMass)].compactMap { $0 })
        try await store.requestAuthorization(toShare: share, read: read)
    }

    /// Whether the app has been granted permission to *write* body mass.
    /// (HealthKit deliberately never reveals whether *read* access was denied.)
    func canWriteBodyMass() -> Bool {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return false }
        return store.authorizationStatus(for: type) == .sharingAuthorized
    }

    func snapshot(for date: Date) async throws -> HealthSnapshot {
        async let steps = sum(.stepCount, unit: .count(), date: date)
        async let active = sum(.activeEnergyBurned, unit: .kilocalorie(), date: date)
        async let basal = sum(.basalEnergyBurned, unit: .kilocalorie(), date: date)
        return try await .init(steps: steps, activeCalories: active, basalCalories: basal == 0 ? nil : basal)
    }

    /// Average heart rate over the day, or nil when there are no samples.
    func averageHeartRate(on date: Date) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let (start, end) = Self.dayBounds(date)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
                                          options: .discreteAverage) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                let bpm = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    /// The most recent body-mass sample recorded on the given day, in kilograms.
    /// Samples written by this app are excluded so a manual log is not read
    /// back as if it came from a scale.
    func latestBodyMass(on date: Date) async throws -> (kilograms: Double, date: Date)? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let (start, end) = Self.dayBounds(date)
        let inDay = HKQuery.predicateForSamples(withStart: start, end: end)
        let notOurs = NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default()))
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [inDay, notOurs])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                guard let sample = samples?.first as? HKQuantitySample else { continuation.resume(returning: nil); return }
                continuation.resume(returning: (sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), sample.endDate))
            }
            store.execute(query)
        }
    }

    /// Writes a body-mass sample. Silently does nothing without share permission,
    /// so a weight log never fails just because Health is disconnected.
    func saveBodyMass(kilograms: Double, date: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable(), canWriteBodyMass(),
              let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await store.save(sample)
    }

    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let (start, end) = Self.dayBounds(date)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
                                          options: .cumulativeSum) { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0) }
            }
            store.execute(query)
        }
    }

    private static func dayBounds(_ date: Date) -> (Date, Date) {
        let start = Calendar.current.startOfDay(for: date)
        return (start, Calendar.current.date(byAdding: .day, value: 1, to: start)!)
    }
}

// MARK: - Notifications

enum NotificationService {
    static let weeklyPhotoIdentifier = "weekly-photos"

    static func request() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleWeeklyPhotos(weekday: Int = 1, hour: Int = 9) async throws {
        let content = UNMutableNotificationContent()
        content.title = "A quiet moment for progress"
        content.body = "Add this week's front, side, and back photos."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, weekday: weekday), repeats: true)
        try await UNUserNotificationCenter.current().add(.init(identifier: weeklyPhotoIdentifier, content: content, trigger: trigger))
    }

    static func cancelWeeklyPhotos() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [weeklyPhotoIdentifier])
    }

    static func isWeeklyPhotoScheduled() async -> Bool {
        await UNUserNotificationCenter.current().pendingNotificationRequests().contains { $0.identifier == weeklyPhotoIdentifier }
    }
}
