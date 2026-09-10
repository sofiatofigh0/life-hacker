import SwiftUI
import SwiftData
import Charts
import PhotosUI
import UIKit

// MARK: - Progress tab

struct ProgressTabView: View {
    let profile: AppProfile
    @Query(sort: \WeightEntity.date) private var weights: [WeightEntity]
    @Query(sort: \PhotoSetEntity.date, order: .reverse) private var photos: [PhotoSetEntity]
    @Query private var workouts: [WorkoutEntity]
    @Query private var logs: [FoodLogEntity]
    @Query private var activities: [ActivityEntity]
    @State private var addPhoto = false
    @State private var compare = false
    @State private var logWeight = false
    @State private var managePhotos = false

    private var units: UnitSystem { profile.units }
    private var latest: WeightEntity? { weights.last }
    private var chartWeights: [WeightEntity] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        return weights.filter { $0.date >= cutoff }
    }
    private var sevenDay: Double? {
        Trends.sevenDayAverage(weights.map { WeightPoint(date: $0.date, kilograms: $0.kilograms) }, through: .now)
    }

    var body: some View {
        TabScreen(eyebrow: "Progress", title: "The long view") {
            HeaderButton(systemImage: "plus", label: "Log weight") { logWeight = true }
        } content: {
            weekCard
            goalCard
            if !chartWeights.isEmpty { chartCard }
            photosCard
        }
        .sheet(isPresented: $addPhoto) { PhotoCaptureFlow() }
        .sheet(isPresented: $compare) { PhotoCompareView(photos: photos) }
        .sheet(isPresented: $logWeight) { WeightEntryView(profile: profile, date: .now) }
        .sheet(isPresented: $managePhotos) { NavigationStack { PhotoSetsView() } }
    }

    // MARK: This week vs last

    private struct WeekStats {
        var workouts = 0
        var calories: Double?
        var protein: Double?
        var steps: Double?
        var weightKG: Double?
    }

    private func stats(for week: WeekWindow) -> WeekStats {
        var stats = WeekStats()
        stats.workouts = workouts.filter { $0.completed && week.contains($0.date) }.count
        let weekLogs = logs.filter { week.contains($0.date) }
        let calorieDays: [(date: Date, value: Double)] = weekLogs.map { (date: $0.date, value: $0.calories) }
        let proteinDays: [(date: Date, value: Double)] = weekLogs.map { (date: $0.date, value: $0.protein) }
        stats.calories = Aggregate.mean(Array(Aggregate.dailyTotals(calorieDays).values))
        stats.protein = Aggregate.mean(Array(Aggregate.dailyTotals(proteinDays).values))
        stats.steps = Aggregate.mean(activities.filter { week.contains($0.date) && $0.steps > 0 }.map(\.steps))
        stats.weightKG = Aggregate.mean(weights.filter { week.contains($0.date) }.map(\.kilograms))
        return stats
    }

    private var weekCard: some View {
        let thisWeek = WeekWindow.current(containing: .now)
        let now = stats(for: thisWeek)
        let last = stats(for: thisWeek.previous)
        return WellnessCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("This week").font(.headline)
                    Spacer()
                    Text("vs last week").font(.caption).foregroundStyle(.secondary)
                }
                weekRow("Workouts", value: "\(now.workouts)", delta: Double(now.workouts - last.workouts), format: { "\(Int($0))" })
                weekRow("Avg calories", value: now.calories.map { Int($0).formatted() + " kcal" } ?? "—",
                        delta: diff(now.calories, last.calories), format: { Int($0).formatted() })
                weekRow("Avg protein", value: now.protein.map { "\(Int($0)) g" } ?? "—",
                        delta: diff(now.protein, last.protein), format: { "\(Int($0)) g" })
                weekRow("Avg steps", value: now.steps.map { Int($0).formatted() } ?? "—",
                        delta: diff(now.steps, last.steps), format: { Int($0).formatted() })
                weekRow("Avg weight", value: now.weightKG.map { units.formatWeight(kilograms: $0) } ?? "—",
                        delta: diff(now.weightKG, last.weightKG),
                        format: { units.displayWeight(kilograms: $0).formatted(.number.precision(.fractionLength(1))) + " " + units.weightUnit })
            }
        }
    }

    private func diff(_ a: Double?, _ b: Double?) -> Double? {
        guard let a, let b else { return nil }
        return a - b
    }

    private func weekRow(_ title: String, value: String, delta: Double?, format: (Double) -> String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold))
            if let delta, abs(delta) >= 0.05 {
                Text((delta > 0 ? "+" : "−") + format(abs(delta)))
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(width: 84, alignment: .trailing)
            } else {
                Text(delta == nil ? "" : "same").font(.caption).foregroundStyle(.tertiary).frame(width: 84, alignment: .trailing)
            }
        }
        .font(.subheadline)
    }

    // MARK: Weight

    private var goalCard: some View {
        WellnessCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Weight").font(.headline)
                if let latest {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(units.formatWeight(kilograms: latest.kilograms)).font(.system(.title, design: .serif, weight: .semibold))
                        Text("→ goal \(units.formatWeight(kilograms: profile.goalKG))").foregroundStyle(.secondary)
                    }
                    let remaining = latest.kilograms - profile.goalKG
                    Text(abs(remaining) < 0.05 ? "At goal"
                         : "\(units.formatWeight(kilograms: abs(remaining))) \(remaining > 0 ? "to lose" : "to gain")")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let sevenDay {
                        Text("7-day average \(units.formatWeight(kilograms: sevenDay))").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Last logged \(latest.date.formatted(date: .abbreviated, time: .omitted)) · \(latest.source)")
                        .font(.caption).foregroundStyle(.tertiary)
                } else {
                    Text("Log a weight to begin your trend.").foregroundStyle(.secondary)
                    Button("Log weight") { logWeight = true }.buttonStyle(.bordered)
                }
            }
        }
    }

    private var chartCard: some View {
        WellnessCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last 90 days").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Chart {
                    ForEach(chartWeights) { entry in
                        LineMark(x: .value("Date", entry.date), y: .value("Weight", units.displayWeight(kilograms: entry.kilograms)))
                            .foregroundStyle(.sage)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", entry.date), y: .value("Weight", units.displayWeight(kilograms: entry.kilograms)))
                            .foregroundStyle(.sage)
                            .symbolSize(20)
                    }
                    RuleMark(y: .value("Goal", units.displayWeight(kilograms: profile.goalKG)))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("goal").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                // A weight chart that starts at zero is a flat line at the top.
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxisLabel(units.weightUnit)
                .frame(height: 200)
            }
        }
    }

    // MARK: Photos

    private var photosCard: some View {
        WellnessCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Progress photos").font(.headline)
                    Spacer()
                    if !photos.isEmpty { Button("Manage") { managePhotos = true }.font(.subheadline) }
                }
                if photos.isEmpty {
                    Text("Weekly front, side, and back photos stay in the app's private storage and are never uploaded.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(photos.prefix(8)) { set in
                                VStack(spacing: 4) {
                                    ProgressPhoto(filename: set.front).frame(width: 72, height: 96)
                                    Text(set.date.formatted(.dateTime.month(.abbreviated).day())).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                HStack {
                    Button("Add this week") { addPhoto = true }.buttonStyle(.borderedProminent)
                    Button("Compare") { compare = true }.buttonStyle(.bordered).disabled(photos.count < 2)
                }
            }
        }
    }
}

// MARK: - Weight entry

struct WeightEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntity.date, order: .reverse) private var weights: [WeightEntity]
    let profile: AppProfile
    let date: Date
    @State private var value: Double?
    @State private var healthNote: String?

    private var units: UnitSystem { profile.units }
    private var existing: WeightEntity? { weights.first { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.source == "Manual" } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Weight (\(units.weightUnit))") {
                        DecimalField(placeholder: units.isMetric ? "70.0" : "154.0", value: $value)
                            .font(.title2)
                    }
                } footer: {
                    Text(existing == nil ? "Logged for \(date.formatted(date: .abbreviated, time: .omitted))."
                         : "Updates today's existing entry.")
                }
                if let healthNote { Section { Text(healthNote).font(.footnote).foregroundStyle(.secondary) } }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled((value ?? 0) <= 0)
            }
            .navigationTitle(existing == nil ? "Log Weight" : "Update Weight")
            .toolbar { Button("Cancel") { dismiss() } }
            .onAppear {
                let kg = existing?.kilograms ?? weights.first?.kilograms ?? profile.currentKG
                value = units.displayWeight(kilograms: kg)
            }
        }
    }

    private func save() {
        guard let value, value > 0 else { return }
        let kg = units.kilograms(fromDisplayWeight: value)
        let stamp = Calendar.current.isDateInToday(date) ? Date.now
            : (Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date)
        if let existing {
            existing.kilograms = kg
            existing.date = stamp
        } else {
            context.insert(WeightEntity(date: stamp, kilograms: kg))
        }
        // The profile's current weight drives the goal card; keep it at the latest entry.
        if weights.first.map({ stamp >= $0.date }) ?? true { profile.currentKG = kg }
        try? context.save()
        Haptics.success()
        // Best-effort write to Apple Health; never blocks the log.
        Task { try? await HealthKitService.shared.saveBodyMass(kilograms: kg, date: stamp) }
        dismiss()
    }
}

// MARK: - Photos

enum ProgressPhotoStore {
    static var directory: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static func url(for filename: String) -> URL { directory.appendingPathComponent(filename) }
    static func image(for filename: String) -> UIImage? { UIImage(contentsOfFile: url(for: filename).path) }

    /// Removes the three files behind a set. Missing files are not an error.
    static func deleteFiles(of set: PhotoSetEntity) {
        for name in [set.front, set.side, set.back] where !name.isEmpty {
            try? FileManager.default.removeItem(at: url(for: name))
        }
    }
}

/// Every photo set, newest first, with swipe to delete (files included).
struct PhotoSetsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PhotoSetEntity.date, order: .reverse) private var photos: [PhotoSetEntity]
    @State private var pending: PhotoSetEntity?

    var body: some View {
        List {
            ForEach(photos) { set in
                HStack(spacing: 8) {
                    ProgressPhoto(filename: set.front).frame(width: 40, height: 54)
                    ProgressPhoto(filename: set.side).frame(width: 40, height: 54)
                    ProgressPhoto(filename: set.back).frame(width: 40, height: 54)
                    Text(set.date.formatted(date: .abbreviated, time: .omitted)).padding(.leading, 6)
                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { pending = set } label: { Label("Delete", systemImage: "trash") }
                }
            }
            if photos.isEmpty { Text("No photo sets yet.").foregroundStyle(.secondary) }
        }
        .navigationTitle("Photo Sets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Done") { dismiss() } }
        .confirmationDialog("Delete this photo set?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            presenting: pending) { set in
            Button("Delete photos from \(set.date.formatted(date: .abbreviated, time: .omitted))", role: .destructive) {
                ProgressPhotoStore.deleteFiles(of: set)
                context.delete(set)
                try? context.save()
            }
        } message: { _ in Text("The three image files are removed from the app's storage as well.") }
    }
}

struct ProgressPhoto: View {
    let filename: String
    var body: some View {
        Group {
            if let image = ProgressPhotoStore.image(for: filename) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color.sage.opacity(0.15))
                    .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PhotoCaptureFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var selections: [PhotosPickerItem?] = [nil, nil, nil]
    @State private var filenames = ["", "", ""]
    private let angles = ["Front", "Side", "Back"]

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<3, id: \.self) { index in
                    PhotosPicker(selection: Binding(get: { selections[index] }, set: { selections[index] = $0; save($0, index: index) }),
                                 matching: .images) {
                        HStack(spacing: 14) {
                            if filenames[index].isEmpty {
                                RoundedRectangle(cornerRadius: 10).fill(Color.sage.opacity(0.15)).frame(width: 48, height: 64)
                                    .overlay { Image(systemName: "photo.badge.plus").foregroundStyle(.sage) }
                            } else {
                                ProgressPhoto(filename: filenames[index]).frame(width: 48, height: 64)
                            }
                            Text(angles[index])
                            Spacer()
                            Text(filenames[index].isEmpty ? "Choose" : "Ready").foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Text("Images are copied to the app's private storage and never uploaded.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Weekly Photos")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(PhotoSetEntity(front: filenames[0], side: filenames[1], back: filenames[2]))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(filenames.contains(""))
                }
            }
        }
    }

    private func save(_ item: PhotosPickerItem?, index: Int) {
        Task {
            guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
            let url = ProgressPhotoStore.url(for: "progress-\(UUID().uuidString).jpg")
            try? data.write(to: url, options: .atomic)
            filenames[index] = url.lastPathComponent
        }
    }
}

struct PhotoCompareView: View {
    /// Newest first, as fetched by the Progress tab.
    let photos: [PhotoSetEntity]
    @Environment(\.dismiss) private var dismiss
    @State private var earlier: Int
    @State private var later = 0
    @State private var angle = 0

    init(photos: [PhotoSetEntity]) {
        self.photos = photos
        _earlier = State(initialValue: max(photos.count - 1, 0))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    picker("Earlier", selection: $earlier)
                    picker("Later", selection: $later)
                }
                Picker("Angle", selection: $angle) { Text("Front").tag(0); Text("Side").tag(1); Text("Back").tag(2) }
                    .pickerStyle(.segmented)
                if photos.indices.contains(earlier), photos.indices.contains(later) {
                    HStack(spacing: 10) {
                        column(photos[earlier])
                        column(photos[later])
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding()
            .navigationTitle("Compare")
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func picker(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(photos.indices, id: \.self) { Text(photos[$0].date.formatted(date: .abbreviated, time: .omitted)).tag($0) }
        }
    }

    private func column(_ set: PhotoSetEntity) -> some View {
        VStack(spacing: 6) {
            ProgressPhoto(filename: [set.front, set.side, set.back][angle])
            Text(set.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
        }
    }
}
