import SwiftUI
import SwiftData

/// Three pages: welcome → measurements → targets.
///
/// Units are chosen *first*, and every field after that is shown in the chosen
/// system. The original asked an imperial user (the default) for height in cm
/// and weight in kg before showing the units picker at the bottom of the form.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var page = 0

    // Stored metric; edited through unit-aware bindings.
    @State private var units = UnitSystem.imperial
    @State private var name = ""
    @State private var age = 30
    @State private var sex = Sex.female
    @State private var heightCM = 165.0
    @State private var currentKG = 70.0
    @State private var goalKG = 65.0
    @State private var activity = ActivityLevel.moderate

    @State private var mode = GoalMode.cut
    @State private var calories = 1800
    @State private var protein = 115
    @State private var steps = 10_000
    @State private var waterLiters = 1.9
    @State private var healthMessage: String?
    @State private var sync = HealthSync.shared

    private let titles = ["Wellness, considered.", "Your foundations", "A gentle direction"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                VStack(spacing: 24) {
                    EditorialTitle(eyebrow: "Aurelia · \(page + 1) of 3", title: titles[page])
                    Group {
                        switch page {
                        case 0: welcome
                        case 1: foundations
                        default: direction
                        }
                    }
                    HStack(spacing: 12) {
                        if page > 0 {
                            Button("Back") { page -= 1 }.buttonStyle(.bordered).controlSize(.large)
                        }
                        Button(page == 2 ? "Begin" : "Continue") {
                            if page < 2 { page += 1; if page == 2 { recommend() } } else { finish() }
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                    }
                }
                .padding(24)
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A private, offline-first home for training, nourishment, activity, and progress.")
                .font(.title3).foregroundStyle(.secondary)
            Text("Everything stays on this phone. Nothing is uploaded.")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var foundations: some View {
        Form {
            Section {
                Picker("Units", selection: $units) {
                    Text("Imperial (lb, in)").tag(UnitSystem.imperial)
                    Text("Metric (kg, cm)").tag(UnitSystem.metric)
                }
                .pickerStyle(.segmented)
            }
            Section("About you") {
                TextField("Name (optional)", text: $name)
                Stepper("Age: \(age)", value: $age, in: 16...100)
                Picker("Sex", selection: $sex) {
                    ForEach(Sex.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                LabeledContent("Height (\(units.heightUnit))") {
                    DecimalField(placeholder: units.isMetric ? "165" : "65", value: heightBinding, fractionDigits: 1)
                }
            }
            Section("Weight") {
                LabeledContent("Current (\(units.weightUnit))") {
                    DecimalField(placeholder: units.isMetric ? "70" : "154", value: weightBinding($currentKG))
                }
                LabeledContent("Goal (\(units.weightUnit))") {
                    DecimalField(placeholder: units.isMetric ? "65" : "143", value: weightBinding($goalKG))
                }
            }
            Section("Activity") {
                Picker("Typical week", selection: $activity) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        VStack(alignment: .leading) {
                            Text(level.label)
                            Text(level.detail).font(.caption).foregroundStyle(.secondary)
                        }.tag(level)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var direction: some View {
        Form {
            Section {
                Picker("Goal", selection: $mode) {
                    ForEach(GoalMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .onChange(of: mode) { _, _ in recommend() }
            } footer: {
                Text("Calories and protein are suggested from your measurements and goal (Mifflin–St Jeor). Edit them freely. Activity never adds calories back.")
            }
            Section("Daily targets") {
                LabeledContent("Calories") { DecimalField(placeholder: "1800", value: intBinding($calories), integer: true) }
                LabeledContent("Protein (g)") { DecimalField(placeholder: "120", value: intBinding($protein), integer: true) }
                LabeledContent("Steps") { DecimalField(placeholder: "10000", value: intBinding($steps), integer: true) }
                LabeledContent("Water (\(units.waterUnit))") {
                    DecimalField(placeholder: units.isMetric ? "2000" : "64",
                                 value: $waterLiters.zeroAsNil.converted(toDisplay: { units.displayWater(liters: $0) },
                                                                        fromDisplay: { units.liters(fromDisplayWater: $0) }),
                                 integer: true)
                }
            }
            Section("Apple Health") {
                Button {
                    Task {
                        await sync.requestAccessAndSync(context: context)
                        healthMessage = sync.lastError ?? "Connected. Steps and active calories will sync automatically."
                    }
                } label: { Label("Connect Apple Health", systemImage: "heart.text.square") }
                Text(healthMessage ?? "Optional — you can connect later in Settings.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: Bindings

    private var heightBinding: Binding<Double?> {
        $heightCM.zeroAsNil.converted(toDisplay: { units.displayHeight(centimeters: $0) },
                                      fromDisplay: { units.centimeters(fromDisplayHeight: $0) })
    }
    private func weightBinding(_ kg: Binding<Double>) -> Binding<Double?> {
        kg.zeroAsNil.converted(toDisplay: { units.displayWeight(kilograms: $0) },
                               fromDisplay: { units.kilograms(fromDisplayWeight: $0) })
    }
    private func intBinding(_ b: Binding<Int>) -> Binding<Double?> { b.zeroAsNil }

    private func recommend() {
        let r = GoalCalculator.recommend(age: age, sex: sex, heightCM: heightCM, weightKG: currentKG, activity: activity, mode: mode)
        calories = r.calories
        protein = r.proteinGrams
    }

    private func finish() {
        let profile = AppProfile(name: name, age: age, sex: sex, heightCM: heightCM, currentKG: currentKG, goalKG: goalKG,
                                 activity: activity, units: units, goal: mode, calorieTarget: calories, proteinTarget: protein,
                                 stepTarget: steps, waterTargetLiters: waterLiters, onboarded: true)
        context.insert(profile)
        context.insert(WeightEntity(date: .now, kilograms: currentKG))
        context.insert(SupplementEntity(name: "Creatine", order: 0))
        context.insert(SupplementEntity(name: "Multivitamin", order: 1))
        try? context.save()
    }
}
