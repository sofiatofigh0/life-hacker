import SwiftUI
import SwiftData
import Charts

struct TodayView: View {
    @Environment(\.modelContext) private var context; let profile: AppProfile
    @Query(sort: \WorkoutEntity.date, order: .reverse) private var workouts: [WorkoutEntity]
    @Query private var logs: [FoodLogEntity]; @Query private var waters: [WaterEntity]; @Query private var supplements: [SupplementEntity]; @Query private var checks: [SupplementCheckEntity]; @Query private var weights: [WeightEntity]; @Query private var activities: [ActivityEntity]
    @State private var showAddWorkout = false; @State private var showSettings = false; @State private var showWeight = false
    private var cal: Calendar { .current }; private func today(_ date: Date) -> Bool { cal.isDateInToday(date) }
    private var macros: Macro { logs.filter { today($0.date) }.reduce(Macro()) { $0 + Macro(calories: $1.calories, protein: $1.protein, carbs: $1.carbs, fat: $1.fat) } }
    private var water: Double { waters.filter { today($0.date) }.map(\.liters).reduce(0,+) }; private var steps: Double { activities.first(where: { today($0.date) })?.steps ?? 0 }
    private var workoutDone: Bool { workouts.contains { today($0.date) && $0.completed } }; private var supplementFraction: Double { supplements.isEmpty ? 1 : Double(checks.filter { today($0.date) }.count) / Double(supplements.count) }
    private var score: Double { CompletionCalculator.score(.init(workout: workoutDone, calories: macros.calories, calorieTarget: Double(profile.calorieTarget), protein: macros.protein, proteinTarget: Double(profile.proteinTarget), steps: steps, stepTarget: Double(profile.stepTarget), waterLiters: water, waterTargetLiters: profile.waterTargetLiters, supplementFraction: supplementFraction)) }
    var body: some View { ScrollView { VStack(spacing: 18) {
        HStack(alignment: .top) { EditorialTitle(eyebrow: "Today", title: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())); Button { showSettings = true } label: { Image(systemName: "gearshape").frame(width: 44, height: 44) } }
        WellnessCard { HStack { ZStack { Circle().stroke(.sage.opacity(0.2), lineWidth: 8); Circle().trim(from: 0, to: score).stroke(.sage, style: .init(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90)); Text(score, format: .percent.precision(.fractionLength(0))).font(.headline) }.frame(width: 82, height: 82); VStack(alignment: .leading) { Text(profile.goalRaw.capitalized).font(.caption.weight(.semibold)).foregroundStyle(.secondary); Text("Daily completion").font(.title3.weight(.semibold)); Text("Activity never increases your calorie allowance.").font(.caption).foregroundStyle(.secondary) } } }
        Button { showAddWorkout = true } label: { checklist("Workout", detail: workoutDone ? "Completed" : "Add strength or cardio", done: workoutDone, icon: "dumbbell") }.buttonStyle(.plain)
        NavigationLink { FoodView(profile: profile) } label: { checklist("Calories", detail: "\(Int(macros.calories)) / \(profile.calorieTarget) kcal", done: (0.9...1.1).contains(macros.calories / Double(profile.calorieTarget)), icon: "fork.knife") }.buttonStyle(.plain)
        NavigationLink { FoodView(profile: profile) } label: { checklist("Protein", detail: "\(Int(macros.protein)) / \(profile.proteinTarget) g", done: macros.protein >= Double(profile.proteinTarget), icon: "leaf") }.buttonStyle(.plain)
        checklist("Steps", detail: "\(Int(steps).formatted()) / \(profile.stepTarget.formatted())", done: steps >= Double(profile.stepTarget), icon: "figure.walk")
        WellnessCard { VStack(alignment: .leading) { checklistRow("Water", "\(displayWater(water)) / \(displayWater(profile.waterTargetLiters))", water >= profile.waterTargetLiters, "drop"); HStack { ForEach([0.237, 0.355, 0.473], id: \.self) { amount in Button(profile.units == .metric ? "+\(Int(amount*1000)) mL" : "+\(Int(Units.fluidOunces(fromLiters: amount))) oz") { context.insert(WaterEntity(liters: amount)); try? context.save() }.buttonStyle(.bordered) } } } }
        WellnessCard { VStack(alignment: .leading, spacing: 12) { Text("Supplements").font(.headline); ForEach(supplements) { supplement in let done = checks.contains { today($0.date) && $0.supplementName == supplement.name }; Button { toggle(supplement.name, done: done) } label: { Label(supplement.name, systemImage: done ? "checkmark.circle.fill" : "circle") }.buttonStyle(.plain) } } }
        Button { showWeight = true } label: { checklist("Weight", detail: weights.contains(where: { today($0.date) }) ? "Logged today" : "Log weight", done: weights.contains(where: { today($0.date) }), icon: "scalemass") }.buttonStyle(.plain)
    }.padding(18) }.background(Color.cream.opacity(0.45)).navigationBarHidden(true)
    .sheet(isPresented: $showAddWorkout) { AddWorkoutView() }.sheet(isPresented: $showSettings) { NavigationStack { SettingsView(profile: profile) } }.sheet(isPresented: $showWeight) { WeightEntryView(profile: profile, date: .now) }
    }
    private func checklist(_ title: String, detail: String, done: Bool, icon: String) -> some View { WellnessCard { checklistRow(title, detail, done, icon) } }
    private func checklistRow(_ title: String, _ detail: String, _ done: Bool, _ icon: String) -> some View { HStack { Image(systemName: icon).frame(width: 30).foregroundStyle(.sage); VStack(alignment: .leading) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Image(systemName: done ? "checkmark.circle.fill" : "chevron.right").foregroundStyle(done ? .sage : .secondary) } }
    private func displayWater(_ liters: Double) -> String { profile.units == .metric ? "\(Int(liters*1000)) mL" : "\(Int(Units.fluidOunces(fromLiters: liters))) oz" }
    private func toggle(_ name: String, done: Bool) { if done, let match = checks.first(where: { today($0.date) && $0.supplementName == name }) { context.delete(match) } else { context.insert(SupplementCheckEntity(name: name)) }; try? context.save() }
}

struct FoodView: View {
    @Environment(\.modelContext) private var context; let profile: AppProfile; @State var date = Date.now
    @Query(sort: \FoodLogEntity.date, order: .reverse) private var logs: [FoodLogEntity]; @State private var add = false
    private var dayLogs: [FoodLogEntity] { logs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    private var total: Macro { dayLogs.reduce(Macro()) { $0 + .init(calories: $1.calories, protein: $1.protein, carbs: $1.carbs, fat: $1.fat) } }
    var body: some View { ScrollView { VStack(spacing: 18) { EditorialTitle(eyebrow: "Nourishment", title: date.formatted(.dateTime.month(.wide).day())); WellnessCard { HStack { metric("Calories", total.calories, Double(profile.calorieTarget), "kcal"); Divider(); metric("Protein", total.protein, Double(profile.proteinTarget), "g") }; Divider(); HStack { Text("Carbs  \(Int(total.carbs))g"); Spacer(); Text("Fat  \(Int(total.fat))g") }.foregroundStyle(.secondary) }
        ForEach(Meal.allCases, id: \.self) { meal in WellnessCard { VStack(alignment: .leading) { Text(meal.rawValue.capitalized).font(.headline); let entries = dayLogs.filter { $0.mealRaw == meal.rawValue }; if entries.isEmpty { Text("Nothing logged yet").foregroundStyle(.secondary).padding(.vertical, 8) } else { ForEach(entries) { entry in HStack { VStack(alignment: .leading) { Text(entry.foodName); Text("\(Int(entry.grams)) g").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(Int(entry.calories)) kcal") }.swipeActions { Button(role: .destructive) { context.delete(entry) } label: { Label("Delete", systemImage: "trash") } } } } } }
    }.padding(18) }.background(Color.cream.opacity(0.45)).toolbar { ToolbarItem(placement: .primaryAction) { Button { add = true } label: { Label("Add Food", systemImage: "plus") } } }.sheet(isPresented: $add) { NavigationStack { AddFoodView(date: date) } } }
    private func metric(_ title: String, _ value: Double, _ target: Double, _ unit: String) -> some View { VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text("\(Int(value))").font(.system(.title, design: .serif, weight: .semibold)); Text("of \(Int(target)) \(unit)").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) }
}
