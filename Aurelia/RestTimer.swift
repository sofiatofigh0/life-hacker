import Foundation
import Observation
import SwiftUI
import UserNotifications

/// A between-sets rest timer. In-app countdown with a haptic at zero, plus a
/// local notification so it still fires when the phone is locked — the same
/// pattern Strong and Hevy use.
@MainActor @Observable
final class RestTimer {
    static let shared = RestTimer()
    static let notificationIdentifier = "rest-timer"

    private(set) var endDate: Date?
    private(set) var remaining = 0
    private var ticker: Task<Void, Never>?

    var isRunning: Bool { endDate != nil }

    func start(seconds: Int) {
        cancel()
        let end = Date.now.addingTimeInterval(TimeInterval(seconds))
        endDate = end
        remaining = seconds
        scheduleNotification(in: seconds)
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let end = self.endDate else { break }
                let left = Int(end.timeIntervalSinceNow.rounded(.up))
                self.remaining = max(0, left)
                if left <= 0 {
                    self.endDate = nil
                    Haptics.success()
                    break
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func add(seconds: Int) {
        guard let end = endDate else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(seconds))
        endDate = newEnd
        remaining = max(0, Int(newEnd.timeIntervalSinceNow.rounded(.up)))
        scheduleNotification(in: remaining)
    }

    func cancel() {
        ticker?.cancel()
        ticker = nil
        endDate = nil
        remaining = 0
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }

    private func scheduleNotification(in seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: trigger))
    }

    static func format(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Pinned to the bottom of a strength session.
struct RestTimerBar: View {
    @State private var timer = RestTimer.shared
    @AppStorage("aurelia.restSeconds") private var defaultSeconds = 90

    var body: some View {
        HStack(spacing: 10) {
            if timer.isRunning {
                Image(systemName: "timer").foregroundStyle(.sage)
                Text(RestTimer.format(timer.remaining))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer()
                Button("+30s") { timer.add(seconds: 30) }.buttonStyle(.bordered).controlSize(.small)
                Button("Skip") { timer.cancel() }.buttonStyle(.bordered).controlSize(.small)
            } else {
                Text("Rest").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                ForEach([60, 90, 120, 180], id: \.self) { seconds in
                    Button(seconds < 120 ? "\(seconds)s" : "\(seconds / 60)m") {
                        defaultSeconds = seconds
                        timer.start(seconds: seconds)
                        Haptics.tap()
                    }
                    .buttonStyle(seconds == defaultSeconds ? .borderedProminent : .bordered)
                    .controlSize(.small)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.easeInOut(duration: 0.2), value: timer.isRunning)
    }
}
