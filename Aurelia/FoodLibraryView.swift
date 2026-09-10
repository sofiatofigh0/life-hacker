import SwiftUI
import SwiftData

/// Every saved food — staples, scanned products, and custom entries — with
/// search, filters, favorites, editing, and deletion. This is the personal
/// repository the barcode scanner checks before going online.
struct FoodLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntity.name) private var foods: [FoodEntity]
    /// When set, tapping a row hands it back (used from Add Food) instead of opening the editor.
    var onPick: ((FoodEntity) -> Void)? = nil

    @State private var search = ""
    @State private var filter = Filter.all
    @State private var editing: FoodEntity?

    enum Filter: String, CaseIterable {
        case all = "All", favorites = "Favorites", scanned = "Scanned", custom = "Custom", staples = "Staples"
    }

    static func kind(of food: FoodEntity) -> Filter {
        if food.barcode != nil { return .scanned }
        if food.brand.isEmpty, FoodCatalog.definition(named: food.name) != nil { return .staples }
        return .custom
    }

    private var filtered: [FoodEntity] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return foods.filter { food in
            switch filter {
            case .all: break
            case .favorites: guard food.favorite else { return false }
            default: guard Self.kind(of: food) == filter else { return false }
            }
            return q.isEmpty || food.name.localizedCaseInsensitiveContains(q) || food.brand.localizedCaseInsensitiveContains(q)
                || (food.barcode?.contains(q) ?? false)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
            }
            Section {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
                ForEach(filtered) { food in
                    Button {
                        if let onPick { onPick(food) } else { editing = food }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.name).foregroundStyle(.primary)
                                Text(subtitle(food)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if food.favorite { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
                            if onPick == nil { Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.caption) }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button { food.favorite.toggle(); try? context.save(); Haptics.tap() } label: {
                            Label(food.favorite ? "Unfavorite" : "Favorite", systemImage: food.favorite ? "star.slash" : "star")
                        }.tint(.yellow)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { context.delete(food); try? context.save() } label: { Label("Delete", systemImage: "trash") }
                        Button { editing = food } label: { Label("Edit", systemImage: "pencil") }.tint(.sage)
                    }
                }
            } header: {
                Text("\(filtered.count) of \(foods.count)")
            } footer: {
                Text("Swipe right to favorite, left to edit or delete. Deleting a food does not change meals you already logged with it.")
            }
        }
        .searchable(text: $search, prompt: "Name, brand, or barcode")
        .navigationTitle("Food Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onPick == nil {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .sheet(item: $editing) { food in FoodEditorView(food: food) }
    }

    private func subtitle(_ food: FoodEntity) -> String {
        var parts: [String] = []
        if !food.brand.isEmpty { parts.append(food.brand) }
        parts.append("\(Int(food.calories100)) kcal · \(Int(food.protein100)) g protein / 100 g")
        if food.servingGrams > 0 && food.servingGrams != 100 { parts.append("serving \(Int(food.servingGrams)) g") }
        return parts.joined(separator: " · ")
    }
}

/// Edit a saved food in place. Values are per 100 g, matching how logs are computed.
struct FoodEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let food: FoodEntity
    @State private var confirmDelete = false

    private var barcodeBinding: Binding<String> {
        Binding(get: { food.barcode ?? "" }, set: { food.barcode = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: Bindable(food).name)
                    TextField("Brand", text: Bindable(food).brand)
                    TextField("Barcode", text: barcodeBinding).keyboardType(.numberPad)
                    LabeledContent("Serving size (g)") { DecimalField(placeholder: "100", value: Bindable(food).servingGrams.zeroAsNil, fractionDigits: 0) }
                    Toggle("Favorite", isOn: Bindable(food).favorite)
                }
                Section("Per 100 grams") {
                    LabeledContent("Calories") { DecimalField(placeholder: "0", value: Bindable(food).calories100.zeroAsNil, fractionDigits: 0) }
                    LabeledContent("Protein (g)") { DecimalField(placeholder: "0", value: Bindable(food).protein100.zeroAsNil) }
                    LabeledContent("Carbs (g)") { DecimalField(placeholder: "0", value: Bindable(food).carbs100.zeroAsNil) }
                    LabeledContent("Fat (g)") { DecimalField(placeholder: "0", value: Bindable(food).fat100.zeroAsNil) }
                }
                if let staple = FoodCatalog.definition(named: food.name), food.brand.isEmpty {
                    Section {
                        Button("Reset to catalog values") {
                            food.calories100 = staple.per100.calories; food.protein100 = staple.per100.protein
                            food.carbs100 = staple.per100.carbs; food.fat100 = staple.per100.fat
                            food.servingGrams = staple.servingGrams
                        }
                    } footer: { Text("Built-in staple. Typical serving: \(staple.servingLabel).") }
                }
                Section {
                    LabeledContent("Used", value: "\(food.useCount) times")
                    Button("Delete food", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { try? context.save(); dismiss() } } }
            .confirmationDialog("Delete this food?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { context.delete(food); try? context.save(); dismiss() }
            } message: { Text("Meals already logged with it are kept.") }
        }
    }
}

/// Built-in staples grouped by category, for browsing rather than searching.
struct StaplesBrowser: View {
    @Query private var foods: [FoodEntity]
    let onPick: (FoodEntity) -> Void

    private func entity(for definition: FoodDefinition) -> FoodEntity? {
        foods.first { $0.name == definition.name && $0.brand.isEmpty }
    }

    var body: some View {
        List {
            ForEach(FoodCategory.allCases, id: \.self) { category in
                Section(category.label) {
                    ForEach(FoodCatalog.foods(in: category), id: \.name) { definition in
                        if let food = entity(for: definition) {
                            Button { onPick(food) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(definition.name).foregroundStyle(.primary)
                                        Text("\(Int(food.calories100)) kcal · \(Int(food.protein100)) g protein / 100 g · \(definition.servingLabel)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Staples")
        .navigationBarTitleDisplayMode(.inline)
    }
}
