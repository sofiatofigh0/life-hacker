import SwiftUI
import SwiftData

// MARK: - Calendar

struct CalendarHistoryView: View {
    let profile: AppProfile
    @State private var month = Date.now
    @Query private var workouts: [WorkoutEntity]
    @Query private var logs: [FoodLogEntity]
    @Query private var waters: [WaterEntity]
    @Query private var activities: [ActivityEntity]
    @Query private var checks: [SupplementCheckEntity]
    @Query private var supplements: [SupplementEntity]

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private var calendar: Calendar { .current }

    private var index: DailyScoreIndex {
        DailyScoreIndex(profile: profile, logs: logs, workouts: workouts, activities: activities,
                        waters: waters, checks: checks, supplementCount: supplements.count)
    }

    var body: some View {
        let index = self.index
        TabScreen(eyebrow: "History", title: month.formatted(.dateTime.month(.wide).year())) {
            monthPicker
            WellnessCard {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(calendar.veryShortWeekdaySymbols.indices, id: \.self) { column in
                        Text(calendar.veryShortWeekdaySymbols[(column + calendar.firstWeekday - 1) % 7])
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(days(), id: \.self) { date in
                        let inMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
                        let isToday = calendar.isDateInToday(date)
                        let future = date > .now
                        let score = future ? 0 : index.score(on: date)
                        NavigationLink { DayDetailView(date: date, profile: profile) } label: {
                            VStack(spacing: 4) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.subheadline.weight(isToday ? .bold : .regular))
                                    .foregroundStyle(isToday ? Color.sage : Color.primary)
                                ZStack {
                                    Circle().stroke(.secondary.opacity(0.15), lineWidth: 3)
                                    if !future {
                                        Circle().trim(from: 0, to: score).stroke(.sage, style: .init(lineWidth: 3, lineCap: .round))
                                            .rotationEffect(.degrees(-90))
                                    }
                                }
                                .frame(width: 26, height: 26)
                            }
                            .frame(height: 56)
                            .opacity(inMonth ? 1 : 0.3)
                        }
                        .buttonStyle(.plain)
                        .disabled(future)
                        .accessibilityLabel(future ? date.formatted(date: .abbreviated, time: .omitted)
                                            : "\(date.formatted(date: .abbreviated, time: .omitted)), \(Int(score * 100)) percent")
                    }
                }
            }
            monthSummary(index)
            legend
        }
    }

    private var monthPicker: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            if !calendar.isDate(month, equalTo: .now, toGranularity: .month) { Button("This month") { month = .now } }
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month))
        }
        .font(.body.weight(.semibold))
    }

    /// Workouts, good days, and averages for the days of this month that have happened.
    private func monthSummary(_ index: DailyScoreIndex) -> some View {
        let days = monthDaysSoFar()
        let goodDays = days.filter { index.score(on: $0) >= 0.7 }.count
        let loggedDays = days.filter { index.hasData(on: $0) }.count
        let workoutCount = workouts.filter { $0.completed && calendar.isDate($0.date, equalTo: month, toGranularity: .month) }.count
        let monthLogs = logs.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
        let calorieDays: [(date: Date, value: Double)] = monthLogs.map { (date: $0.date, value: $0.calories) }
        let avgCalories = Aggregate.mean(Array(Aggregate.dailyTotals(calorieDays).values))
        let avgSteps = Aggregate.mean(activities.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) && $0.steps > 0 }.map(\.steps))
        return WellnessCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(calendar.isDate(month, equalTo: .now, toGranularity: .month) ? "So far this month" : "This month").font(.headline)
                if loggedDays == 0 {
                    Text("Nothing logged this month.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    summaryRow("Workouts", "\(workoutCount)")
                    summaryRow("Days at 70% or more", "\(goodDays) of \(days.count)")
                    summaryRow("Average calories", avgCalories.map { Int($0).formatted() + " kcal" } ?? "—")
                    summaryRow("Average steps", avgSteps.map { Int($0).formatted() } ?? "—")
                }
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.semibold) }.font(.subheadline)
    }

    private var legend: some View {
        Text("Each ring is that day's completion score: workout, calories in range, protein, steps, water, and supplements.")
            .font(.footnote).foregroundStyle(.secondary)
    }

    private func shift(_ months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: month) { month = next }
    }

    private func days() -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let prefix = (firstWeekday - calendar.firstWeekday + 7) % 7
        return (0..<(prefix + range.count)).compactMap { calendar.date(byAdding: .day, value: $0 - prefix, to: interval.start) }
    }

    private func monthDaysSoFar() -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let today = calendar.startOfDay(for: .now)
        return (0..<range.count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }.filter { $0 <= today }
    }
}

// MARK: - Day detail

struct DayDetailView: View {
    @Environment(\.modelContext) private var context
    let date: Date
    let profile: AppProfile
    @Query private var workouts: [WorkoutEntity]
    @Query(sort: \FoodLogEntity.date) private var logs: [FoodLogEntity]
    @Query private var waters: [WaterEntity]
    @Query(sort: \WeightEntity.date, order: .reverse) private var weights: [WeightEntity]
    @Query private var activities: [ActivityEntity]
    @State private var addFood = false
    @State private var addWorkout = false
    @State private var editWeight = false
    @State private var editing: FoodLogEntity?

    private var calendar: Calendar { .current }
    private var dayWorkouts: [WorkoutEntity] { workouts.filter { calendar.isDate($0.date, inSameDayAs: date) } }
    private var dayLogs: [FoodLogEntity] { logs.filter { calendar.isDate($0.date, inSameDayAs: date) } }
    private var activity: ActivityEntity? { activities.first { calendar.isDate($0.date, inSameDayAs: date) } }
    private var water: Double { waters.filter { calendar.isDate($0.date, inSameDayAs: date) }.map(\.liters).reduce(0, +) }
    private var weight: WeightEntity? { weights.first { calendar.isDate($0.date, inSameDayAs: date) } }
    private var units: UnitSystem { profile.units }
    /// Entries added retroactively are stamped at noon on that day.
    private var logDate: Date { calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date }

    var body: some View {
        List {
            Section("Workout") {
                if dayWorkouts.isEmpty { Text("No workout logged").foregroundStyle(.secondary) }
                ForEach(dayWorkouts) { workout in
                    NavigationLink { WorkoutEditor(workout: workout, profile: profile) } label: {
                        HStack {
                            Text(workout.name)
                            Spacer()
                            if workout.completed { Image(systemName: "checkmark.circle.fill").foregroundStyle(.sage) }
                        }
                    }
                }
                Button("Add workout for this day") { addWorkout = true }
            }
            Section("Nutrition") {
                if dayLogs.isEmpty { Text("Nothing logged").foregroundStyle(.secondary) }
                ForEach(dayLogs) { entry in
                    Button { editing = entry } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.foodName).foregroundStyle(.primary)
                                Text("\(Meal(rawValue: entry.mealRaw)?.label ?? entry.mealRaw) · \(entry.grams > 0 ? "\(Int(entry.grams)) g" : "quick add")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(entry.calories)) kcal").foregroundStyle(.primary)
                        }
                    }
                }
                .onDelete { offsets in offsets.map { dayLogs[$0] }.forEach(context.delete); try? context.save() }
                if !dayLogs.isEmpty {
                    LabeledContent("Total", value: "\(Int(dayLogs.map(\.calories).reduce(0, +)).formatted()) kcal · \(Int(dayLogs.map(\.protein).reduce(0, +))) g protein")
                        .font(.subheadline)
                }
                Button("Add forgotten food") { addFood = true }
            }
            Section("Activity") {
                LabeledContent("Steps", value: Int(activity?.steps ?? 0).formatted())
                LabeledContent("Active calories", value: "\(Int(activity?.activeCalories ?? 0)) kcal")
                if let hr = activity?.averageHeartRate { LabeledContent("Average heart rate", value: "\(Int(hr)) bpm") }
                LabeledContent("Water", value: units.formatWater(liters: water))
            }
            Section("Weight") {
                if let weight {
                    LabeledContent(units.formatWeight(kilograms: weight.kilograms), value: weight.source).foregroundStyle(.secondary)
                } else {
                    Text("Not logged").foregroundStyle(.secondary)
                }
                Button(weight == nil ? "Add weight" : "Update weight") { editWeight = true }
            }
        }
        .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
        .sheet(isPresented: $addFood) { NavigationStack { AddFoodView(date: logDate) { addFood = false } } }
        .sheet(isPresented: $addWorkout) { AddWorkoutView(date: logDate) }
        .sheet(isPresented: $editWeight) { WeightEntryView(profile: profile, date: date) }
        .sheet(item: $editing) { entry in FoodEntryEditor(entry: entry) }
    }
}
