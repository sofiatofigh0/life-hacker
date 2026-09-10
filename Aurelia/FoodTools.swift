import SwiftUI
import SwiftData

// MARK: - Quick add

/// Log calories and macros without a food — for a restaurant meal or a label
/// you don't want to save. MyFitnessPal's most-used "escape hatch".
struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let date: Date
    var onDone: () -> Void
    @State private var name = ""
    @State private var meal: Meal
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?

    init(date: Date, onDone: @escaping () -> Void) {
        self.date = date; self.onDone = onDone
        _meal = State(initialValue: Meal.inferred(hour: Calendar.current.component(.hour, from: date)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Description (optional)", text: $name)
                    Picker("Meal", selection: $meal) { ForEach(Meal.allCases, id: \.self) { Text($0.label).tag($0) } }
                }
                Section("Nutrition") {
                    LabeledContent("Calories") { DecimalField(placeholder: "0", value: $calories, fractionDigits: 0) }
                    LabeledContent("Protein (g)") { DecimalField(placeholder: "0", value: $protein, fractionDigits: 0) }
                    LabeledContent("Carbs (g)") { DecimalField(placeholder: "optional", value: $carbs, fractionDigits: 0) }
                    LabeledContent("Fat (g)") { DecimalField(placeholder: "optional", value: $fat, fractionDigits: 0) }
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        let label = name.trimmingCharacters(in: .whitespaces)
                        context.insert(FoodLogEntity(date: date, mealRaw: meal.rawValue, foodName: label.isEmpty ? "Quick add" : label,
                                                     grams: 0, calories: calories ?? 0, protein: protein ?? 0, carbs: carbs ?? 0, fat: fat ?? 0))
                        try? context.save()
                        Haptics.success()
                        onDone()
                    }
                    .disabled((calories ?? 0) <= 0 && (protein ?? 0) <= 0)
                }
            }
        }
    }
}

// MARK: - Edit a logged entry

/// Change the amount or meal of something already logged. Macros scale with
/// the amount from the ratio they were logged at, so an entry keeps the
/// nutrition values it had even if the food was edited since.
struct FoodEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let entry: FoodLogEntity
    @State private var grams: Double?
    @State private var meal: Meal
    @State private var confirmDelete = false

    private let original: (grams: Double, calories: Double, protein: Double, carbs: Double, fat: Double)

    init(entry: FoodLogEntity) {
        self.entry = entry
        original = (entry.grams, entry.calories, entry.protein, entry.carbs, entry.fat)
        _grams = State(initialValue: entry.grams > 0 ? entry.grams : nil)
        _meal = State(initialValue: Meal(rawValue: entry.mealRaw) ?? .snacks)
    }

    private var isQuickAdd: Bool { original.grams <= 0 }
    private var scale: Double { isQuickAdd ? 1 : (grams ?? 0) / original.grams }

    var body: some View {
        NavigationStack {
            Form {
                Section(entry.foodName) {
                    if !isQuickAdd {
                        LabeledContent("Amount (g)") { DecimalField(placeholder: "\(Int(original.grams))", value: $grams, fractionDigits: 0) }
                    }
                    Picker("Meal", selection: $meal) { ForEach(Meal.allCases, id: \.self) { Text($0.label).tag($0) } }
                }
                Section("This amount") {
                    LabeledContent("Calories", value: "\(Int(original.calories * scale)) kcal")
                    LabeledContent("Protein", value: "\(Int(original.protein * scale)) g")
                    LabeledContent("Carbs", value: "\(Int(original.carbs * scale)) g")
                    LabeledContent("Fat", value: "\(Int(original.fat * scale)) g")
                }
                Section {
                    Button("Remove from log", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !isQuickAdd, let grams, grams > 0 {
                            entry.grams = grams
                            entry.calories = original.calories * scale
                            entry.protein = original.protein * scale
                            entry.carbs = original.carbs * scale
                            entry.fat = original.fat * scale
                        }
                        entry.mealRaw = meal.rawValue
                        try? context.save()
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(!isQuickAdd && (grams ?? 0) <= 0)
                }
            }
            .confirmationDialog("Remove this entry?", isPresented: $confirmDelete) {
                Button("Remove", role: .destructive) { context.delete(entry); try? context.save(); dismiss() }
            }
        }
    }
}

// MARK: - Saved meals

/// `SavedMealEntity` stores `[FoodSnapshot]` as JSON. The snapshot's
/// `servingGrams` carries the logged amount, so a saved meal is a list of
/// (food, grams) that can be re-logged in one tap.
enum SavedMeals {
    static func items(of meal: SavedMealEntity) -> [FoodSnapshot] {
        (try? JSONDecoder().decode([FoodSnapshot].self, from: meal.itemData)) ?? []
    }

    static func snapshot(from entry: FoodLogEntity) -> FoodSnapshot? {
        guard entry.grams > 0 else { return nil }
        let per100 = Macro(calories: entry.calories / entry.grams * 100, protein: entry.protein / entry.grams * 100,
                           carbs: entry.carbs / entry.grams * 100, fat: entry.fat / entry.grams * 100)
        return FoodSnapshot(name: entry.foodName, nutrientsPer100Grams: per100, servingGrams: entry.grams)
    }

    static func totals(of meal: SavedMealEntity) -> Macro {
        items(of: meal).reduce(Macro()) { $0 + $1.nutrients(grams: $1.servingGrams ?? 0) }
    }

    /// Logs every item of a saved meal into `meal` on `date`.
    @MainActor
    static func log(_ saved: SavedMealEntity, into meal: Meal, on date: Date, context: ModelContext) {
        for item in items(of: saved) {
            let grams = item.servingGrams ?? 0
            let m = item.nutrients(grams: grams)
            context.insert(FoodLogEntity(date: date, mealRaw: meal.rawValue, foodName: item.name, grams: grams,
                                         calories: m.calories, protein: m.protein, carbs: m.carbs, fat: m.fat))
        }
        try? context.save()
    }

    /// Copies one day's entries onto another, preserving meal and time of day.
    @MainActor
    static func copy(entries: [FoodLogEntity], to day: Date, context: ModelContext, calendar: Calendar = .current) {
        for entry in entries {
            let hour = calendar.component(.hour, from: entry.date)
            let minute = calendar.component(.minute, from: entry.date)
            let stamp = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
            context.insert(FoodLogEntity(date: stamp, mealRaw: entry.mealRaw, foodName: entry.foodName, grams: entry.grams,
                                         calories: entry.calories, protein: entry.protein, carbs: entry.carbs, fat: entry.fat))
        }
        try? context.save()
    }
}

/// Rows for Add Food: tap to log the whole meal, swipe to delete.
struct SavedMealsSection: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedMealEntity.name) private var saved: [SavedMealEntity]
    let date: Date
    var onLogged: () -> Void

    var body: some View {
        if !saved.isEmpty {
            Section("Saved meals") {
                ForEach(saved) { meal in
                    let totals = SavedMeals.totals(of: meal)
                    Button {
                        SavedMeals.log(meal, into: Meal.inferred(hour: Calendar.current.component(.hour, from: date)), on: date, context: context)
                        Haptics.success()
                        onLogged()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.name)
                                Text("\(SavedMeals.items(of: meal).count) items · \(Int(totals.calories)) kcal · \(Int(totals.protein)) g protein")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(.sage)
                        }
                    }
                }
                .onDelete { offsets in offsets.map { saved[$0] }.forEach(context.delete); try? context.save() }
            }
        }
    }
}
