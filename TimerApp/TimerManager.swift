import Foundation
import UserNotifications

class WorkTimer: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let totalDuration: TimeInterval

    @Published var remainingTime: TimeInterval
    @Published var state: TimerState = .idle

    enum TimerState {
        case idle, running, paused, finished
    }

    private var countdown: Timer?
    var onFinish: (() -> Void)?

    init(name: String, duration: TimeInterval) {
        self.name = name
        self.totalDuration = duration
        self.remainingTime = duration
    }

    var remainingTimeString: String {
        let h = Int(remainingTime) / 3600
        let m = Int(remainingTime) % 3600 / 60
        let s = Int(remainingTime) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (remainingTime / totalDuration)
    }

    var isRunning: Bool { state == .running }

    func start() {
        guard state == .idle || state == .paused else { return }
        state = .running
        countdown = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingTime > 0 {
                self.remainingTime -= 1
            } else {
                self.finish()
            }
        }
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        countdown?.invalidate()
        countdown = nil
    }

    func reset() {
        countdown?.invalidate()
        countdown = nil
        state = .idle
        remainingTime = totalDuration
    }

    private func finish() {
        countdown?.invalidate()
        countdown = nil
        state = .finished
        onFinish?()
    }

    deinit {
        countdown?.invalidate()
    }
}

class TimerManager: ObservableObject {
    @Published var timers: [WorkTimer] = []

    var activeTimer: WorkTimer? {
        timers.first(where: { $0.isRunning })
    }

    func addTimer(name: String, duration: TimeInterval) {
        let t = WorkTimer(name: name, duration: duration)
        t.onFinish = { [weak self, weak t] in
            guard let t = t else { return }
            self?.sendNotification(for: t)
        }
        timers.append(t)
    }

    func remove(_ timer: WorkTimer) {
        timer.reset()
        timers.removeAll { $0.id == timer.id }
    }

    private func sendNotification(for timer: WorkTimer) {
        let content = UNMutableNotificationContent()
        content.title = "⏱ Timer klaar!"
        content.body = "'\(timer.name)' is afgelopen. Tijd voor een pauze!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: timer.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
