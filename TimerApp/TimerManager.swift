import Foundation
import UserNotifications
import Combine
import SwiftUI

final class WorkTimer: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let totalDuration: TimeInterval

    @Published var remainingTime: TimeInterval
    @Published var state: TimerState = .idle

    enum TimerState {
        case idle, running, paused
    }

    private var timerCancellable: AnyCancellable?
    private var lastTickDate: Date?

    init(name: String, duration: TimeInterval) {
        self.name = name
        self.totalDuration = duration
        self.remainingTime = duration
    }

    var remainingTimeString: String {
        let negative = remainingTime < 0
        let absTime = abs(Int(remainingTime))
        let h = absTime / 3600
        let m = absTime % 3600 / 60
        let s = absTime % 60
        let base: String
        if h > 0 {
            base = String(format: "%d:%02d:%02d", h, m, s)
        } else {
            base = String(format: "%02d:%02d", m, s)
        }
        return negative ? "-\(base)" : base
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let spent = totalDuration - remainingTime
        return max(0, min(1, spent / totalDuration))
    }

    var isRunning: Bool { state == .running }
    var isOvertime: Bool { remainingTime < 0 }

    func start(tick: @escaping (_ delta: TimeInterval, _ isOvertime: Bool) -> Void) {
        guard state == .idle || state == .paused else { return }
        state = .running
        lastTickDate = Date()

        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self = self, self.state == .running else { return }
                let previous = self.lastTickDate ?? now
                let delta = max(0, now.timeIntervalSince(previous))
                self.lastTickDate = now
                self.remainingTime -= delta
                tick(delta, self.isOvertime)
            }
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        timerCancellable?.cancel()
        timerCancellable = nil
        lastTickDate = nil
    }

    func reset() {
        timerCancellable?.cancel()
        timerCancellable = nil
        state = .idle
        remainingTime = totalDuration
        lastTickDate = nil
    }

    deinit {
        timerCancellable?.cancel()
    }
}

final class TimerManager: ObservableObject {
    @Published var timers: [WorkTimer] = []

    @Published private(set) var totalActiveSeconds: TimeInterval = UserDefaults.standard.double(forKey: "totalActiveSeconds") {
        didSet {
            UserDefaults.standard.set(totalActiveSeconds, forKey: "totalActiveSeconds")
        }
    }

    @Published var dailyLimitMinutes: Int = UserDefaults.standard.object(forKey: "dailyLimitMinutes") as? Int ?? 300 {
        didSet {
            UserDefaults.standard.set(dailyLimitMinutes, forKey: "dailyLimitMinutes")
        }
    }

    @Published var sessionLimitMinutes: Int = UserDefaults.standard.object(forKey: "sessionLimitMinutes") as? Int ?? 75 {
        didSet {
            UserDefaults.standard.set(sessionLimitMinutes, forKey: "sessionLimitMinutes")
        }
    }

    @Published var currentSessionSeconds: TimeInterval = 0
    @Published var dailySeconds: TimeInterval = 0 {
        didSet {
            UserDefaults.standard.set(dailySeconds, forKey: "dailySeconds")
            UserDefaults.standard.set(Date(), forKey: "lastDailyUpdate")
        }
    }

    @Published var dailyOvertimeSeconds: TimeInterval = 0
    @Published var sessionOvertimeSeconds: TimeInterval = 0
    @Published var showDailyLimitAlert = false
    @Published var showSessionLimitAlert = false

    private var dailyTimer: Timer?
    private var timerObservers: Set<AnyCancellable> = []

    init() {
        let savedDaily = UserDefaults.standard.double(forKey: "dailySeconds")
        let lastUpdate = UserDefaults.standard.object(forKey: "lastDailyUpdate") as? Date ?? Date.distantPast

        if Calendar.current.isDateInToday(lastUpdate) {
            self.dailySeconds = savedDaily
        } else {
            self.dailySeconds = 0
        }

        setupMidnightReset()
    }

    var activeTimer: WorkTimer? {
        timers.first(where: { $0.isRunning })
    }

    /// Wordt elke seconde aangeroepen vanuit AppDelegate zolang de gebruiker actief is.
    func tickActivity() {
        totalActiveSeconds += 1
        UserDefaults.standard.set(totalActiveSeconds, forKey: "totalActiveSeconds")
        dailySeconds += 1
        currentSessionSeconds += 1
        checkLimits()
    }

    func addTimer(name: String, duration: TimeInterval) {
        let t = WorkTimer(name: name, duration: duration)
        // Forward timer changes to TimerManager so SwiftUI views re-render
        t.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &timerObservers)
        timers.append(t)
    }

    func start(_ timer: WorkTimer) {
        for t in timers where t.id != timer.id && t.isRunning {
            t.pause()
        }
        timer.start { [weak self] delta, isOvertime in
            guard let self = self else { return }
            if isOvertime {
                self.totalActiveSeconds = max(0, self.totalActiveSeconds - delta)
            } else {
                self.totalActiveSeconds += delta
            }
            self.addLimitTime(delta, isTimerOvertime: isOvertime)
        }
    }

    func pause(_ timer: WorkTimer) {
        timer.pause()
        if !timers.contains(where: { $0.isRunning }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
                if let self = self, !self.timers.contains(where: { $0.isRunning }) {
                    self.resetSession()
                }
            }
        }
    }

    func reset(_ timer: WorkTimer) {
        timer.reset()
    }

    func remove(_ timer: WorkTimer) {
        timer.reset()
        timers.removeAll { $0.id == timer.id }
    }

    private func addLimitTime(_ seconds: TimeInterval, isTimerOvertime: Bool) {
        if isTimerOvertime {
            dailySeconds = max(0, dailySeconds - seconds)
            currentSessionSeconds = max(0, currentSessionSeconds - seconds)
            dailyOvertimeSeconds += seconds
            sessionOvertimeSeconds += seconds
        } else {
            dailySeconds += seconds
            currentSessionSeconds += seconds
        }
        checkLimits()
    }

    private func checkLimits() {
        let dailyLimitSeconds = TimeInterval(dailyLimitMinutes * 60)
        let sessionLimitSeconds = TimeInterval(sessionLimitMinutes * 60)
        if dailySeconds >= dailyLimitSeconds && !showDailyLimitAlert {
            showDailyLimitAlert = true
        }
        if currentSessionSeconds >= sessionLimitSeconds && !showSessionLimitAlert {
            showSessionLimitAlert = true
        }
    }

    func extendDailyLimit(by minutes: Int) {
        dailyLimitMinutes += minutes
        showDailyLimitAlert = false
    }

    func extendSessionLimit(by minutes: Int) {
        sessionLimitMinutes += minutes
        showSessionLimitAlert = false
    }

    func resetSession() {
        currentSessionSeconds = 0
        sessionOvertimeSeconds = 0
    }

    func resetDaily() {
        dailySeconds = 0
        dailyOvertimeSeconds = 0
    }

    var dailyRemainingSeconds: TimeInterval {
        TimeInterval(dailyLimitMinutes * 60) - dailySeconds
    }

    var sessionRemainingSeconds: TimeInterval {
        TimeInterval(sessionLimitMinutes * 60) - currentSessionSeconds
    }

    var isDailyLimitExceeded: Bool {
        dailySeconds >= TimeInterval(dailyLimitMinutes * 60)
    }

    var isSessionLimitExceeded: Bool {
        currentSessionSeconds >= TimeInterval(sessionLimitMinutes * 60)
    }

    func dailyProgressPercentage() -> Double {
        let limit = TimeInterval(dailyLimitMinutes * 60)
        guard limit > 0 else { return 0 }
        return min(1.0, dailySeconds / limit)
    }

    func sessionProgressPercentage() -> Double {
        let limit = TimeInterval(sessionLimitMinutes * 60)
        guard limit > 0 else { return 0 }
        return min(1.0, currentSessionSeconds / limit)
    }

    private func setupMidnightReset() {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let midnight = calendar.startOfDay(for: tomorrow)
        dailyTimer = Timer(fireAt: midnight, interval: 24 * 3600, target: self, selector: #selector(resetDailyAutomatically), userInfo: nil, repeats: true)
        RunLoop.main.add(dailyTimer!, forMode: .common)
    }

    @objc private func resetDailyAutomatically() {
        resetDaily()
    }

    func totalActiveString() -> String {
        let total = Int(max(0, totalActiveSeconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let absSeconds = abs(Int(seconds))
        let hours = absSeconds / 3600
        let minutes = (absSeconds % 3600) / 60
        let secs = absSeconds % 60
        let timeString: String
        if hours > 0 {
            timeString = String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            timeString = String(format: "%02d:%02d", minutes, secs)
        }
        return seconds < 0 ? "-\(timeString)" : timeString
    }

    func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            if remainingMinutes > 0 {
                return "\(hours)u \(remainingMinutes)m"
            } else {
                return "\(hours)u"
            }
        } else {
            return "\(remainingMinutes)m"
        }
    }

    func activeDisplayTitle() -> String {
        if let active = activeTimer {
            return active.remainingTimeString
        } else {
            return "⏱"
        }
    }

    deinit {
        dailyTimer?.invalidate()
    }
}
