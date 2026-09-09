import SwiftUI
import SwiftData

extension WorkoutEntity {
    /// A session created from a template: one exercise per template entry,
    /// each with the template's default number of empty sets.
    static func make(from template: TemplateEntity, date: Date) -> WorkoutEntity {
        let exercises = template.exerciseNames.enumerated().map { index, name in
            SessionExerciseEntity(name: name, order: index, sets: (0..<template.defaultSets).map { SetEntity(order: $0) })
        }
        return WorkoutEntity(date: date, name: template.name, exercises: exercises)
    }
}

/// Routes to the right editor for a session.
struct WorkoutEditor: View {
    let workout: WorkoutEntity
    let profile: AppProfile
    var body: some View {
        if workout.isCardio { CardioEditor(workout: workout, profile: profile) }
        else { StrengthSessionView(workout: workout, profile: profile) }
    }
}

// MARK: - Home

struct WorkoutHome: View {
    @Environment(\.modelContext) private var context
    let profile: AppProfile
    @Query(sort: \WorkoutEntity.date, order: .reverse) private var sessions: [WorkoutEntity]
    @Query(sort: \TemplateEntity.weekday) private var templates: [TemplateEntity]
    @State private var add = false
    @State private var builder = false
    @State private var pendingDelete: WorkoutEntity?

    private var scheduledToday: TemplateEntity? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return templates.first { $0.weekday == weekday }
    }

    var body: some View {
        TabScreen(eyebrow: "Training", title: "Move with intention") {
            HeaderButton(systemImage: "calendar.badge.clock", label: "Weekly schedule") { builder = true }
        } content: {
            Button { add = true } label: {
                Label("Add Workout", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)

            if let template = scheduledToday, !sessions.contains(where: { Calendar.current.isDateInToday($0.date) }) {
                WellnessCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scheduled today").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(template.name).font(.headline)
                        }
                        Spacer()
                        Button("Start") {
                            context.insert(WorkoutEntity.make(from: template, date: .now))
                            try? context.save()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if sessions.isEmpty {
                ContentUnavailableView("No sessions yet", systemImage: "dumbbell", description: Text("Start a strength or cardio workout."))
            } else {
                ForEach(sessions.prefix(30)) { workout in
                    NavigationLink { WorkoutEditor(workout: workout, profile: profile) } label: {
                        WellnessCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workout.name).font(.headline)
                                    Text(subtitle(for: workout)).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: workout.completed ? "checkmark.circle.fill" : "chevron.right")
                                    .foregroundStyle(workout.completed ? Color.sage : Color.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { pendingDelete = workout } label: { Label("Delete workout", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(isPresented: $add) { AddWorkoutView(date: .now) }
        .sheet(isPresented: $builder) { NavigationStack { TemplateBuilderView() } }
        .confirmationDialog("Delete this workout?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            presenting: pendingDelete) { workout in
            Button("Delete \(workout.name)", role: .destructive) { context.delete(workout); try? context.save() }
        } message: { _ in Text("Sets and notes for this session will be removed.") }
    }

    private func subtitle(for workout: WorkoutEntity) -> String {
        var parts = [workout.date.formatted(date: .abbreviated, time: .omitted)]
        if workout.isCardio, workout.durationMinutes > 0 { parts.append("\(Int(workout.durationMinutes)) min") }
        else if !workout.isCardio { parts.append("\(workout.exercises.count) exercise\(workout.exercises.count == 1 ? "" : "s")") }
        if !workout.completed { parts.append("in progress") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Add

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \TemplateEntity.weekday) private var templates: [TemplateEntity]
    let date: Date

    private let cardio = ["Walking", "Outdoor Walking", "Running", "Incline Treadmill", "Treadmill", "Cycling",
                          "Stationary Bike", "Elliptical", "Stair Climber", "Swimming", "Rowing", "Hiking", "Other"]

    var body: some View {
        NavigationStack {
            List {
                Section("Strength") {
                    ForEach(templates) { template in
                        Button {
                            insert(WorkoutEntity.make(from: template, date: date))
                        } label: {
                            HStack {
                                Text(template.name)
                                Spacer()
                                Text(template.exerciseNames.isEmpty ? "No exercises" : "\(template.exerciseNames.count) exercises")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("Quick strength session") { insert(WorkoutEntity(date: date, name: "Strength")) }
                }
                Section("Cardio") {
                    ForEach(cardio, id: \.self) { name in
                        Button(name) { insert(WorkoutEntity(date: date, name: name, isCardio: true)) }
                    }
                }
            }
            .navigationTitle("Add Workout")
            .toolbar { Button("Cancel") { dismiss() } }
        }
    }

    private func insert(_ workout: WorkoutEntity) {
        context.insert(workout)
        try? context.save()
        dismiss()
    }
}

// MARK: - Strength

struct StrengthSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let workout: WorkoutEntity
    let profile: AppProfile
    @State private var addExercise = false
    @State private var confirmDelete = false

    private var units: UnitSystem { profile.units }
    private var orderedExercises: [SessionExerciseEntity] { workout.exercises.sorted { $0.order < $1.order } }

    var body: some View {
        List {
            if workout.completed {
                Section {
                    Label("Completed", systemImage: "checkmark.circle.fill").foregroundStyle(.sage)
                }
            }
            ForEach(orderedExercises) { exercise in
                Section {
                    ForEach(exercise.sets.sorted { $0.order < $1.order }) { set in
                        HStack(spacing: 12) {
                            Text("Set \(set.order + 1)").frame(width: 52, alignment: .leading).foregroundStyle(.secondary)
                            DecimalField(placeholder: units.weightUnit, value: weightBinding(set))
                                .textFieldStyle(.roundedBorder)
                            DecimalField(placeholder: "reps", value: Bindable(set).reps.zeroAsNil, integer: true)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .onDelete { offsets in
                        let ordered = exercise.sets.sorted { $0.order < $1.order }
                        offsets.map { ordered[$0] }.forEach(context.delete)
                        try? context.save()
                    }
                    Button("Add set") {
                        let next = (exercise.sets.map(\.order).max() ?? -1) + 1
                        exercise.sets.append(SetEntity(order: next))
                        try? context.save()
                    }
                } header: {
                    HStack {
                        Text(exercise.name)
                        Spacer()
                        NavigationLink { ExerciseDetail(name: exercise.name) } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                } footer: {
                    Button("Remove exercise", role: .destructive) {
                        context.delete(exercise)
                        try? context.save()
                    }
                    .font(.caption)
                }
            }
            Section {
                Button { addExercise = true } label: { Label("Add exercise", systemImage: "plus") }
                if workout.completed {
                    Button("Reopen workout") { workout.completed = false; try? context.save() }
                } else {
                    Button("Finish workout") { workout.completed = true; try? context.save(); Haptics.success() }
                        .buttonStyle(.borderedProminent)
                        .disabled(workout.exercises.isEmpty)
                }
            }
            Section {
                Button("Delete workout", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(workout.name)
        .sheet(isPresented: $addExercise) { ExercisePicker(exclude: Set(workout.exercises.map(\.name))) { name in add(name) } }
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { context.delete(workout); try? context.save(); dismiss() }
        }
    }

    private func weightBinding(_ set: SetEntity) -> Binding<Double?> {
        Bindable(set).weightKG.zeroAsNil.converted(toDisplay: { units.displayWeight(kilograms: $0) },
                                                    fromDisplay: { units.kilograms(fromDisplayWeight: $0) })
    }

    private func add(_ name: String) {
        let next = (workout.exercises.map(\.order).max() ?? -1) + 1
        workout.exercises.append(SessionExerciseEntity(name: name, order: next, sets: (0..<3).map { SetEntity(order: $0) }))
        try? context.save()
        addExercise = false
    }
}

/// Searchable exercise library. The original bound the search bar to a constant.
struct ExercisePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ExerciseEntity.name) private var library: [ExerciseEntity]
    var exclude: Set<String> = []
    let onPick: (String) -> Void
    @State private var search = ""

    private var matches: [ExerciseEntity] {
        library.filter { !exclude.contains($0.name) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
    }
    private var canCreate: Bool {
        let trimmed = search.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !library.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List {
                if canCreate {
                    Button { create(search.trimmingCharacters(in: .whitespaces)) } label: {
                        Label("Add “\(search.trimmingCharacters(in: .whitespaces))” as a custom exercise", systemImage: "plus.circle")
                    }
                }
                ForEach(matches) { item in
                    Button {
                        onPick(item.name)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            if !item.summary.isEmpty { Text(item.summary).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .toolbar { Button("Cancel") { dismiss() } }
        }
    }

    private func create(_ name: String) {
        context.insert(ExerciseEntity(name, summary: "Custom exercise", tips: ["Move with control"], isCustom: true))
        try? context.save()
        onPick(name)
    }
}

struct ExerciseDetail: View {
    @Query private var exercises: [ExerciseEntity]
    let name: String
    var body: some View {
        let exercise = exercises.first { $0.name == name }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.sage.opacity(0.15))
                    .frame(height: 180)
                    .overlay { Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 55)).foregroundStyle(.sage) }
                Text(exercise?.summary ?? "Custom exercise").font(.title3)
                Text("Form notes").font(.headline)
                ForEach((exercise?.tips ?? "Move with control").components(separatedBy: "\n"), id: \.self) { tip in
                    Label(tip, systemImage: "checkmark")
                }
            }
            .padding()
        }
        .navigationTitle(name)
    }
}

// MARK: - Cardio

struct CardioEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let workout: WorkoutEntity
    let profile: AppProfile
    @State private var confirmDelete = false

    private var units: UnitSystem { profile.units }

    var body: some View {
        Form {
            if workout.completed {
                Section { Label("Completed", systemImage: "checkmark.circle.fill").foregroundStyle(.sage) }
            }
            Section("Session") {
                LabeledContent("Duration (minutes)") { DecimalField(placeholder: "30", value: Bindable(workout).durationMinutes.zeroAsNil, integer: true) }
                LabeledContent("Distance (\(units.distanceUnit))") {
                    DecimalField(placeholder: "Optional", value: distanceBinding, fractionDigits: 2)
                }
                if workout.name.localizedCaseInsensitiveContains("incline") {
                    LabeledContent("Incline %") { DecimalField(placeholder: "10", value: Bindable(workout).incline) }
                }
                LabeledContent("Speed (\(units.speedUnit))") {
                    DecimalField(placeholder: "Optional", value: speedBinding)
                }
                LabeledContent("Calories") { DecimalField(placeholder: "Optional", value: Bindable(workout).calories, integer: true) }
                LabeledContent("Average heart rate") { DecimalField(placeholder: "Optional", value: Bindable(workout).averageHeartRate, integer: true) }
                TextField("Notes", text: Bindable(workout).notes, axis: .vertical)
            }
            Section {
                if workout.completed {
                    Button("Reopen") { workout.completed = false; try? context.save() }
                } else {
                    Button("Save & complete") { workout.completed = true; try? context.save(); Haptics.success() }.buttonStyle(.borderedProminent)
                }
            }
            Section {
                Button("Delete workout", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(workout.name)
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { context.delete(workout); try? context.save(); dismiss() }
        }
    }

    private var distanceBinding: Binding<Double?> {
        Bindable(workout).distanceKM.converted(toDisplay: { units.displayDistance(kilometers: $0) },
                                               fromDisplay: { units.kilometers(fromDisplayDistance: $0) })
    }
    private var speedBinding: Binding<Double?> {
        Bindable(workout).speedKPH.converted(toDisplay: { units.displayDistance(kilometers: $0) },
                                             fromDisplay: { units.kilometers(fromDisplayDistance: $0) })
    }
}

// MARK: - Templates

struct TemplateBuilderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TemplateEntity.weekday) private var templates: [TemplateEntity]
    @State private var name = ""
    @State private var weekday = 2

    var body: some View {
        List {
            Section("New template") {
                TextField("Template name", text: $name)
                Picker("Weekday", selection: $weekday) {
                    Text("Unscheduled").tag(0)
                    ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) }
                }
                Button("Create") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    context.insert(TemplateEntity(name: trimmed, weekday: weekday))
                    try? context.save()
                    name = ""
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if templates.isEmpty {
                Section {
                    Text("Templates become one-tap workouts, and a template scheduled for today appears on the Today tab.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            ForEach(templates) { template in
                Section {
                    TextField("Name", text: Bindable(template).name)
                    Picker("Scheduled day", selection: Bindable(template).weekday) {
                        Text("Unscheduled").tag(0)
                        ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) }
                    }
                    Stepper("Default sets: \(template.defaultSets)", value: Bindable(template).defaultSets, in: 1...10)
                    NavigationLink("Exercises (\(template.exerciseNames.count))") { TemplateExercisesView(template: template) }
                    Button("Delete template", role: .destructive) { context.delete(template); try? context.save() }
                } header: { Text(template.name) }
            }
        }
        .navigationTitle("Weekly Schedule")
        .toolbar { Button("Done") { try? context.save(); dismiss() } }
    }
}

struct TemplateExercisesView: View {
    @Environment(\.modelContext) private var context
    let template: TemplateEntity
    @State private var picker = false

    var body: some View {
        List {
            Section("In template") {
                if template.exerciseNames.isEmpty {
                    Text("No exercises yet").foregroundStyle(.secondary)
                }
                ForEach(template.exerciseNames, id: \.self) { Text($0) }
                    .onDelete { template.exerciseNames.remove(atOffsets: $0); try? context.save() }
                    .onMove { template.exerciseNames.move(fromOffsets: $0, toOffset: $1); try? context.save() }
            }
            Section {
                Button { picker = true } label: { Label("Add exercise", systemImage: "plus") }
            }
        }
        .toolbar { EditButton() }
        .navigationTitle(template.name)
        .sheet(isPresented: $picker) {
            ExercisePicker(exclude: Set(template.exerciseNames)) { name in
                template.exerciseNames.append(name)
                try? context.save()
                picker = false
            }
        }
    }
}
