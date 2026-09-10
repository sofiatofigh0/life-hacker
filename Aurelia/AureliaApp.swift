import SwiftUI
import SwiftData
import Observation
import UIKit

/// Tactile confirmation for actions whose result is otherwise easy to miss.
/// "Pressing something doesn't indicate if it worked" was a direct report.
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

@main struct AureliaApp: App {
    private let container: ModelContainer
    private let storeFailure: String?

    init() {
        let result = Persistence.makeContainer()
        container = result.container
        storeFailure = result.failure
    }

    var body: some Scene {
        WindowGroup {
            ContainerSwitcher(real: container, storeFailure: storeFailure)
        }
    }
}

// MARK: - Demo mode

/// Demo mode is a presentation setting, not user data, so it lives in
/// UserDefaults rather than on the profile. That also lets it decide which
/// *container* the app runs against — the whole point of the redesign.
@MainActor @Observable
final class DemoModeController {
    static let shared = DemoModeController()
    private static let key = "aurelia.demoMode"

    private(set) var isEnabled: Bool
    /// Bumped to rebuild the demo container from scratch.
    private(set) var generation = 0
    /// Bumped after a restore so every view re-fetches against the new rows.
    private(set) var viewGeneration = 0

    private init() { isEnabled = UserDefaults.standard.bool(forKey: Self.key) }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.key)
    }

    /// A binding for a Toggle.
    var enabledBinding: Binding<Bool> {
        Binding(get: { self.isEnabled }, set: { self.setEnabled($0) })
    }

    func reset() { generation += 1 }
    func rebuildViews() { viewGeneration += 1 }
}

/// Chooses between the real store and a throwaway demo store, and rebuilds the
/// view tree when that choice changes so every `@Query` re-fetches.
struct ContainerSwitcher: View {
    let real: ModelContainer
    let storeFailure: String?
    @State private var demo = DemoModeController.shared
    @State private var demoContainer: ModelContainer?

    var body: some View {
        let active = demo.isEnabled ? (demoContainer ?? real) : real
        RootView(storeFailure: demo.isEnabled ? nil : storeFailure)
            .modelContainer(active)
            .id("\(demo.isEnabled)-\(demo.generation)-\(demo.viewGeneration)-\(demoContainer == nil)")
            // A cream and sage palette is designed for light appearance; the
            // cards use `.background`, which went black in dark mode.
            .preferredColorScheme(.light)
            .onChange(of: demo.isEnabled, initial: true) { _, enabled in
                if enabled && demoContainer == nil { demoContainer = Persistence.makeDemoContainer() }
            }
            .onChange(of: demo.generation) { _, _ in
                demoContainer = Persistence.makeDemoContainer()
            }
    }
}

// MARK: - Root

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [AppProfile]
    /// Non-nil when the on-disk store could not be opened and the app is running
    /// against a temporary in-memory database instead.
    var storeFailure: String? = nil
    @State private var sync = HealthSync.shared
    @State private var demo = DemoModeController.shared

    var body: some View {
        VStack(spacing: 0) {
            if let storeFailure { StoreFailureBanner(message: storeFailure) }
            if demo.isEnabled { DemoBanner() }
            Group {
                if let profile = profiles.first, profile.onboarded { MainTabs(profile: profile) }
                else { OnboardingView() }
            }
        }
        .tint(.sage)
        .task { await syncHealthIfAppropriate() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await syncHealthIfAppropriate() } }
        }
    }

    /// Health data belongs to the real store only, and only once there is a
    /// profile to attach it to.
    private func syncHealthIfAppropriate() async {
        guard !demo.isEnabled, profiles.first?.onboarded == true else { return }
        if let last = sync.lastSynced, Date.now.timeIntervalSince(last) < 60 { return }
        await sync.sync(context: context)
    }
}

struct MainTabs: View {
    let profile: AppProfile
    var body: some View {
        TabView {
            NavigationStack { TodayView(profile: profile) }.tabItem { Label("Today", systemImage: "sun.max") }
            NavigationStack { WorkoutHome(profile: profile) }.tabItem { Label("Workout", systemImage: "dumbbell") }
            NavigationStack { FoodView(profile: profile) }.tabItem { Label("Food", systemImage: "leaf") }
            NavigationStack { CalendarHistoryView(profile: profile) }.tabItem { Label("Calendar", systemImage: "calendar") }
            NavigationStack { ProgressTabView(profile: profile) }.tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}

// MARK: - Palette

/// The single source of truth for the palette. Kept separate from the two
/// extensions below so neither can resolve `Color.sage` back to itself.
enum Palette {
    static let sage = Color(red: 0.38, green: 0.49, blue: 0.42)
    static let cream = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let charcoal = Color(red: 0.18, green: 0.18, blue: 0.17)
}

extension Color {
    static let sage = Palette.sage
    static let cream = Palette.cream
    static let charcoal = Palette.charcoal
}

/// Leading-dot syntax in a `ShapeStyle` position — `.foregroundStyle(.sage)`,
/// `.stroke(.sage)`, `.fill(.sage)` — only finds members declared on
/// `ShapeStyle`, not on `Color`. This is how SwiftUI itself exposes `.red`.
extension ShapeStyle where Self == Color {
    static var sage: Color { Palette.sage }
    static var cream: Color { Palette.cream }
    static var charcoal: Color { Palette.charcoal }
}

// MARK: - Banners

/// Shown when the store could not be opened. The app is usable but nothing will
/// persist, so the message has to be unmissable — and it must not suggest
/// deleting the app, which is what would actually destroy the existing data.
struct StoreFailureBanner: View {
    let message: String
    @State private var showDetail = false
    var body: some View {
        Button { showDetail.toggle() } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label("Saved data could not be opened", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                Text("Anything you log now will be lost when you quit. Your existing data is still on the device — do not delete the app.")
                    .font(.caption)
                if showDetail { Text(message).font(.caption2.monospaced()).padding(.top, 2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.orange.opacity(0.18))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

struct DemoBanner: View {
    var body: some View {
        Label("Demo data — your real records are untouched", systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.sage.opacity(0.18))
    }
}

// MARK: - Shared layout

struct EditorialTitle: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
            Text(title).font(.system(.largeTitle, design: .serif, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WellnessCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.05), radius: 14, y: 5)
    }
}

/// The frame every tab root shares: editorial header, optional trailing
/// control, cream ground, and — when it *is* the root — no system nav bar,
/// so the screen has one title instead of two.
struct TabScreen<Trailing: View, Content: View>: View {
    let eyebrow: String
    let title: String
    var hidesNavigationBar = true
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .top) { EditorialTitle(eyebrow: eyebrow, title: title); trailing }
                content
            }
            .padding(18)
        }
        .background(Color.cream.opacity(0.45))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(hidesNavigationBar ? .hidden : .visible, for: .navigationBar)
    }
}

extension TabScreen where Trailing == EmptyView {
    init(eyebrow: String, title: String, hidesNavigationBar: Bool = true, @ViewBuilder content: () -> Content) {
        self.init(eyebrow: eyebrow, title: title, hidesNavigationBar: hidesNavigationBar, trailing: { EmptyView() }, content: content)
    }
}

/// A round header control, e.g. the Settings gear or the Add Food plus.
struct HeaderButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.background, in: Circle())
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
        .accessibilityLabel(label)
    }
}

/// One row of the Today checklist.
struct ChecklistRow: View {
    let title: String
    let detail: String
    let done: Bool
    let icon: String
    var chevron = true
    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 30).foregroundStyle(.sage)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(.sage) }
            else if chevron { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
        }
    }
}

// MARK: - Numeric entry

/// A text field for an optional number. Shows the placeholder when empty
/// instead of a literal "0", accepts either decimal separator, and does not
/// fight the user while they type ("1." stays "1.").
struct DecimalField: View {
    let placeholder: String
    @Binding var value: Double?
    var fractionDigits: Int = 1
    var integer = false
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(integer ? .numberPad : .decimalPad)
            .multilineTextAlignment(.trailing)
            .onAppear { text = format(value) }
            .onChange(of: value) { _, new in
                if !DecimalField.approximatelyEqual(parse(text), new) { text = format(new) }
            }
            .onChange(of: text) { _, new in
                let parsed = parse(new)
                if !DecimalField.approximatelyEqual(parsed, value) { value = parsed }
            }
    }

    private func format(_ v: Double?) -> String {
        guard let v else { return "" }
        return v.formatted(.number.precision(.fractionLength(0...(integer ? 0 : fractionDigits))).grouping(.never))
    }
    private func parse(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : Double(t)
    }
    static func approximatelyEqual(_ a: Double?, _ b: Double?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return abs(x - y) < 0.000_01
        default: return false
        }
    }
}

extension Binding where Value == Double {
    /// Presents 0 as "empty" so a fresh field shows its placeholder.
    var zeroAsNil: Binding<Double?> {
        Binding<Double?>(get: { wrappedValue == 0 ? nil : wrappedValue }, set: { wrappedValue = $0 ?? 0 })
    }
}

extension Binding where Value == Int {
    var zeroAsNil: Binding<Double?> {
        Binding<Double?>(get: { wrappedValue == 0 ? nil : Double(wrappedValue) }, set: { wrappedValue = Int(($0 ?? 0).rounded()) })
    }
}

extension Binding where Value == Double? {
    /// A view of a stored (metric) value in display units.
    func converted(toDisplay out: @escaping (Double) -> Double, fromDisplay input: @escaping (Double) -> Double) -> Binding<Double?> {
        Binding<Double?>(get: { wrappedValue.map(out) }, set: { wrappedValue = $0.map(input) })
    }
}
