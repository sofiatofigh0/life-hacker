import SwiftUI
import SwiftData
import Combine

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
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
    /// "Today" is state, not `Date.now`, so the screen rolls over at midnight
    /// and when the app returns to the foreground on a new day.
    @State private var today = Date.now

    // MARK: Derived

    private var calendar: Calendar { .current }
    private func isToday(_ date: Date) -> Bool { calendar.isDate(date, inSameDayAs: today) }

    private var macros: Macro {
        logs.filter { isToday($0.date) }.reduce(Macro()) { $0 + Macro(calories: $1.calories, protein: $1.protein, carbs: $1.carbs, fat: $1.fat) }
    }
    private var water: Double { waters.filter { isToday($0.date) }.map(\.liters).reduce(0, +) }
    private var steps: Double { activities.first { isToday($0.date) }?.steps ?? 0 }
    private var todaysWorkout: WorkoutEntity? {
        workouts.first { isToday($0.date) && $0.completed } ?? workouts.first { isToday($0.date) }
    }
    private var scheduledTemplate: TemplateEntity? {
        let weekday = calendar.component(.weekday, from: today)
        return templates.first { $0.weekday == weekday }
    }
    private var todaysWeight: WeightEntity? { weights.first { isToday($0.date) } }
    private var checkedToday: Int { checks.filter { isToday($0.date) }.count }
    private var calorieRatio: Double { profile.calorieTarget > 0 ? macros.calories / Double(profile.calorieTarget) : 0 }
    private var caloriesInRange: Bool { (0.9...1.1).contains(calorieRatio) }
    private var caloriesOver: Bool { calorieRatio > 1.1 }

    private var index: DailyScoreIndex {
        DailyScoreIndex(profile: profile, logs: logs, workouts: workouts, activities: activities,
                        waters: waters, checks: checks, supplementCount: supplements.count)
    }

    // MARK: Body

    var body: some View {
        let index = self.index
        let score = index.score(on: today)
        let streak = Streak.consecutiveDays(scoreForDay: { index.score(on: $0) }, threshold: 0.7, today: today, calendar: calendar)
        TabScreen(eyebrow: today.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                  title: Greeting.text(hour: calendar.component(.hour, from: today), name: profile.name)) {
            HeaderButton(systemImage: "gearshape", label: "Settings") { showSettings = true }
        } content: {
            completionCard(score: score, streak: streak)
            workoutCard
            NavigationLink { FoodView(profile: profile, embedded: true) } label: {
                card(ChecklistRow(title: "Calories", detail: calorieDetail, done: caloriesInRange, icon: "fork.knife",
                                  progress: calorieRatio, progressTint: caloriesOver ? .orange : .sage))
            }.buttonStyle(.plain)
            NavigationLink { FoodView(profile: profile, embedded: true) } label: {
                card(ChecklistRow(title: "Protein", detail: proteinDetail, done: macros.protein >= Double(profile.proteinTarget), icon: "leaf",
                                  progress: profile.proteinTarget > 0 ? macros.protein / Double(profile.proteinTarget) : 0))
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
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in today = .now }
        .onChange(of: scenePhase) { _, phase in if phase == .active { today = .now } }
    }

    private func card(_ row: ChecklistRow) -> some View { WellnessCard { row } }

    // MARK: Copy

    private var calorieDetail: String {
        let eaten = Int(macros.calories)
        let target = profile.calorieTarget
        guard eaten > 0 else { return "\(target.formatted()) kcal today" }
        let diff = target - eaten
        if diff >= 0 { return "\(diff.formatted()) left · \(eaten.formatted()) of \(target.formatted())" }
        return "\((-diff).formatted()) over · \(eaten.formatted()) of \(target.formatted())"
    }

    private var proteinDetail: String {
        let eaten = Int(macros.protein)
        let target = profile.proteinTarget
        guard eaten > 0 else { return "\(target) g today" }
        let diff = target - eaten
        if diff > 0 { return "\(diff) g to go · \(eaten) of \(target) g" }
        return "Target met · \(eaten) of \(target) g"
    }

    // MARK: Cards

    private func completionCard(score: Double, streak: Int) -> some View {
        WellnessCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(.sage.opacity(0.2), lineWidth: 8)
                    Circle().trim(from: 0, to: score).stroke(.sage, style: .init(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text(score, format: .percent.precision(.fractionLength(0))).font(.headline)
                }
                .frame(width: 82, height: 82)
                .animation(.easeOut(duration: 0.4), value: score)
                .accessibilityLabel("Daily completion \(Int(score * 100)) percent")
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.goal.label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Daily completion").font(.title3.weight(.semibold))
                    if streak > 0 {
                        Label("\(streak)-day streak", systemImage: "flame.fill").font(.caption).foregroundStyle(.orange)
                    } else {
                        Text("Reach 70% to start a streak.").font(.caption).foregroundStyle(.secondary)
                    }
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
                    ChecklistRow(title: "Steps", detail: stepsDetail, done: steps >= Double(profile.stepTarget), icon: "figure.walk", chevron: false,
                                 progress: profile.stepTarget > 0 ? steps / Double(profile.stepTarget) : 0)
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
                             done: water >= profile.waterTargetLiters, icon: "drop", chevron: false,
                             progress: profile.waterTargetLiters > 0 ? water / profile.waterTargetLiters : 0)
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
                HStack {
                    Text("Supplements").font(.headline)
                    Spacer()
                    if !supplements.isEmpty {
                        Text("\(checkedToday) / \(supplements.count)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
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
