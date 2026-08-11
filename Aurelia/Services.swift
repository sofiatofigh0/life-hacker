import Foundation
import HealthKit
import UserNotifications

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
        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=product_name,brands,code,serving_quantity,nutriments")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(OFFResponse.self, from: data)
        guard let p = result.product, let name = p.productName else { return nil }
        return FoodSnapshot(name: name, brand: p.brands, barcode: p.code, nutrientsPer100Grams: .init(calories: p.nutriments?.energyKcal100g ?? 0, protein: p.nutriments?.proteins100g ?? 0, carbs: p.nutriments?.carbohydrates100g ?? 0, fat: p.nutriments?.fat100g ?? 0), servingGrams: p.servingQuantity)
    }
    private struct OFFResponse: Decodable { let product: Product? }
    private struct Product: Decodable { let productName: String?; let brands: String?; let code: String?; let servingQuantity: Double?; let nutriments: Nutriments?; enum CodingKeys: String, CodingKey { case productName = "product_name", brands, code, servingQuantity = "serving_quantity", nutriments } }
    private struct Nutriments: Decodable { let energyKcal100g, proteins100g, carbohydrates100g, fat100g: Double?; enum CodingKeys: String, CodingKey { case energyKcal100g = "energy-kcal_100g", proteins100g = "proteins_100g", carbohydrates100g = "carbohydrates_100g", fat100g = "fat_100g" } }
}

actor HealthKitService: HealthProviding {
    private let store = HKHealthStore()
    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let ids = [HKQuantityTypeIdentifier.stepCount, .activeEnergyBurned, .basalEnergyBurned, .heartRate, .bodyMass, .distanceWalkingRunning]
        let read = Set(ids.compactMap(HKObjectType.quantityType(forIdentifier:))) .union([HKObjectType.workoutType()])
        let share = Set([HKObjectType.quantityType(forIdentifier: .bodyMass)].compactMap { $0 })
        try await store.requestAuthorization(toShare: share, read: read)
    }
    func snapshot(for date: Date) async throws -> HealthSnapshot {
        async let steps = sum(.stepCount, unit: .count(), date: date)
        async let active = sum(.activeEnergyBurned, unit: .kilocalorie(), date: date)
        async let basal = sum(.basalEnergyBurned, unit: .kilocalorie(), date: date)
        return try await .init(steps: steps, activeCalories: active, basalCalories: basal == 0 ? nil : basal)
    }
    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let start = Calendar.current.startOfDay(for: date); let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end), options: .cumulativeSum) { _, result, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0) }
            }; store.execute(query)
        }
    }
}

enum NotificationService {
    static func request() async throws -> Bool { try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) }
    static func scheduleWeeklyPhotos(weekday: Int = 1, hour: Int = 9) async throws {
        let content = UNMutableNotificationContent(); content.title = "A quiet moment for progress"; content.body = "Add this week's front, side, and back photos."; content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, weekday: weekday), repeats: true)
        try await UNUserNotificationCenter.current().add(.init(identifier: "weekly-photos", content: content, trigger: trigger))
    }
}
