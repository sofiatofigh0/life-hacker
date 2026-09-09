import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let profile: AppProfile
    @Query(sort: \SupplementEntity.order) private var supplements: [SupplementEntity]

    @State private var sync = HealthSync.shared
    @State private var demo = DemoModeController.shared
    @State private var newSupplement = ""
    @State private var reminderOn = false
    @State private var reminderNote: String?
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var cleanupReport: DemoCleanup.Report?
    @State private var cleanupResult: String?

    private var units: UnitSystem { profile.units }

    var body: some View {
        Form {
            goalSection
            profileSection
            supplementsSection
            healthSection
            remindersSection
            dataSection
            demoSection
            Section("Privacy") {
                Text("Health data and progress photos remain on this device. Only food search text is sent to nutrition providers.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Settings")
        .toolbar { Button("Done") { try? context.save(); dismiss() } }
        .sheet(item: $exportFile) { file in ShareSheet(url: file.url) }
        .task { reminderOn = await NotificationService.isWeeklyPhotoScheduled() }
        .alert("Old demo data", isPresented: Binding(get: { cleanupReport != nil }, set: { if !$0 { cleanupReport = nil } }),
               presenting: cleanupReport) { report in
            if report.total > 0 {
                Button("Remove \(report.total) rows", role: .destructive) { removeLegacyDemo() }
                Button("Keep", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { report in
            Text(report.total > 0
                 ? "Found \(report.summary) matching the fixtures an earlier build wrote into your real records. Remove them?"
                 : "No demo fixtures found in your records.")
        }
    }

    // MARK: Sections

    private var goalSection: some View {
        Section {
            Picker("Goal", selection: Bindable(profile).goal) {
                ForEach(GoalMode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            LabeledContent("Calorie target") { DecimalField(placeholder: "1800", value: Bindable(profile).calorieTarget.zeroAsNil, integer: true) }
            LabeledContent("Protein target (g)") { DecimalField(placeholder: "120", value: Bindable(profile).proteinTarget.zeroAsNil, integer: true) }
            LabeledContent("Step target") { DecimalField(placeholder: "10000", value: Bindable(profile).stepTarget.zeroAsNil, integer: true) }
            LabeledContent("Water target (\(units.waterUnit))") {
                DecimalField(placeholder: units.isMetric ? "2000" : "64", value: waterTargetBinding, integer: true)
            }
            Button("Recalculate calories & protein") {
                let r = GoalCalculator.recommend(age: profile.age, sex: profile.sex, heightCM: profile.heightCM,
                                                 weightKG: profile.currentKG, activity: profile.activity, mode: profile.goal)
                profile.calorieTarget = r.calories
                profile.proteinTarget = r.proteinGrams
            }
        } header: { Text("Daily targets") } footer: {
            Text("Recalculate uses your current weight, height, age, activity, and goal. Activity never adds calories back.")
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            Picker("Units", selection: Bindable(profile).units) {
                Text("Imperial (lb, in)").tag(UnitSystem.imperial)
                Text("Metric (kg, cm)").tag(UnitSystem.metric)
            }
            TextField("Name", text: Bindable(profile).name)
            Stepper("Age: \(profile.age)", value: Bindable(profile).age, in: 16...100)
            Picker("Sex", selection: Bindable(profile).sex) {
                ForEach(Sex.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            LabeledContent("Height (\(units.heightUnit))") { DecimalField(placeholder: "", value: heightBinding) }
            LabeledContent("Goal weight (\(units.weightUnit))") { DecimalField(placeholder: "", value: goalWeightBinding) }
            Picker("Activity", selection: Bindable(profile).activity) {
                ForEach(ActivityLevel.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            LabeledContent("Current weight", value: units.formatWeight(kilograms: profile.currentKG))
                .foregroundStyle(.secondary)
        }
    }

    private var supplementsSection: some View {
        Section("Supplements") {
            ForEach(supplements) { Text($0.name) }
                .onDelete { offsets in
                    offsets.map { supplements[$0] }.forEach(context.delete)
                    try? context.save()
                }
            HStack {
                TextField("Add supplement", text: $newSupplement)
                Button("Add") {
                    let name = newSupplement.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    context.insert(SupplementEntity(name: name, order: (supplements.map(\.order).max() ?? -1) + 1))
                    try? context.save()
                    newSupplement = ""
                }
                .disabled(newSupplement.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var healthSection: some View {
        Section {
            if !sync.isAvailable {
                Text("Apple Health is not available on this device.").foregroundStyle(.secondary)
            } else if demo.isEnabled {
                Text("Health sync is paused while demo mode is on.").foregroundStyle(.secondary)
            } else {
                Button {
                    Task { await sync.requestAccessAndSync(context: context) }
                } label: {
                    HStack {
                        Label(sync.lastSynced == nil ? "Connect Apple Health" : "Refresh now", systemImage: "heart.text.square")
                        if sync.isSyncing { Spacer(); SwiftUI.ProgressView() }
                    }
                }
                .disabled(sync.isSyncing)
                if let error = sync.lastError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                } else if let last = sync.lastSynced {
                    Text("Last synced \(last.formatted(date: .omitted, time: .shortened)). Runs automatically when the app opens.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("Reads steps, active energy, heart rate, and weight. Weights you log here are written back to Health.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        } header: { Text("Apple Health") } footer: {
            if sync.isAvailable && !demo.isEnabled {
                Text("If steps stay at zero after connecting, open the Health app → Sharing → Apps → Aurelia and turn on the categories.")
            }
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            Toggle("Weekly photo reminder (Sunday 9 am)", isOn: $reminderOn)
                .onChange(of: reminderOn) { _, on in
                    Task {
                        if on {
                            let granted = (try? await NotificationService.request()) ?? false
                            if granted { try? await NotificationService.scheduleWeeklyPhotos(); reminderNote = nil }
                            else { reminderOn = false; reminderNote = "Notifications are off for Aurelia in iOS Settings." }
                        } else {
                            NotificationService.cancelWeeklyPhotos()
                        }
                    }
                }
            if let reminderNote { Text(reminderNote).font(.footnote).foregroundStyle(.secondary) }
        }
    }

    private var dataSection: some View {
        Section {
            Button { export() } label: { Label("Export all data (JSON)", systemImage: "square.and.arrow.up") }
            if let exportError { Text(exportError).font(.footnote).foregroundStyle(.red) }
            if !demo.isEnabled {
                Button { cleanupReport = DemoCleanup.scan(context: context) } label: {
                    Label("Check for old demo data", systemImage: "magnifyingglass")
                }
                if let cleanupResult { Text(cleanupResult).font(.footnote).foregroundStyle(.secondary) }
            }
        } header: { Text("Your data") } footer: {
            Text("Export writes every log to a JSON file you can save to Files, AirDrop, or email. Progress photos are listed by filename, not embedded. \"Check for old demo data\" finds rows an earlier build's demo mode wrote into your real records.")
        }
    }

    private var demoSection: some View {
        Section {
            Toggle("Demo mode", isOn: demo.enabledBinding)
            if demo.isEnabled {
                Button("Regenerate demo data") { demo.reset() }
            }
        } header: { Text("Portfolio") } footer: {
            Text("Demo mode shows a generated five-week history in a separate, throwaway store. Your own records are never modified by it.")
        }
    }

    // MARK: Bindings

    private var heightBinding: Binding<Double?> {
        Bindable(profile).heightCM.zeroAsNil.converted(toDisplay: { units.displayHeight(centimeters: $0) },
                                                       fromDisplay: { units.centimeters(fromDisplayHeight: $0) })
    }
    private var goalWeightBinding: Binding<Double?> {
        Bindable(profile).goalKG.zeroAsNil.converted(toDisplay: { units.displayWeight(kilograms: $0) },
                                                     fromDisplay: { units.kilograms(fromDisplayWeight: $0) })
    }
    private var waterTargetBinding: Binding<Double?> {
        Bindable(profile).waterTargetLiters.zeroAsNil.converted(toDisplay: { units.displayWater(liters: $0) },
                                                                fromDisplay: { units.liters(fromDisplayWater: $0) })
    }

    // MARK: Actions

    private func export() {
        exportError = nil
        do {
            try context.save()
            let result = try ExportService.writeFile(context: context)
            exportFile = ExportFile(url: result.url, records: result.records)
            Haptics.success()
        } catch {
            exportError = "Export failed: \(error.localizedDescription)"
        }
    }

    private func removeLegacyDemo() {
        do {
            let report = try DemoCleanup.remove(context: context)
            cleanupResult = report.total == 0 ? "Nothing to remove." : "Removed \(report.summary)."
            Haptics.success()
        } catch {
            cleanupResult = "Could not remove demo data: \(error.localizedDescription)"
        }
    }
}
