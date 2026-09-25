import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Scheduling

/// Turns `ReminderEntity` rows into local notifications and keeps the two in
/// step. Every request identifier starts with the reminder's `notificationKey`,
/// so a reminder can be removed or rebuilt without touching the others.
enum ReminderScheduler {
    static let prefix = "reminder-"

    /// Rebuilds every enabled reminder's notifications from scratch.
    @MainActor
    static func rescheduleAll(context: ModelContext) async {
        let reminders = (try? context.fetch(FetchDescriptor<ReminderEntity>())) ?? []
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for reminder in reminders where reminder.enabled {
            for request in requests(for: reminder) { try? await center.add(request) }
        }
    }

    @MainActor
    static func reschedule(_ reminder: ReminderEntity) async {
        await cancel(reminder)
        guard reminder.enabled else { return }
        let center = UNUserNotificationCenter.current()
        for request in requests(for: reminder) { try? await center.add(request) }
    }

    static func cancel(_ reminder: ReminderEntity) async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(reminder.notificationKey) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// One request per firing time per weekday. iOS allows 64 pending
    /// requests per app; a water reminder every hour on every day is 13, so
    /// the editor caps the interval at 30 minutes to stay well under.
    static func requests(for reminder: ReminderEntity) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []
        let days = reminder.weekdays.isEmpty ? [0] : reminder.weekdays
        for (index, minutes) in firingMinutes(for: reminder).enumerated() {
            for day in days {
                var components = DateComponents(hour: minutes / 60, minute: minutes % 60)
                if day > 0 { components.weekday = day }
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = "\(reminder.notificationKey)-\(index)-\(day)"
                requests.append(UNNotificationRequest(identifier: identifier, content: content(for: reminder), trigger: trigger))
            }
        }
        return requests
    }

    static func firingMinutes(for reminder: ReminderEntity) -> [Int] {
        guard reminder.reminderKind == .water, reminder.intervalMinutes >= 30, reminder.endMinutesOfDay > reminder.minutesOfDay else {
            return [reminder.minutesOfDay]
        }
        return Array(stride(from: reminder.minutesOfDay, through: reminder.endMinutesOfDay, by: reminder.intervalMinutes))
    }

    private static func content(for reminder: ReminderEntity) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        switch reminder.reminderKind {
        case .supplement:
            content.title = "Time for \(reminder.title)"
            content.body = "Tick it off on the Today tab."
        case .water:
            content.title = reminder.title.isEmpty ? "Water" : reminder.title
            content.body = "A glass now keeps the day on track."
        case .other:
            content.title = reminder.title
            content.body = "Reminder from Aurelia."
        }
        content.sound = .default
        content.threadIdentifier = reminder.kind
        return content
    }

    /// "8:00 AM · every day" / "9:00 AM – 9:00 PM every 2 h · Mon, Wed, Fri".
    static func summary(for reminder: ReminderEntity) -> String {
        var parts: [String] = []
        if reminder.reminderKind == .water, reminder.intervalMinutes >= 30, reminder.endMinutesOfDay > reminder.minutesOfDay {
            let interval = reminder.intervalMinutes % 60 == 0 ? "\(reminder.intervalMinutes / 60) h" : "\(reminder.intervalMinutes) min"
            parts.append("\(time(reminder.minutesOfDay)) – \(time(reminder.endMinutesOfDay)) every \(interval)")
        } else {
            parts.append(time(reminder.minutesOfDay))
        }
        if reminder.weekdays.isEmpty {
            parts.append("every day")
        } else {
            let symbols = Calendar.current.shortWeekdaySymbols
            parts.append(reminder.weekdays.sorted().map { symbols[$0 - 1] }.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    static func time(_ minutes: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - List

struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ReminderEntity.minutesOfDay) private var reminders: [ReminderEntity]
    @State private var editing: ReminderEntity?
    @State private var creating = false
    @State private var permissionNote: String?

    var body: some View {
        List {
            if reminders.isEmpty {
                Section {
                    Text("Nothing yet. Add a nudge for a supplement, a water schedule, or anything else.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            ForEach(ReminderKind.allCases, id: \.self) { kind in
                let rows = reminders.filter { $0.reminderKind == kind }
                if !rows.isEmpty {
                    Section(kind.label + (rows.count == 1 ? "" : "s")) {
                        ForEach(rows) { reminder in row(reminder) }
                            .onDelete { offsets in
                                for reminder in offsets.map({ rows[$0] }) { delete(reminder) }
                            }
                    }
                }
            }
            if let permissionNote {
                Section { Text(permissionNote).font(.footnote).foregroundStyle(.orange) }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { creating = true } label: { Label("Add reminder", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $creating) { ReminderEditor(reminder: nil) }
        .sheet(item: $editing) { reminder in ReminderEditor(reminder: reminder) }
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            permissionNote = settings.authorizationStatus == .denied
                ? "Notifications are off for Aurelia in iOS Settings, so reminders will not appear." : nil
        }
    }

    private func row(_ reminder: ReminderEntity) -> some View {
        HStack {
            Image(systemName: reminder.reminderKind.icon).foregroundStyle(.sage).frame(width: 28)
            Button { editing = reminder } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title.isEmpty ? reminder.reminderKind.label : reminder.title).foregroundStyle(.primary)
                    Text(ReminderScheduler.summary(for: reminder)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("Enabled", isOn: Binding(get: { reminder.enabled }, set: { on in
                reminder.enabled = on
                context.commit()
                Task { await ReminderScheduler.reschedule(reminder) }
            }))
            .labelsHidden()
        }
    }

    private func delete(_ reminder: ReminderEntity) {
        Task { await ReminderScheduler.cancel(reminder) }
        context.delete(reminder)
        context.commit()
    }
}

// MARK: - Editor

struct ReminderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SupplementEntity.order) private var supplements: [SupplementEntity]
    let reminder: ReminderEntity?

    @State private var kind: ReminderKind
    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var intervalMinutes: Int
    @State private var repeatsDaily: Bool
    @State private var weekdays: Set<Int>
    @State private var permissionNote: String?

    private static let intervals = [30, 60, 90, 120, 180, 240]

    init(reminder: ReminderEntity?) {
        self.reminder = reminder
        _kind = State(initialValue: reminder?.reminderKind ?? .supplement)
        _title = State(initialValue: reminder?.title ?? "")
        _start = State(initialValue: Self.date(minutes: reminder?.minutesOfDay ?? 8 * 60))
        _end = State(initialValue: Self.date(minutes: reminder?.endMinutesOfDay ?? 21 * 60))
        _intervalMinutes = State(initialValue: reminder?.intervalMinutes ?? 120)
        _repeatsDaily = State(initialValue: reminder?.weekdays.isEmpty ?? true)
        _weekdays = State(initialValue: Set(reminder?.weekdays ?? []))
    }

    private var isWaterSchedule: Bool { kind == .water }
    private var canSave: Bool {
        if kind == .other && title.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if kind == .supplement && title.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if !repeatsDaily && weekdays.isEmpty { return false }
        if isWaterSchedule && Self.minutes(end) <= Self.minutes(start) { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(ReminderKind.allCases, id: \.self) { Label($0.label, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch kind {
                    case .supplement:
                        if supplements.isEmpty {
                            TextField("Supplement name", text: $title)
                        } else {
                            Picker("Supplement", selection: $title) {
                                ForEach(supplements) { Text($0.name).tag($0.name) }
                            }
                            .onAppear { if title.isEmpty, let first = supplements.first { title = first.name } }
                        }
                    case .water:
                        TextField("Label (optional)", text: $title)
                    case .other:
                        TextField("What to remind you of", text: $title)
                    }
                }
                Section(isWaterSchedule ? "Schedule" : "Time") {
                    DatePicker(isWaterSchedule ? "From" : "Time", selection: $start, displayedComponents: .hourAndMinute)
                    if isWaterSchedule {
                        DatePicker("Until", selection: $end, displayedComponents: .hourAndMinute)
                        Picker("Every", selection: $intervalMinutes) {
                            ForEach(Self.intervals, id: \.self) { Text($0 % 60 == 0 ? "\($0 / 60) h" : "\($0) min").tag($0) }
                        }
                    }
                }
                Section {
                    Toggle("Every day", isOn: $repeatsDaily)
                    if !repeatsDaily {
                        HStack {
                            ForEach(1...7, id: \.self) { day in
                                let on = weekdays.contains(day)
                                Button(String(Calendar.current.veryShortWeekdaySymbols[day - 1])) {
                                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                                }
                                .buttonStyle(.bordered)
                                .tint(on ? .sage : .secondary)
                                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                } footer: {
                    if isWaterSchedule {
                        Text("Fires \(ReminderScheduler.firingMinutes(for: preview).count) times a day between those hours.")
                    }
                }
                if let permissionNote { Section { Text(permissionNote).font(.footnote).foregroundStyle(.orange) } }
            }
            .navigationTitle(reminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!canSave) }
            }
        }
    }

    /// An unsaved copy for the footer's count.
    private var preview: ReminderEntity {
        ReminderEntity(title: title, kind: kind, minutesOfDay: Self.minutes(start), endMinutesOfDay: Self.minutes(end),
                       intervalMinutes: intervalMinutes, weekdays: repeatsDaily ? [] : Array(weekdays))
    }

    private func save() {
        Task {
            let granted = (try? await NotificationService.request()) ?? false
            guard granted else { permissionNote = "Notifications are off for Aurelia in iOS Settings. Turn them on to receive reminders."; return }
            let target = reminder ?? ReminderEntity(title: "", kind: kind, minutesOfDay: 0)
            target.title = title.trimmingCharacters(in: .whitespaces)
            target.reminderKind = kind
            target.minutesOfDay = Self.minutes(start)
            target.endMinutesOfDay = isWaterSchedule ? Self.minutes(end) : 0
            target.intervalMinutes = isWaterSchedule ? intervalMinutes : 0
            target.weekdays = repeatsDaily ? [] : Array(weekdays).sorted()
            target.enabled = true
            if reminder == nil { context.insert(target) }
            context.commit()
            await ReminderScheduler.reschedule(target)
            Haptics.success()
            ToastCenter.shared.show(reminder == nil ? "Reminder added" : "Reminder updated")
            dismiss()
        }
    }

    private static func minutes(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
    private static func date(minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }
}
