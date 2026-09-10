import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Reminder preferences live in UserDefaults; the scheduled notifications are
/// derived from them plus the templates, so both Settings and the schedule
/// editor can rebuild them.
enum ReminderSettings {
    static let workoutOnKey = "aurelia.workoutReminder"
    static let workoutMinutesKey = "aurelia.workoutReminderMinutes"
    static let dailyOnKey = "aurelia.dailyReminder"
    static let dailyMinutesKey = "aurelia.dailyReminderMinutes"
    static let defaultWorkoutMinutes = 7 * 60 + 30
    static let defaultDailyMinutes = 20 * 60 + 30

    /// Reschedules workout reminders from the current templates if the
    /// reminder is on. Safe to call whenever templates change.
    @MainActor
    static func refreshWorkoutReminders(templates: [TemplateEntity]) async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: workoutOnKey) else { return }
        let minutes = defaults.object(forKey: workoutMinutesKey) as? Int ?? defaultWorkoutMinutes
        let scheduled: [(name: String, weekday: Int)] = templates.filter { $0.weekday > 0 }.map { (name: $0.name, weekday: $0.weekday) }
        try? await NotificationService.scheduleWorkoutReminders(templates: scheduled, hour: minutes / 60, minute: minutes % 60)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let profile: AppProfile
    @Query(sort: \SupplementEntity.order) private var supplements: [SupplementEntity]
    @Query(sort: \TemplateEntity.weekday) private var templates: [TemplateEntity]

    @State private var sync = HealthSync.shared
    @State private var demo = DemoModeController.shared
    @State private var newSupplement = ""
    @State private var photoReminderOn = false
    @State private var reminderNote: String?
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var cleanupReport: DemoCleanup.Report?
    @State private var cleanupResult: String?
    @State private var showImporter = false
    @State private var pendingRestore: AureliaExport?
    @State private var restoreMessage: String?

    @AppStorage(ReminderSettings.workoutOnKey) private var workoutReminderOn = false
    @AppStorage(ReminderSettings.workoutMinutesKey) private var workoutMinutes = ReminderSettings.defaultWorkoutMinutes
    @AppStorage(ReminderSettings.dailyOnKey) private var dailyReminderOn = false
    @AppStorage(ReminderSettings.dailyMinutesKey) private var dailyMinutes = ReminderSettings.defaultDailyMinutes
    @AppStorage("aurelia.restSeconds") private var restSeconds = 90
    @AppStorage("aurelia.autoRest") private var autoRest = true

    private var units: UnitSystem { profile.units }

    var body: some View {
        Form {
            goalSection
            profileSection
            supplementsSection
            trainingSection
            healthSection
            remindersSection
            dataSection
            demoSection
            Section {
                Text("Health data and progress photos remain on this device. Only food search text and barcodes are sent to nutrition providers.")
                    .font(.footnote)
            } header: { Text("Privacy") } footer: {
                Text(versionFooter).padding(.top, 8)
            }
        }
        .navigationTitle("Settings")
        .toolbar { Button("Done") { try? context.save(); dismiss() } }
        .sheet(item: $exportFile) { file in ShareSheet(url: file.url) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do { pendingRestore = try ImportService.preview(url: url) }
                catch { restoreMessage = error.localizedDescription; Haptics.warning() }
            case .failure(let error):
                restoreMessage = error.localizedDescription
            }
        }
        .alert("Replace everything with this backup?",
               isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
               presenting: pendingRestore) { export in
            Button("Replace with \(export.recordCount) records", role: .destructive) { restore(export) }
            Button("Cancel", role: .cancel) {}
        } message: { export in
            Text("Backup from \(export.exportedAt.formatted(date: .abbreviated, time: .shortened)). Everything currently in the app will be removed first. Export a copy of the current data before you do this if you might want it back.")
        }
        .task { photoReminderOn = await NotificationService.isWeeklyPhotoScheduled() }
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

    private var versionFooter: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Aurelia \(version) (\(build)) · data schema \(Persistence.schemaVersionString)"
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
                Haptics.success()
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
        Section {
            ForEach(supplements) { Text($0.name) }
                .onDelete { offsets in
                    offsets.map { supplements[$0] }.forEach(context.delete)
                    try? context.save()
                }
                .onMove { from, to in
                    var reordered = supplements
                    reordered.move(fromOffsets: from, toOffset: to)
                    for (index, supplement) in reordered.enumerated() { supplement.order = index }
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
        } header: {
            HStack {
                Text("Supplements")
                Spacer()
                if supplements.count > 1 { EditButton().font(.caption) }
            }
        }
    }

    private var trainingSection: some View {
        Section {
            Picker("Default rest", selection: $restSeconds) {
                Text("1:00").tag(60); Text("1:30").tag(90); Text("2:00").tag(120); Text("3:00").tag(180)
            }
            Toggle("Start rest timer when a set is ticked", isOn: $autoRest)
        } header: { Text("Training") } footer: {
            Text("The rest timer runs at the bottom of a strength session and notifies you when it ends, even with the phone locked.")
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
        Section {
            Toggle("Workout days", isOn: $workoutReminderOn)
                .onChange(of: workoutReminderOn) { _, on in
                    Task {
                        if on {
                            guard await ensurePermission() else { workoutReminderOn = false; return }
                            await ReminderSettings.refreshWorkoutReminders(templates: templates)
                        } else {
                            await NotificationService.cancelWorkoutReminders()
                        }
                    }
                }
            if workoutReminderOn {
                DatePicker("Time", selection: minutesBinding($workoutMinutes), displayedComponents: .hourAndMinute)
                    .onChange(of: workoutMinutes) { _, _ in Task { await ReminderSettings.refreshWorkoutReminders(templates: templates) } }
                if templates.allSatisfy({ $0.weekday == 0 }) {
                    Text("No template has a scheduled weekday yet. Set one in Workout → Weekly schedule.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Toggle("Evening log check-in", isOn: $dailyReminderOn)
                .onChange(of: dailyReminderOn) { _, on in
                    Task {
                        if on {
                            guard await ensurePermission() else { dailyReminderOn = false; return }
                            try? await NotificationService.scheduleDailyLogReminder(hour: dailyMinutes / 60, minute: dailyMinutes % 60)
                        } else {
                            NotificationService.cancelDailyLogReminder()
                        }
                    }
                }
            if dailyReminderOn {
                DatePicker("Time", selection: minutesBinding($dailyMinutes), displayedComponents: .hourAndMinute)
                    .onChange(of: dailyMinutes) { _, minutes in
                        Task { try? await NotificationService.scheduleDailyLogReminder(hour: minutes / 60, minute: minutes % 60) }
                    }
            }
            Toggle("Weekly photo reminder (Sunday 9 am)", isOn: $photoReminderOn)
                .onChange(of: photoReminderOn) { _, on in
                    Task {
                        if on {
                            guard await ensurePermission() else { photoReminderOn = false; return }
                            try? await NotificationService.scheduleWeeklyPhotos()
                        } else {
                            NotificationService.cancelWeeklyPhotos()
                        }
                    }
                }
            if let reminderNote { Text(reminderNote).font(.footnote).foregroundStyle(.secondary) }
        } header: { Text("Reminders") } footer: {
            Text("Workout reminders fire on the weekdays your templates are scheduled. The evening check-in nudges you to log meals, water, and weight.")
        }
    }

    private var dataSection: some View {
        Section {
            Button { export() } label: { Label("Export all data (JSON)", systemImage: "square.and.arrow.up") }
            if let exportError { Text(exportError).font(.footnote).foregroundStyle(.red) }
            if !demo.isEnabled {
                Button { showImporter = true } label: { Label("Restore from a backup…", systemImage: "square.and.arrow.down") }
                if let restoreMessage { Text(restoreMessage).font(.footnote).foregroundStyle(.secondary) }
            }
            if !demo.isEnabled {
                Button { cleanupReport = DemoCleanup.scan(context: context) } label: {
                    Label("Check for old demo data", systemImage: "magnifyingglass")
                }
                if let cleanupResult { Text(cleanupResult).font(.footnote).foregroundStyle(.secondary) }
            }
        } header: { Text("Your data") } footer: {
            Text("Export writes every log to a JSON file you can save to Files, AirDrop, or email. Restore replaces everything with a backup file. Progress photos are listed by filename, not embedded. \"Check for old demo data\" finds rows an earlier build's demo mode wrote into your real records.")
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

    /// Minutes-since-midnight as a Date for `DatePicker`; only the time of day is kept.
    private func minutesBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: .now) ?? .now },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            })
    }

    // MARK: Actions

    private func ensurePermission() async -> Bool {
        let granted = (try? await NotificationService.request()) ?? false
        reminderNote = granted ? nil : "Notifications are off for Aurelia in iOS Settings."
        if !granted { Haptics.warning() }
        return granted
    }

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

    private func restore(_ export: AureliaExport) {
        // Leave this screen first: it holds the profile that is about to be deleted.
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            do {
                try ImportService.restore(export, context: context)
                Haptics.success()
            } catch {
                Haptics.warning()
            }
            DemoModeController.shared.rebuildViews()
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
