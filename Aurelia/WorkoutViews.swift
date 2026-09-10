import SwiftUI
import SwiftData
import Charts

extension WorkoutEntity {
    /// A session created from a template: one exercise per template entry,
    /// each with the template's default number of empty sets.
    static func make(from template: TemplateEntity, date: Date) -> WorkoutEntity {
        let exercises = template.exerciseNames.enumerated().map { index, name in
            SessionExerciseEntity(name: name, order: index, sets: (0..<template.defaultSets).map { SetEntity(order: $0) })
        }
        return WorkoutEntity(date: date, name: template.name, exercises: exercises)
    }

    /// A fresh session with the same exercises and set counts as `previous`.
    /// Values are left blank on purpose: last time's numbers appear as
    /// placeholders, and ticking a set adopts them.
    static func repeating(_ previous: WorkoutEntity, date: Date) -> WorkoutEntity {
        let ordered = previous.exercises.sorted { $0.order < $1.order }
        var exercises: [SessionExerciseEntity] = []
        for (index, exercise) in ordered.enumerated() {
            let sets = exercise.sets.sorted { $0.order < $1.order }
            var copies: [SetEntity] = []
            for (setIndex, set) in sets.enumerated() { copies.append(SetEntity(order: setIndex, isWarmup: set.isWarmup)) }
            if copies.isEmpty { copies = (0..<3).map { SetEntity(order: $0) } }
            exercises.append(SessionExerciseEntity(name: exercise.name, order: index, sets: copies))
        }
        return WorkoutEntity(date: date, name: previous.name, isCardio: previous.isCardio, exercises: exercises)
    }

    /// Weight × reps over completed working sets, in kilograms.
    var volumeKG: Double {
        let performed: [(weightKG: Double, reps: Int)] = exercises.flatMap { exercise in
            exercise.sets.filter { $0.completed && !$0.isWarmup }.map { (weightKG: $0.weightKG, reps: $0.reps) }
        }
        return Volume.total(sets: performed)
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
    @State private var library = false
    @State private var pendingDelete: WorkoutEntity?
    @State private var opened: WorkoutEntity?

    private var units: UnitSystem { profile.units }
    private var scheduledToday: TemplateEntity? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return templates.first { $0.weekday == weekday }
    }
    private var hasSessionToday: Bool { sessions.contains { Calendar.current.isDateInToday($0.date) } }
    private var lastCompleted: WorkoutEntity? { sessions.first { $0.completed } }

    var body: some View {
        TabScreen(eyebrow: "Training", title: "Move with intention") {
            HStack(spacing: 8) {
                HeaderButton(systemImage: "books.vertical", label: "Exercise library") { library = true }
                HeaderButton(systemImage: "calendar.badge.clock", label: "Weekly schedule") { builder = true }
            }
        } content: {
            Button { add = true } label: {
                Label("Add Workout", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)

            if let template = scheduledToday, !hasSessionToday {
                WellnessCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scheduled today").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(template.name).font(.headline)
                        }
                        Spacer()
                        Button("Start") { start(WorkoutEntity.make(from: template, date: .now)) }
                            .buttonStyle(.bordered)
                    }
                }
            } else if let last = lastCompleted, !hasSessionToday {
                WellnessCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last session · \(last.date.formatted(.relative(presentation: .named)))").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(last.name).font(.headline)
                        }
                        Spacer()
                        Button("Repeat") { start(WorkoutEntity.repeating(last, date: .now)) }
                            .buttonStyle(.bordered)
                    }
                }
            }

            if sessions.isEmpty {
                ContentUnavailableView {
                    Label("No sessions yet", systemImage: "dumbbell")
                } description: {
                    Text("Add a workout above, or set up a weekly schedule so today's session is one tap away.")
                } actions: {
                    Button("Set up schedule") { builder = true }
                }
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
                        Button { start(WorkoutEntity.repeating(workout, date: .now)) } label: { Label("Repeat today", systemImage: "arrow.counterclockwise") }
                        Button(role: .destructive) { pendingDelete = workout } label: { Label("Delete workout", systemImage: "trash") }
                    }
                }
            }
        }
        .sheet(isPresented: $add) { AddWorkoutView(date: .now) }
        .sheet(isPresented: $builder) { NavigationStack { TemplateBuilderView() } }
        .sheet(isPresented: $library) { NavigationStack { ExerciseLibraryView() } }
        .navigationDestination(item: $opened) { WorkoutEditor(workout: $0, profile: profile) }
        .confirmationDialog("Delete this workout?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            presenting: pendingDelete) { workout in
            Button("Delete \(workout.name)", role: .destructive) { context.delete(workout); try? context.save() }
        } message: { _ in Text("Sets and notes for this session will be removed.") }
    }

    private func start(_ workout: WorkoutEntity) {
        context.insert(workout)
        try? context.save()
        Haptics.success()
        opened = workout
    }

    private func subtitle(for workout: WorkoutEntity) -> String {
        var parts = [workout.date.formatted(date: .abbreviated, time: .omitted)]
        if workout.isCardio {
            if workout.durationMinutes > 0 { parts.append("\(Int(workout.durationMinutes)) min") }
            if let km = workout.distanceKM, km > 0 {
                parts.append(units.displayDistance(kilometers: km).formatted(.number.precision(.fractionLength(0...2))) + " " + units.distanceUnit)
            }
        } else {
            parts.append("\(workout.exercises.count) exercise\(workout.exercises.count == 1 ? "" : "s")")
            let volume = workout.volumeKG
            if volume > 0 { parts.append(Int(units.displayWeight(kilograms: volume)).formatted() + " " + units.weightUnit) }
            if workout.durationMinutes > 0 { parts.append("\(Int(workout.durationMinutes)) min") }
        }
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
    @Query(sort: \WorkoutEntity.date, order: .reverse) private var history: [WorkoutEntity]
    @Query private var templates: [TemplateEntity]
    @AppStorage("aurelia.autoRest") private var autoRest = true
    @AppStorage("aurelia.restSeconds") private var restSeconds = 90
    @State private var timer = RestTimer.shared
    @State private var addExercise = false
    @State private var confirmDelete = false

    private var units: UnitSystem { profile.units }
    private var orderedExercises: [SessionExerciseEntity] { workout.exercises.sorted { $0.order < $1.order } }
    private var repRange: String? { templates.first { $0.name == workout.name }?.repRange }

    private var allSets: [SetEntity] { workout.exercises.flatMap(\.sets) }
    private var doneSets: Int { allSets.filter { $0.completed && !$0.isWarmup }.count }
    private var workingSets: Int { allSets.filter { !$0.isWarmup }.count }
    private var elapsedMinutes: Double { Date.now.timeIntervalSince(workout.date) / 60 }
    /// A session started today counts up; anything else is whatever was entered.
    private var showsLiveTimer: Bool { !workout.completed && elapsedMinutes >= 0 && elapsedMinutes < 360 }

    var body: some View {
        List {
            summarySection
            ForEach(orderedExercises) { exercise in
                exerciseSection(exercise)
            }
            Section {
                Button { addExercise = true } label: { Label("Add exercise", systemImage: "plus") }
                if workout.completed {
                    Button("Reopen workout") { workout.completed = false; try? context.save() }
                } else {
                    Button("Finish workout") { finish() }
                        .buttonStyle(.borderedProminent)
                        .disabled(workout.exercises.isEmpty)
                }
            } footer: {
                if !workout.completed {
                    Text("Finishing marks every set with reps as done, removes untouched empty sets, and records the duration.")
                }
            }
            Section("Session") {
                LabeledContent("Duration (min)") { DecimalField(placeholder: "—", value: Bindable(workout).durationMinutes.zeroAsNil, integer: true) }
                TextField("Session notes", text: Bindable(workout).notes, axis: .vertical)
            }
            Section {
                Button("Delete workout", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(workout.name)
        .safeAreaInset(edge: .bottom) { if !workout.completed { RestTimerBar() } }
        .sheet(isPresented: $addExercise) { ExercisePicker(exclude: Set(workout.exercises.map(\.name))) { name in add(name) } }
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { timer.cancel(); context.delete(workout); try? context.save(); dismiss() }
        }
    }

    // MARK: Sections

    private var summarySection: some View {
        Section {
            HStack {
                stat("Volume", Int(units.displayWeight(kilograms: workout.volumeKG)).formatted() + " " + units.weightUnit)
                Divider()
                stat("Sets", "\(doneSets) / \(workingSets)")
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.completed ? "Duration" : "Elapsed").font(.caption).foregroundStyle(.secondary)
                    if showsLiveTimer {
                        Text(workout.date, style: .timer).font(.headline).monospacedDigit()
                    } else {
                        Text(workout.durationMinutes > 0 ? "\(Int(workout.durationMinutes)) min" : "—").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if workout.completed {
                Label("Completed", systemImage: "checkmark.circle.fill").foregroundStyle(.sage).font(.subheadline)
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exerciseSection(_ exercise: SessionExerciseEntity) -> some View {
        let ordered = exercise.sets.sorted { $0.order < $1.order }
        let numbers = Self.displayNumbers(ordered)
        let previous = previousSets(for: exercise.name)
        let best = bestWeight(for: exercise.name)
        return Section {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { pair in
                SetRow(entry: pair.element, number: numbers[pair.offset], units: units,
                       previous: Self.previousSet(previous, number: numbers[pair.offset]), bestWeightKG: best) {
                    if autoRest && !workout.completed { timer.start(seconds: restSeconds) }
                }
            }
            .onDelete { offsets in
                offsets.map { ordered[$0] }.forEach(context.delete)
                try? context.save()
            }
            TextField("Notes (seat 4, felt heavy…)", text: Bindable(exercise).notes, axis: .vertical)
                .font(.subheadline)
            Button("Add set") {
                let next = (exercise.sets.map(\.order).max() ?? -1) + 1
                exercise.sets.append(SetEntity(order: next))
                try? context.save()
            }
        } header: {
            HStack {
                Text(exercise.name)
                if let repRange, !repRange.isEmpty { Text("· \(repRange) reps").foregroundStyle(.secondary) }
                Spacer()
                if let last = previous.last {
                    Text("Last: \(units.displayWeight(kilograms: last.weightKG).formatted(.number.precision(.fractionLength(0...1)))) × \(last.reps)")
                        .textCase(nil).foregroundStyle(.secondary)
                }
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

    // MARK: History lookups

    /// Working sets from the most recent *other* completed session that
    /// included this exercise, in order.
    private func previousSets(for name: String) -> [SetEntity] {
        for session in history where session.completed && session.persistentModelID != workout.persistentModelID {
            if let exercise = session.exercises.first(where: { $0.name == name }) {
                return exercise.sets.filter { !$0.isWarmup && $0.reps > 0 }.sorted { $0.order < $1.order }
            }
        }
        return []
    }

    /// Heaviest weight with at least one rep, in any other session.
    private func bestWeight(for name: String) -> Double {
        var best = 0.0
        for session in history where session.persistentModelID != workout.persistentModelID {
            for exercise in session.exercises where exercise.name == name {
                for set in exercise.sets where set.reps > 0 && !set.isWarmup { best = max(best, set.weightKG) }
            }
        }
        return best
    }

    /// 1-based numbers for working sets; 0 for warm-ups.
    private static func displayNumbers(_ sets: [SetEntity]) -> [Int] {
        var count = 0
        var numbers: [Int] = []
        for set in sets {
            if set.isWarmup { numbers.append(0) } else { count += 1; numbers.append(count) }
        }
        return numbers
    }

    /// Set `number` last time, or the last one if this session has more sets.
    private static func previousSet(_ sets: [SetEntity], number: Int) -> SetEntity? {
        guard number > 0, !sets.isEmpty else { return nil }
        return number <= sets.count ? sets[number - 1] : sets.last
    }

    // MARK: Actions

    private func add(_ name: String) {
        let next = (workout.exercises.map(\.order).max() ?? -1) + 1
        workout.exercises.append(SessionExerciseEntity(name: name, order: next, sets: (0..<3).map { SetEntity(order: $0) }))
        try? context.save()
        addExercise = false
    }

    private func finish() {
        if workout.durationMinutes == 0, elapsedMinutes >= 1, elapsedMinutes < 360 {
            workout.durationMinutes = elapsedMinutes.rounded()
        }
        for exercise in Array(workout.exercises) {
            let sets = Array(exercise.sets)
            let empty = sets.filter { $0.reps == 0 && $0.weightKG == 0 && !$0.completed }
            if empty.count == sets.count {
                context.delete(exercise)
                continue
            }
            for set in sets where set.reps > 0 && !set.completed { set.completed = true }
            empty.forEach(context.delete)
        }
        workout.completed = true
        timer.cancel()
        try? context.save()
        Haptics.success()
    }
}

/// One set: done toggle, number (tap for warm-up / RPE), weight, reps, PR tag.
private struct SetRow: View {
    @Environment(\.modelContext) private var context
    let entry: SetEntity
    let number: Int
    let units: UnitSystem
    let previous: SetEntity?
    let bestWeightKG: Double
    let onCompleted: () -> Void

    private var isPR: Bool { entry.completed && !entry.isWarmup && entry.reps > 0 && bestWeightKG > 0 && entry.weightKG > bestWeightKG }

    var body: some View {
        HStack(spacing: 10) {
            Button { toggle() } label: {
                Image(systemName: entry.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(entry.completed ? Color.sage : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.completed ? "Mark set not done" : "Mark set done")

            Menu {
                Toggle("Warm-up set", isOn: Bindable(entry).isWarmup)
                Picker("RPE", selection: Bindable(entry).rpe) {
                    Text("No RPE").tag(Int?.none)
                    ForEach([6, 7, 8, 9, 10], id: \.self) { value in Text("RPE \(value)").tag(Int?.some(value)) }
                }
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.isWarmup ? "W" : "\(number)").font(.subheadline.weight(.semibold))
                    if let rpe = entry.rpe { Text("@\(rpe)").font(.caption2) }
                }
                .frame(width: 28, alignment: .leading)
            }
            .foregroundStyle(entry.isWarmup ? Color.secondary : Color.primary)
            .accessibilityLabel(entry.isWarmup ? "Warm-up set options" : "Set \(number) options")

            DecimalField(placeholder: weightPlaceholder, value: weightBinding)
                .textFieldStyle(.roundedBorder)
            DecimalField(placeholder: repsPlaceholder, value: Bindable(entry).reps.zeroAsNil, integer: true)
                .textFieldStyle(.roundedBorder)

            if isPR {
                Text("PR")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.sage.opacity(0.18), in: Capsule())
                    .foregroundStyle(.sage)
            }
        }
        .opacity(entry.isWarmup && !entry.completed ? 0.7 : 1)
    }

    private var weightPlaceholder: String {
        guard let previous else { return units.weightUnit }
        return units.displayWeight(kilograms: previous.weightKG).formatted(.number.precision(.fractionLength(0...1)))
    }
    private var repsPlaceholder: String { previous.map { "\($0.reps)" } ?? "reps" }

    private var weightBinding: Binding<Double?> {
        Bindable(entry).weightKG.zeroAsNil.converted(toDisplay: { units.displayWeight(kilograms: $0) },
                                                    fromDisplay: { units.kilograms(fromDisplayWeight: $0) })
    }

    private func toggle() {
        if entry.completed {
            entry.completed = false
        } else {
            // Ticking an untouched set adopts last time's numbers.
            if let previous {
                if entry.reps == 0 { entry.reps = previous.reps }
                if entry.weightKG == 0 { entry.weightKG = previous.weightKG }
            }
            entry.completed = true
            Haptics.tap()
            onCompleted()
        }
        try? context.save()
    }
}

/// Browse the whole exercise library: grouped by muscle group, filterable by
/// equipment, searchable, with form notes a tap away. Custom exercises can be
/// added and deleted here; built-in ones cannot be deleted.
struct ExerciseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ExerciseEntity.name) private var library: [ExerciseEntity]
    @State private var search = ""
    @State private var group: MuscleGroup?
    @State private var equipment: Equipment?

    private var matches: [ExerciseEntity] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return library.filter { entity in
            let definition = ExerciseCatalog.definition(named: entity.name)
            if let group, definition?.muscleGroup != group { return false }
            if let equipment, definition?.equipment != equipment { return false }
            guard !q.isEmpty else { return true }
            let haystack = [entity.name, definition?.muscleGroup.label ?? "Custom", definition?.equipment.label ?? ""].joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(q)
        }
    }
    private var sections: [(title: String, rows: [ExerciseEntity])] {
        var result: [(String, [ExerciseEntity])] = []
        for g in MuscleGroup.allCases {
            let inGroup = matches.filter { ExerciseCatalog.definition(named: $0.name)?.muscleGroup == g }
            if !inGroup.isEmpty { result.append(("\(g.label) · \(inGroup.count)", inGroup)) }
        }
        let customs = matches.filter { ExerciseCatalog.definition(named: $0.name) == nil }
        if !customs.isEmpty { result.append(("Custom · \(customs.count)", customs)) }
        return result
    }
    private var canCreate: Bool {
        let trimmed = search.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !library.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var body: some View {
        List {
            if canCreate {
                Button {
                    context.insert(ExerciseEntity(search.trimmingCharacters(in: .whitespaces), summary: "Custom exercise", tips: ["Move with control"], isCustom: true))
                    try? context.save(); search = ""
                } label: { Label("Add “\(search.trimmingCharacters(in: .whitespaces))” as a custom exercise", systemImage: "plus.circle") }
            }
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.rows) { entity in
                        NavigationLink { ExerciseDetail(name: entity.name) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entity.name)
                                Text(ExerciseCatalog.definition(named: entity.name)?.subtitle ?? "Custom").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if entity.isCustom {
                                Button(role: .destructive) { context.delete(entity); try? context.save() } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            if matches.isEmpty && !canCreate { ContentUnavailableView.search(text: search) }
        }
        .searchable(text: $search, prompt: "Search \(library.count) exercises")
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Muscle group", selection: $group) {
                        Text("All muscle groups").tag(MuscleGroup?.none)
                        ForEach(MuscleGroup.allCases, id: \.self) { Text($0.label).tag(MuscleGroup?.some($0)) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        Text("Any equipment").tag(Equipment?.none)
                        ForEach(Equipment.allCases, id: \.self) { Text($0.label).tag(Equipment?.some($0)) }
                    }
                } label: {
                    Label("Filter", systemImage: group == nil && equipment == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
    }
}

/// The exercise library, grouped by muscle group with an equipment filter.
/// Muscle group and equipment come from `ExerciseCatalog` by name; the stored
/// entity only carries name, summary, and tips.
struct ExercisePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ExerciseEntity.name) private var library: [ExerciseEntity]
    var exclude: Set<String> = []
    let onPick: (String) -> Void
    @State private var search = ""
    @State private var group: MuscleGroup?
    @State private var equipment: Equipment?

    private struct Row: Identifiable {
        let entity: ExerciseEntity
        let definition: ExerciseDefinition?
        var id: String { entity.name }
        var subtitle: String { definition?.subtitle ?? "Custom" }
    }

    private var rows: [Row] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return library.compactMap { entity -> Row? in
            guard !exclude.contains(entity.name) else { return nil }
            let definition = ExerciseCatalog.definition(named: entity.name)
            if let group, definition?.muscleGroup != group { return nil }
            if let equipment, definition?.equipment != equipment { return nil }
            if !q.isEmpty {
                let haystack = [entity.name, definition?.muscleGroup.label ?? "", definition?.equipment.label ?? ""].joined(separator: " ")
                guard haystack.localizedCaseInsensitiveContains(q) else { return nil }
            }
            return Row(entity: entity, definition: definition)
        }
    }
    /// Grouped in catalog order, customs last.
    private var sections: [(title: String, rows: [Row])] {
        var result: [(String, [Row])] = []
        for g in MuscleGroup.allCases {
            let inGroup = rows.filter { $0.definition?.muscleGroup == g }
            if !inGroup.isEmpty { result.append((g.label, inGroup)) }
        }
        let customs = rows.filter { $0.definition == nil }
        if !customs.isEmpty { result.append(("Custom", customs)) }
        return result
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
                ForEach(sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.rows) { row in
                            Button { onPick(row.entity.name) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.entity.name)
                                    Text(row.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if rows.isEmpty && !canCreate {
                    ContentUnavailableView.search(text: search)
                }
            }
            .searchable(text: $search, prompt: "Search \(library.count) exercises")
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Muscle group", selection: $group) {
                            Text("All muscle groups").tag(MuscleGroup?.none)
                            ForEach(MuscleGroup.allCases, id: \.self) { Text($0.label).tag(MuscleGroup?.some($0)) }
                        }
                        Picker("Equipment", selection: $equipment) {
                            Text("Any equipment").tag(Equipment?.none)
                            ForEach(Equipment.allCases, id: \.self) { Text($0.label).tag(Equipment?.some($0)) }
                        }
                    } label: {
                        Label("Filter", systemImage: group == nil && equipment == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
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
    @Query private var profiles: [AppProfile]
    @Query(sort: \WorkoutEntity.date, order: .reverse) private var workouts: [WorkoutEntity]
    let name: String

    private struct HistoryPoint: Identifiable {
        let id: PersistentIdentifier
        let date: Date
        let bestKG: Double
        let bestReps: Int
        let sets: Int
        let volumeKG: Double
    }

    private var units: UnitSystem { profiles.first?.units ?? .imperial }

    /// Newest first. "Best" is the set with the highest estimated 1RM.
    private var history: [HistoryPoint] {
        var points: [HistoryPoint] = []
        for workout in workouts where workout.completed {
            guard let exercise = workout.exercises.first(where: { $0.name == name }) else { continue }
            let working = exercise.sets.filter { $0.reps > 0 && !$0.isWarmup }
            guard let best = working.max(by: { a, b in
                Volume.estimatedOneRepMax(weightKG: a.weightKG, reps: a.reps) < Volume.estimatedOneRepMax(weightKG: b.weightKG, reps: b.reps)
            }) else { continue }
            let performed: [(weightKG: Double, reps: Int)] = working.map { (weightKG: $0.weightKG, reps: $0.reps) }
            points.append(HistoryPoint(id: workout.persistentModelID, date: workout.date, bestKG: best.weightKG, bestReps: best.reps,
                                       sets: working.count, volumeKG: Volume.total(sets: performed)))
        }
        return points
    }

    var body: some View {
        let exercise = exercises.first { $0.name == name }
        let definition = ExerciseCatalog.definition(named: name)
        let history = self.history
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.sage.opacity(0.15))
                    .frame(height: 140)
                    .overlay { Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 55)).foregroundStyle(.sage) }
                if let definition {
                    HStack(spacing: 8) {
                        Text(definition.muscleGroup.label)
                        Text("·").foregroundStyle(.secondary)
                        Text(definition.equipment.label)
                    }
                    .font(.caption.weight(.semibold)).textCase(.uppercase).tracking(1).foregroundStyle(.secondary)
                }
                Text(exercise?.summary ?? "Custom exercise").font(.title3)

                if !history.isEmpty {
                    Text("Your history").font(.headline)
                    if history.count >= 2 { chart(history) }
                    ForEach(history.prefix(8)) { point in
                        HStack {
                            Text(point.date.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(weight(point.bestKG)) × \(point.bestReps) · \(point.sets) sets · \(weight(point.volumeKG)) total")
                                .font(.subheadline)
                        }
                    }
                    if let best = history.max(by: { $0.bestKG < $1.bestKG }) {
                        Label("Best: \(weight(best.bestKG)) × \(best.bestReps) on \(best.date.formatted(date: .abbreviated, time: .omitted))", systemImage: "trophy")
                            .font(.subheadline).foregroundStyle(.sage)
                    }
                }

                Text("Form notes").font(.headline)
                ForEach((exercise?.tips ?? "Move with control").components(separatedBy: "\n"), id: \.self) { tip in
                    Label(tip, systemImage: "checkmark")
                }
            }
            .padding()
        }
        .navigationTitle(name)
    }

    private func weight(_ kg: Double) -> String {
        units.displayWeight(kilograms: kg).formatted(.number.precision(.fractionLength(0...1))) + " " + units.weightUnit
    }

    private func chart(_ points: [HistoryPoint]) -> some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Best set", units.displayWeight(kilograms: point.bestKG)))
                    .foregroundStyle(.sage)
                PointMark(x: .value("Date", point.date), y: .value("Best set", units.displayWeight(kilograms: point.bestKG)))
                    .foregroundStyle(.sage)
                    .symbolSize(24)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxisLabel(units.weightUnit)
        .frame(height: 160)
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
    private var pace: String? {
        Pace.format(minutes: workout.durationMinutes, distance: units.displayDistance(kilometers: workout.distanceKM ?? 0), unit: units.distanceUnit)
    }

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
                if let pace { LabeledContent("Pace", value: pace).foregroundStyle(.secondary) }
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
                    Button("Save & complete") { workout.completed = true; try? context.save(); Haptics.success() }
                        .buttonStyle(.borderedProminent)
                        .disabled(workout.durationMinutes <= 0)
                }
            } footer: {
                if !workout.completed && workout.durationMinutes <= 0 { Text("Enter the duration to complete this session.") }
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
                    LabeledContent("Rep range") {
                        TextField("8–12", text: Bindable(template).repRange).multilineTextAlignment(.trailing)
                    }
                    NavigationLink("Exercises (\(template.exerciseNames.count))") { TemplateExercisesView(template: template) }
                    Button("Delete template", role: .destructive) { context.delete(template); try? context.save() }
                } header: { Text(template.name) }
            }
        }
        .navigationTitle("Weekly Schedule")
        .toolbar {
            Button("Done") {
                try? context.save()
                // Scheduled days may have changed; keep the reminders in step.
                let scheduled = templates
                Task { await ReminderSettings.refreshWorkoutReminders(templates: scheduled) }
                dismiss()
            }
        }
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
