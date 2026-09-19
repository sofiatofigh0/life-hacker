import SwiftUI
import SwiftData
import Observation
import os

// MARK: - Tokens

/// The design system in one place. Views use these instead of literals so a
/// change here moves the whole app.
enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
    }
    enum Radius {
        static let control: CGFloat = 10
        static let card: CGFloat = 16
        static let sheet: CGFloat = 24
    }
    enum Shadow {
        static let cardColor = Color.black.opacity(0.04)
        static let cardRadius: CGFloat = 10
        static let cardY: CGFloat = 3
    }
    /// A hairline edge keeps cards legible on the cream ground without a heavy shadow.
    static let hairline = Color.primary.opacity(0.06)
}

// MARK: - Layout

/// Horizontal normally; vertical at accessibility text sizes, where five
/// controls in a row no longer fit.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = Theme.Spacing.sm
    @ViewBuilder var content: Content

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: alignment, spacing: spacing) { content }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}

// MARK: - Appearance

/// System, light, or dark. Stored as a string so the default (system) needs no migration.
enum Appearance: String, CaseIterable {
    case system, light, dark
    static let key = "aurelia.appearance"

    var label: String {
        switch self {
        case .system: return "Match iPhone"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Logging

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Aurelia"
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let health = Logger(subsystem: subsystem, category: "health")
    static let files = Logger(subsystem: subsystem, category: "files")
}

// MARK: - Saving

extension ModelContext {
    /// Saves, and if that fails says so to the person and to the log.
    /// The one place a failed save is allowed to be handled.
    @MainActor
    func commit() {
        do { try save() } catch {
            Log.persistence.error("save failed: \(error.localizedDescription, privacy: .public)")
            ToastCenter.shared.show("That change couldn't be saved. Please try again.", style: .error)
        }
    }
}

// MARK: - Toasts

/// A single, unobtrusive confirmation at the bottom of the screen.
/// One at a time; a new one replaces the current one.
@MainActor @Observable
final class ToastCenter {
    static let shared = ToastCenter()

    enum Style { case success, info, error }

    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let style: Style
        let actionTitle: String?
        let action: (() -> Void)?
    }

    private(set) var current: Toast?
    private var dismissal: Task<Void, Never>?

    func show(_ message: String, style: Style = .success, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        dismissal?.cancel()
        withAnimation(.spring(duration: 0.35)) {
            current = Toast(message: message, style: style, actionTitle: actionTitle, action: action)
        }
        let seconds: Double = action == nil ? 2.4 : 4.5
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissal?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { current = nil }
    }
}

struct ToastHost: View {
    @State private var center = ToastCenter.shared

    var body: some View {
        if let toast = center.current {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon(for: toast.style)).foregroundStyle(tint(for: toast.style))
                Text(toast.message).font(.subheadline).lineLimit(2)
                if let title = toast.actionTitle, let action = toast.action {
                    Spacer(minLength: Theme.Spacing.sm)
                    Button(title) { action(); center.dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.hairline))
            .shadow(color: Theme.Shadow.cardColor, radius: Theme.Shadow.cardRadius, y: Theme.Shadow.cardY)
            .padding(.horizontal, Theme.Spacing.lg)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onTapGesture { center.dismiss() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private func icon(for style: ToastCenter.Style) -> String {
        switch style {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    private func tint(for style: ToastCenter.Style) -> Color {
        switch style {
        case .success: return .sage
        case .info: return .secondary
        case .error: return .orange
        }
    }
}

// MARK: - Empty state

/// The app's one empty state: what this area is for, and the way in.
struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var primary: (title: String, action: () -> Void)? = nil
    var secondary: (title: String, action: () -> Void)? = nil

    var body: some View {
        WellnessCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Image(systemName: icon).font(.title2).foregroundStyle(.sage)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title).font(.headline)
                    Text(message).font(.subheadline).foregroundStyle(.secondary)
                }
                if primary != nil || secondary != nil {
                    HStack(spacing: Theme.Spacing.sm) {
                        if let primary { Button(primary.title, action: primary.action).buttonStyle(.borderedProminent) }
                        if let secondary { Button(secondary.title, action: secondary.action).buttonStyle(.bordered) }
                    }
                    .padding(.top, Theme.Spacing.xs)
                }
            }
        }
    }
}
