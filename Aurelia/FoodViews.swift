import SwiftUI
import SwiftData
import AVFoundation
import UIKit

// MARK: - Day view

struct FoodView: View {
    @Environment(\.modelContext) private var context
    let profile: AppProfile
    /// True when pushed from Today rather than shown as the tab root, so the
    /// system bar (and its back button) stays visible.
    var embedded = false

    @State private var date = Date.now
    @State private var add = false
    @State private var library = false
    @State private var editing: FoodLogEntity?
    @State private var savingMeal: Meal?
    @State private var mealName = ""
    @Query(sort: \FoodLogEntity.date) private var logs: [FoodLogEntity]

    private var calendar: Calendar { .current }
    private var dayLogs: [FoodLogEntity] { logs.filter { calendar.isDate($0.date, inSameDayAs: date) } }
    private var yesterdayLogs: [FoodLogEntity] {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return [] }
        return logs.filter { calendar.isDate($0.date, inSameDayAs: yesterday) }
    }
    private var total: Macro {
        dayLogs.reduce(Macro()) { $0 + .init(calories: $1.calories, protein: $1.protein, carbs: $1.carbs, fat: $1.fat) }
    }
    private var isToday: Bool { calendar.isDateInToday(date) }

    var body: some View {
        TabScreen(eyebrow: "Nourishment", title: isToday ? "Today" : date.formatted(.dateTime.weekday(.abbreviated).month(.wide).day()),
                  hidesNavigationBar: !embedded) {
            HStack(spacing: 8) {
                HeaderButton(systemImage: "books.vertical", label: "Food library") { library = true }
                HeaderButton(systemImage: "plus", label: "Add food") { add = true }
            }
        } content: {
            dayPicker
            totalsCard
            if dayLogs.isEmpty && !yesterdayLogs.isEmpty {
                Button {
                    SavedMeals.copy(entries: yesterdayLogs, to: date, context: context)
                    Haptics.success()
                } label: {
                    Label("Copy yesterday's \(yesterdayLogs.count) entries", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            ForEach(Meal.allCases, id: \.self) { meal in mealCard(meal) }
        }
        .sheet(isPresented: $add) { NavigationStack { AddFoodView(date: logDate) { add = false } } }
        .sheet(isPresented: $library) { NavigationStack { FoodLibraryView() } }
        .sheet(item: $editing) { entry in FoodEntryEditor(entry: entry) }
        .alert("Save as a meal", isPresented: Binding(get: { savingMeal != nil }, set: { if !$0 { savingMeal = nil } }),
               presenting: savingMeal) { meal in
            TextField("Meal name", text: $mealName)
            Button("Save") { saveMeal(meal) }
            Button("Cancel", role: .cancel) {}
        } message: { meal in
            Text("Everything logged under \(meal.label) today becomes a one-tap meal in Add Food.")
        }
    }

    /// Foods added to a past day are stamped at noon so they sort sensibly.
    private var logDate: Date {
        isToday ? .now : calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    private var dayPicker: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            if !isToday { Button("Today") { date = .now } }
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }.disabled(isToday)
        }
        .font(.body.weight(.semibold))
    }

    private func shift(_ days: Int) {
        if let next = calendar.date(byAdding: .day, value: days, to: date) { date = min(next, .now) }
    }

    // MARK: Totals

    private var calorieTarget: Double { Double(profile.calorieTarget) }
    private var proteinTarget: Double { Double(profile.proteinTarget) }
    private var calorieRatio: Double { calorieTarget > 0 ? total.calories / calorieTarget : 0 }

    private var totalsCard: some View {
        WellnessCard {
            HStack(alignment: .top) {
                metric("Calories", value: total.calories, target: calorieTarget, unit: "kcal", over: calorieRatio > 1.1)
                Divider()
                metric("Protein", value: total.protein, target: proteinTarget, unit: "g", over: false)
            }
            Divider().padding(.vertical, 8)
            HStack {
                Text("Carbs  \(Int(total.carbs)) g"); Spacer(); Text("Fat  \(Int(total.fat)) g")
            }
            .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func metric(_ title: String, value: Double, target: Double, unit: String, over: Bool) -> some View {
        let remaining = Int(target - value)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(Int(value).formatted()).font(.system(.title, design: .serif, weight: .semibold))
            Text(remaining >= 0 ? "\(remaining.formatted()) \(unit) left of \(Int(target).formatted())"
                 : "\((-remaining).formatted()) \(unit) over \(Int(target).formatted())")
                .font(.caption).foregroundStyle(over ? Color.orange : Color.secondary)
            ProgressBar(value: target > 0 ? value / target : 0, tint: over ? .orange : .sage)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Meals

    private func mealCard(_ meal: Meal) -> some View {
        let entries = dayLogs.filter { $0.mealRaw == meal.rawValue }
        let calories = Int(entries.map(\.calories).reduce(0, +))
        let protein = Int(entries.map(\.protein).reduce(0, +))
        return WellnessCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(meal.label).font(.headline)
                    Spacer()
                    if !entries.isEmpty {
                        Text("\(calories.formatted()) kcal · \(protein) g").font(.subheadline).foregroundStyle(.secondary)
                        Menu {
                            Button { mealName = ""; savingMeal = meal } label: { Label("Save as meal…", systemImage: "bookmark") }
                        } label: {
                            Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("\(meal.label) options")
                    }
                }
                if entries.isEmpty {
                    Text("Nothing logged").foregroundStyle(.secondary).font(.subheadline)
                } else {
                    ForEach(entries) { entry in entryRow(entry) }
                }
            }
        }
    }

    private func entryRow(_ entry: FoodLogEntity) -> some View {
        HStack {
            Button { editing = entry } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.foodName).foregroundStyle(.primary)
                        Text(entry.grams > 0 ? "\(Int(entry.grams)) g · \(Int(entry.protein)) g protein" : "Quick add · \(Int(entry.protein)) g protein")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(entry.calories)) kcal").font(.subheadline).foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // A ScrollView has no swipe actions; the original's delete was unreachable.
            Button { context.delete(entry); try? context.save() } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(entry.foodName)")
        }
    }

    private func saveMeal(_ meal: Meal) {
        let name = mealName.trimmingCharacters(in: .whitespaces)
        let entries = dayLogs.filter { $0.mealRaw == meal.rawValue }
        let items = entries.compactMap(SavedMeals.snapshot(from:))
        guard !items.isEmpty else { return }
        context.insert(SavedMealEntity(name: name.isEmpty ? "\(meal.label) · \(date.formatted(date: .abbreviated, time: .omitted))" : name, items: items))
        try? context.save()
        Haptics.success()
    }
}

// MARK: - Add food

struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntity.lastUsed, order: .reverse) private var cached: [FoodEntity]
    let date: Date
    /// Called once a food has been logged, so the presenting screen can close the sheet.
    var onDone: () -> Void

    @State private var query = ""
    @State private var results: [FoodSnapshot] = []
    @State private var loading = false
    @State private var error: String?
    @State private var scanner = false
    @State private var manual = false
    @State private var quick = false
    @State private var manualPrefill: FoodSnapshot?
    @State private var selected: FoodEntity?

    private let service = RemoteNutritionService(proxyURL: Self.configuredProxyURL)
    private var searchAvailable: Bool { Self.configuredProxyURL != nil }

    private var favorites: [FoodEntity] { cached.filter(\.favorite).sorted { $0.name < $1.name } }
    private var recent: [FoodEntity] { Array(cached.filter { $0.lastUsed != nil }.prefix(8)) }
    private var frequent: [FoodEntity] { Array(cached.filter { $0.useCount > 0 }.sorted { $0.useCount > $1.useCount }.prefix(8)) }
    private var library: [FoodEntity] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return cached.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.brand.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField(searchAvailable ? "Search foods" : "Search your foods", text: $query)
                        .submitLabel(.search)
                        .onSubmit { search() }
                    if loading { SwiftUI.ProgressView() }
                }
                Button { scanner = true } label: { Label("Scan barcode", systemImage: "barcode.viewfinder") }
                Button { quick = true } label: { Label("Quick add calories", systemImage: "bolt") }
                Button { manual = true } label: { Label("Create food manually", systemImage: "square.and.pencil") }
                if let error { Text(error).font(.footnote).foregroundStyle(.secondary) }
            }
            if !library.isEmpty {
                Section("Your foods") { ForEach(library) { foodRow($0) } }
            }
            if !results.isEmpty {
                Section("Search results") {
                    ForEach(results) { result in
                        Button { selected = cache(result) } label: {
                            VStack(alignment: .leading) {
                                Text(result.name)
                                Text([result.brand, "\(Int(result.nutrientsPer100Grams.calories)) kcal / 100 g"].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if query.isEmpty {
                SavedMealsSection(date: date, onLogged: onDone)
                if !favorites.isEmpty { Section("Favorites") { ForEach(favorites) { foodRow($0) } } }
                if !recent.isEmpty { Section("Recent") { ForEach(recent) { foodRow($0) } } }
                if !frequent.isEmpty { Section("Frequent") { ForEach(frequent) { foodRow($0) } } }
                Section {
                    NavigationLink { StaplesBrowser { selected = $0 } } label: { Label("Browse staples by category", systemImage: "leaf") }
                    NavigationLink { FoodLibraryView(onPick: { selected = $0 }) } label: { Label("All saved foods", systemImage: "books.vertical") }
                } footer: {
                    Text("Type a name to search your saved foods and the built-in staples\(searchAvailable ? ", then press Search for online results" : ""). Packaged products: scan the barcode. Restaurant meal or a label you won't reuse: Quick add.")
                }
            }
        }
        .navigationTitle("Add Food")
        .toolbar { Button("Cancel") { dismiss() } }
        .navigationDestination(item: $selected) { food in FoodAmountView(food: food, date: date, onDone: onDone) }
        .sheet(isPresented: $scanner) { BarcodeScannerView { code in scanner = false; lookup(code) } }
        .sheet(isPresented: $quick) { QuickAddView(date: date) { quick = false; onDone() } }
        .sheet(isPresented: $manual) {
            ManualFoodView(prefill: manualPrefill) { food in manual = false; manualPrefill = nil; selected = food }
        }
    }

    private func foodRow(_ food: FoodEntity) -> some View {
        Button { selected = food } label: {
            VStack(alignment: .leading) {
                Text(food.name)
                Text([food.brand.isEmpty ? nil : food.brand, "\(Int(food.calories100)) kcal / 100 g"].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Reuses an existing cached food (by barcode, then by name + brand) instead
    /// of inserting a duplicate on every tap.
    private func cache(_ snapshot: FoodSnapshot) -> FoodEntity {
        if let code = snapshot.barcode, let match = cached.first(where: { $0.barcode == code }) { return match }
        let brand = snapshot.brand ?? ""
        if let match = cached.first(where: {
            $0.name.caseInsensitiveCompare(snapshot.name) == .orderedSame && $0.brand.caseInsensitiveCompare(brand) == .orderedSame
        }) { return match }
        let entity = FoodEntity(name: snapshot.name, brand: brand, barcode: snapshot.barcode,
                                calories100: snapshot.nutrientsPer100Grams.calories, protein100: snapshot.nutrientsPer100Grams.protein,
                                carbs100: snapshot.nutrientsPer100Grams.carbs, fat100: snapshot.nutrientsPer100Grams.fat,
                                servingGrams: snapshot.servingGrams ?? 100)
        context.insert(entity)
        try? context.save()
        return entity
    }

    private static var configuredProxyURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "NutritionProxyURL") as? String,
              !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return URL(string: raw)
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        guard searchAvailable else {
            error = library.isEmpty ? "No matching foods saved yet. Online search is not configured." : nil
            return
        }
        loading = true; error = nil
        Task {
            do {
                results = try await service.search(q)
                if results.isEmpty { error = "No foods found online. Create one manually." }
            } catch {
                self.error = "Online search is unavailable. Your saved foods still work."
            }
            loading = false
        }
    }

    private func lookup(_ code: String) {
        if let match = cached.first(where: { $0.barcode == code }) { Haptics.success(); selected = match; return }
        loading = true; error = nil
        Task {
            do {
                if let result = try await service.barcodeLookup(code) {
                    if result.hasNutritionData {
                        Haptics.success()
                        selected = cache(result.snapshot)
                    } else {
                        // The product exists but nobody has entered its label yet.
                        Haptics.warning()
                        error = "Found “\(result.snapshot.name)” but Open Food Facts has no nutrition facts for it. Enter them from the label."
                        manualPrefill = result.snapshot
                        manual = true
                    }
                } else {
                    Haptics.warning()
                    error = "Barcode \(code) isn't in Open Food Facts. Create the food manually."
                    manualPrefill = FoodSnapshot(name: "", barcode: code, nutrientsPer100Grams: Macro())
                    manual = true
                }
            } catch {
                Haptics.warning()
                self.error = "Could not look up that barcode. Check your connection."
            }
            loading = false
        }
    }
}

// MARK: - Amount

struct FoodAmountView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let food: FoodEntity
    let date: Date
    var onDone: () -> Void
    @State private var grams: Double?
    @State private var meal: Meal

    init(food: FoodEntity, date: Date, onDone: @escaping () -> Void) {
        self.food = food; self.date = date; self.onDone = onDone
        _grams = State(initialValue: food.servingGrams > 0 ? food.servingGrams : 100)
        _meal = State(initialValue: Meal.inferred(hour: Calendar.current.component(.hour, from: date)))
    }

    private var scale: Double { (grams ?? 0) / 100 }
    private var canLog: Bool { (grams ?? 0) > 0 }

    var body: some View {
        Form {
            Section(food.name) {
                LabeledContent("Amount (g)") { DecimalField(placeholder: "100", value: $grams, fractionDigits: 0) }
                Picker("Meal", selection: $meal) { ForEach(Meal.allCases, id: \.self) { Text($0.label).tag($0) } }
                if food.servingGrams > 0 && food.servingGrams != 100 {
                    Button("Use one serving (\(Int(food.servingGrams)) g)") { grams = food.servingGrams }
                }
            }
            Section("This amount") {
                LabeledContent("Calories", value: "\(Int(food.calories100 * scale)) kcal")
                LabeledContent("Protein", value: "\(Int(food.protein100 * scale)) g")
                LabeledContent("Carbs", value: "\(Int(food.carbs100 * scale)) g")
                LabeledContent("Fat", value: "\(Int(food.fat100 * scale)) g")
            }
            Section {
                Button("Add to \(meal.label)") { log(); onDone() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canLog)
                // Logging a whole plate is several foods; going back to the
                // search each time is the friction every tracker gets wrong.
                Button("Add & log another") { log(); dismiss() }
                    .disabled(!canLog)
            }
        }
        .navigationTitle("Serving")
    }

    private func log() {
        context.insert(FoodLogEntity(date: date, meal: meal, food: food, grams: grams ?? 0))
        food.useCount += 1
        food.lastUsed = .now
        try? context.save()
        Haptics.success()
    }
}

struct ManualFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var onSaved: (FoodEntity) -> Void
    private let barcode: String?
    @State private var name: String
    @State private var brand: String
    @State private var serving: Double?
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?

    /// `prefill` carries what a barcode lookup did find (name, brand, code,
    /// serving) when it found no nutrition facts, so the user only types the label.
    init(prefill: FoodSnapshot? = nil, onSaved: @escaping (FoodEntity) -> Void) {
        self.onSaved = onSaved
        barcode = prefill?.barcode
        _name = State(initialValue: prefill?.name ?? "")
        _brand = State(initialValue: prefill?.brand ?? "")
        _serving = State(initialValue: prefill?.servingGrams ?? 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                if barcode != nil {
                    Section {
                        Label("Scanned product without nutrition facts on file. Enter the values from the label, per 100 g.", systemImage: "barcode")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    LabeledContent("Serving size (g)") { DecimalField(placeholder: "100", value: $serving, fractionDigits: 0) }
                }
                Section("Per 100 grams") {
                    LabeledContent("Calories") { DecimalField(placeholder: "0", value: $calories, fractionDigits: 0) }
                    LabeledContent("Protein (g)") { DecimalField(placeholder: "0", value: $protein) }
                    LabeledContent("Carbs (g)") { DecimalField(placeholder: "0", value: $carbs) }
                    LabeledContent("Fat (g)") { DecimalField(placeholder: "0", value: $fat) }
                }
            }
            .navigationTitle("Custom Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entity = FoodEntity(name: name.trimmingCharacters(in: .whitespaces), brand: brand.trimmingCharacters(in: .whitespaces),
                                                barcode: barcode, calories100: calories ?? 0, protein100: protein ?? 0,
                                                carbs100: carbs ?? 0, fat100: fat ?? 0, servingGrams: serving ?? 100)
                        context.insert(entity)
                        try? context.save()
                        Haptics.success()
                        onSaved(entity)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Barcode scanner

/// Handles the camera permission the original skipped: without it a denied
/// camera was just a black screen.
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let completion: (String) -> Void
    @State private var status = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            Group {
                switch status {
                case .authorized:
                    BarcodeScannerSheet(completion: completion).ignoresSafeArea()
                case .notDetermined:
                    SwiftUI.ProgressView("Requesting camera access…")
                        .task {
                            _ = await AVCaptureDevice.requestAccess(for: .video)
                            status = AVCaptureDevice.authorizationStatus(for: .video)
                        }
                default:
                    ContentUnavailableView {
                        Label("Camera access is off", systemImage: "camera.fill")
                    } description: {
                        Text("Allow camera access in Settings to scan barcodes. You can still create foods manually.")
                    } actions: {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
        }
    }
}

struct BarcodeScannerSheet: UIViewControllerRepresentable {
    let completion: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.completion = completion
        return controller
    }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var completion: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var delivered = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
        DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { DispatchQueue.global(qos: .userInitiated).async { [session] in session.stopRunning() } }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !delivered, let value = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        delivered = true
        completion?(value)
    }
}
