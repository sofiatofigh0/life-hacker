import SwiftUI
import SwiftData

@main struct AureliaApp: App {
    private let container: ModelContainer = {
        let schema = Schema([AppProfile.self, ExerciseEntity.self, TemplateEntity.self, WorkoutEntity.self,
            SessionExerciseEntity.self, SetEntity.self, FoodEntity.self, FoodLogEntity.self, SavedMealEntity.self,
            WaterEntity.self, SupplementEntity.self, SupplementCheckEntity.self, WeightEntity.self,
            ActivityEntity.self, PhotoSetEntity.self])
        return try! ModelContainer(for: schema)
    }()
    var body: some Scene { WindowGroup { RootView() }.modelContainer(container) }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [AppProfile]
    var body: some View {
        Group { if let profile = profiles.first, profile.onboarded { MainTabs(profile: profile) } else { OnboardingView() } }
            .task { seedLibrary() }.tint(.sage)
    }
    private func seedLibrary() {
        let count = (try? context.fetchCount(FetchDescriptor<ExerciseEntity>())) ?? 0
        guard count == 0 else { return }; SeedData.exercises.forEach { context.insert(ExerciseEntity($0.0, summary: $0.1, tips: $0.2)) }; try? context.save()
    }
}

struct MainTabs: View {
    let profile: AppProfile
    var body: some View {
        TabView {
            NavigationStack { TodayView(profile: profile) }.tabItem { Label("Today", systemImage: "sun.max") }
            NavigationStack { WorkoutHome() }.tabItem { Label("Workout", systemImage: "dumbbell") }
            NavigationStack { FoodView(profile: profile) }.tabItem { Label("Food", systemImage: "leaf") }
            NavigationStack { CalendarHistoryView(profile: profile) }.tabItem { Label("Calendar", systemImage: "calendar") }
            NavigationStack { ProgressView(profile: profile) }.tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}

extension Color {
    static let sage = Color(red: 0.38, green: 0.49, blue: 0.42)
    static let cream = Color(red: 0.97, green: 0.95, blue: 0.91)
}
struct EditorialTitle: View { let eyebrow: String; let title: String; var body: some View { VStack(alignment: .leading, spacing: 5) { Text(eyebrow.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary); Text(title).font(.system(.largeTitle, design: .serif, weight: .medium)) }.frame(maxWidth: .infinity, alignment: .leading) } }
struct WellnessCard<Content: View>: View { @ViewBuilder var content: Content; var body: some View { content.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.background).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.05), radius: 14, y: 5) } }

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var page = 0; @State private var age = 30; @State private var sex = Sex.female; @State private var height = 165.0
    @State private var current = 70.0; @State private var goal = 65.0; @State private var activity = ActivityLevel.moderate
    @State private var mode = GoalMode.cut; @State private var units = UnitSystem.imperial; @State private var calories = 1800; @State private var protein = 115
    @State private var steps = 10_000; @State private var water = 1.9; @State private var healthMessage = "Connect when ready"
    var body: some View {
        NavigationStack { ZStack { Color.cream.ignoresSafeArea(); VStack(spacing: 28) {
            EditorialTitle(eyebrow: "Aurelia", title: page == 0 ? "Wellness, considered." : page == 1 ? "Your foundations" : "A gentle direction")
            Group {
                if page == 0 { Text("A private, offline-first home for training, nourishment, activity, and progress.").font(.title3).foregroundStyle(.secondary); Spacer() }
                else if page == 1 { Form { Stepper("Age: \(age)", value: $age, in: 16...100); Picker("Sex", selection: $sex) { ForEach(Sex.allCases, id: \.self) { Text($0.rawValue.capitalized) } }; LabeledContent("Height (cm)") { TextField("", value: $height, format: .number).keyboardType(.decimalPad) }; LabeledContent("Current weight (kg)") { TextField("", value: $current, format: .number).keyboardType(.decimalPad) }; LabeledContent("Goal weight (kg)") { TextField("", value: $goal, format: .number).keyboardType(.decimalPad) }; Picker("Activity", selection: $activity) { ForEach(ActivityLevel.allCases, id: \.self) { Text(String(describing: $0)) } }; Picker("Units", selection: $units) { ForEach(UnitSystem.allCases, id: \.self) { Text($0.rawValue.capitalized) } } }.scrollContentBackground(.hidden) }
                else { Form { Picker("Goal", selection: $mode) { Text("Cut").tag(GoalMode.cut); Text("Maintain / Recomp").tag(GoalMode.maintain); Text("Bulk").tag(GoalMode.bulk) }.onChange(of: mode) { recommend() }; LabeledContent("Daily calories") { TextField("", value: $calories, format: .number).keyboardType(.numberPad) }; LabeledContent("Protein (g)") { TextField("", value: $protein, format: .number).keyboardType(.numberPad) }; LabeledContent("Steps") { TextField("", value: $steps, format: .number).keyboardType(.numberPad) }; LabeledContent("Water (L)") { TextField("", value: $water, format: .number).keyboardType(.decimalPad) }; Button("Connect Apple Health") { Task { do { try await HealthKitService().authorize(); healthMessage = "Health access requested" } catch { healthMessage = "You can connect later in Settings" } } }; Text(healthMessage).font(.footnote).foregroundStyle(.secondary) }.scrollContentBackground(.hidden) }
            }
            Button(page == 2 ? "Begin" : "Continue") { if page < 2 { page += 1; if page == 2 { recommend() } } else { finish() } }.buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
        }.padding(24) } }
    }
    private func recommend() { let r = GoalCalculator.recommend(age: age, sex: sex, heightCM: height, weightKG: current, activity: activity, mode: mode); calories = r.calories; protein = r.proteinGrams }
    private func finish() { context.insert(AppProfile(age: age, sex: sex, heightCM: height, currentKG: current, goalKG: goal, activity: activity, units: units, goal: mode, calorieTarget: calories, proteinTarget: protein, stepTarget: steps, waterTargetLiters: water, onboarded: true)); context.insert(SupplementEntity(name: "Creatine")); context.insert(SupplementEntity(name: "Multivitamin", order: 1)); try? context.save() }
}
