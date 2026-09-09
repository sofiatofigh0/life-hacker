import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    let profile: AppProfile

    @Query(sort: \WorkoutEntity.date, order: .reverse) private var workouts: [WorkoutEntity]
    @Query private var logs: [FoodLogEntity]
    @Query private var waters: [WaterEntity]
    @Query(sort: \SupplementEntity.order) private var supplements: [SupplementEntity]
    @Query private var checks: [SupplementCheckEntity]
    @Query(sort: \WeightEntity.date, order: .reverse) private var weights: [WeightEntity]
    @Query private var activities: [ActivityEntity]
    @Query private var templates: [TemplateEntity]

    @State private var sync = HealthSync.shared
    @State private var showAddWorkout = false
    @State private var showSettings = false
    @State private var showWeight = false
    @State private var startedWorkout: WorkoutEntity?

    // MARK: Derived

    private var calendar: Calendar { .current }
    private func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }

    private var macros: Macro {
        logs.filter { isToday($0.date) }.reduce(Macro()) { $0 + Macro(calories: $1.calories, protein: $1.protein, carbs: $1.carbs, fat: $1.fat) }
    }
    private var water: Double { waters.filter { isToday($0.date) }.map(\.liters).reduce(0, +) }
    private var steps: Double { activities.first { isToday($0.date) }?.steps ?? 0 }
    private var todaysWorkout: WorkoutEntity? {
        workouts.first { isToday($0.date) && $0.completed } ?? workouts.first { isToday($0.date) }
    }
    private var workoutDone: Bool { todaysWorkout?.completed == true }
    private var scheduledTemplate: TemplateEntity? {
        let weekday = calendar.component(.weekday, from: .now)
        return templates.first { $0.weekday == weekday }
    }
    private var todaysWeight: WeightEntity? { weights.first { isToday($0.date) } }
    private var supplementFraction: Double {
        supplements.isEmpty ? 1 : Double(checks.filter { isToday($0.date) }.count) / Double(supplements.count)
    }
    private var calorieRatio: Double { profile.calorieTarget > 0 ? macros.calories / Double(profile.calorieTarget) : 0 }
    private var score: Double {
        CompletionCalculator.score(.init(workout: workoutDone, calories: macros.calories, calorieTarget: Double(profile.calorieTarget),
                                         protein: macros.protein, proteinTarget: Double(profile.proteinTarget),
                                         steps: steps, stepTarget: Double(profile.stepTarget),
                                         waterLiters: water, waterTargetLiters: profile.waterTargetLiters,
                                         supplementFraction: supplementFraction))
    }

    // MARK: Body

    var body: some View {
        TabScreen(eyebrow: "Today", title: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())) {
            HeaderButton(systemImage: "gearshape", label: "Settings") { showSettings = true }
        } content: {
            completionCard
            workoutCard
            NavigationLink { FoodView(profile: profile, embedded: true) } label: {
                card(ChecklistRow(title: "Calories", detail: "\(Int(macros.calories)) / \(profile.calorieTarget) kcal",
                                  done: (0.9...1.1).contains(calorieRatio), icon: "fork.knife"))
            }.buttonStyle(.plain)
            NavigationLink { FoodView(profile: profile, embedded: true) } label: {
                card(ChecklistRow(title: "Protein", detail: "\(Int(macros.protein)) / \(profile.proteinTarget) g",
                                  done: macros.protein >= Double(profile.proteinTarget), icon: "leaf"))
            }.buttonStyle(.plain)
            stepsCard
            waterCard
            supplementsCard
            Button { showWeight = true } label: {
                card(ChecklistRow(title: "Weight",
                                  detail: todaysWeight.map { profile.units.formatWeight(kilograms: $0.kilograms) + " · logged" } ?? "Log weight",
                                  done: todaysWeight != nil, icon: "scalemass"))
            }.buttonStyle(.plain)
        }
        .sheet(isPresented: $showAddWorkout) { AddWorkoutView(date: .now) }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView(profile: profile) } }
        .sheet(isPresented: $showWeight) { WeightEntryView(profile: profile, date: .now) }
        .navigationDestination(item: $startedWorkout) { WorkoutEditor(workout: $0, profile: profile) }
    }

    private func card(_ row: ChecklistRow) -> some View { WellnessCard { row } }

    private var completionCard: some View {
        WellnessCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(.sage.opacity(0.2), lineWidth: 8)
                    Circle().trim(from: 0, to: score).stroke(.sage, style: .init(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text(score, format: .percent.precision(.fractionLength(0))).font(.headline)
                }
                .frame(width: 82, height: 82)
                .animation(.easeOut(duration: 0.4), value: score)
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.goal.label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Daily completion").font(.title3.weight(.semibold))
                    Text("Activity never increases your calorie allowance.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var workoutCard: some View {
        if let workout = todaysWorkout {
            NavigationLink { WorkoutEditor(workout: workout, profile: profile) } label: {
                card(ChecklistRow(title: "Workout", detail: workout.name + (workout.completed ? " · completed" : " · in progress"),
                                  done: workout.completed, icon: "dumbbell"))
            }.buttonStyle(.plain)
        } else if let template = scheduledTemplate {
            Button { start(template) } label: {
                card(ChecklistRow(title: "Workout", detail: "Scheduled: \(template.name) · tap to start", done: false, icon: "dumbbell"))
            }.buttonStyle(.plain)
        } else {
            Button { showAddWorkout = true } label: {
                card(ChecklistRow(title: "Workout", detail: "Add strength or cardio", done: false, icon: "dumbbell"))
            }.buttonStyle(.plain)
        }
    }

    private var stepsCard: some View {
        Button { Task { await sync.sync(context: context) } } label: {
            WellnessCard {
                VStack(alignment: .leading, spacing: 6) {
                    ChecklistRow(title: "Steps", detail: stepsDetail, done: steps >= Double(profile.stepTarget), icon: "figure.walk", chevron: false)
                    if let error = sync.lastError {
                        Text(error).font(.caption2).foregroundStyle(.red)
                    } else if let last = sync.lastSynced {
                        Text("Apple Health · updated \(last.formatted(.relative(presentation: .named)))").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }.buttonStyle(.plain)
    }

    private var stepsDetail: String {
        if sync.isSyncing { return "Syncing Apple Health…" }
        if steps == 0 && !sync.hasEverReceivedData { return "Tap to sync Apple Health" }
        return "\(Int(steps).formatted()) / \(profile.stepTarget.formatted())"
    }

    private var waterCard: some View {
        WellnessCard {
            VStack(alignment: .leading, spacing: 12) {
                ChecklistRow(title: "Water",
                             detail: "\(profile.units.formatWater(liters: water)) / \(profile.units.formatWater(liters: profile.waterTargetLiters))",
                             done: water >= profile.waterTargetLiters, icon: "drop", chevron: false)
                HStack {
                    ForEach(profile.units.waterQuickAdds, id: \.self) { amount in
                        Button(profile.units.waterQuickAddLabel(liters: amount)) {
                            context.insert(WaterEntity(liters: amount))
                            try? context.save()
                            Haptics.tap()
                        }
                        .buttonStyle(.bordered)
                    }
                    if water > 0 {
                        Spacer()
                        Button { undoLastWater() } label: { Image(systemName: "arrow.uturn.backward") }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Undo last water")
                    }
                }
            }
        }
    }

    private var supplementsCard: some View {
        WellnessCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Supplements").font(.headline)
                if supplements.isEmpty {
                    Text("Add supplements in Settings to track them here.").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(supplements) { supplement in
                    let done = checks.contains { isToday($0.date) && $0.supplementName == supplement.name }
                    Button { toggle(supplement.name, done: done) } label: {
                        Label(supplement.name, systemImage: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? Color.sage : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Actions

    private func toggle(_ name: String, done: Bool) {
        if done, let match = checks.first(where: { isToday($0.date) && $0.supplementName == name }) {
            context.delete(match)
        } else {
            context.insert(SupplementCheckEntity(name: name))
        }
        try? context.save()
        Haptics.tap()
    }

    private func undoLastWater() {
        guard let last = waters.filter({ isToday($0.date) }).max(by: { $0.date < $1.date }) else { return }
        context.delete(last)
        try? context.save()
    }

    private func start(_ template: TemplateEntity) {
        let workout = WorkoutEntity.make(from: template, date: .now)
        context.insert(workout)
        try? context.save()
        Haptics.success()
        startedWorkout = workout
    }
}
