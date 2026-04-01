import Foundation
import UserNotifications
import Combine
import SwiftUI

final class TimerManager: ObservableObject {

    @Published var dailyLimitMinutes: Int = UserDefaults.standard.object(forKey: "dailyLimitMinutes") as? Int ?? 300 {
        didSet { UserDefaults.standard.set(dailyLimitMinutes, forKey: "dailyLimitMinutes") }
    }

    @Published var sessionLimitMinutes: Int = UserDefaults.standard.object(forKey: "sessionLimitMinutes") as? Int ?? 75 {
        didSet { UserDefaults.standard.set(sessionLimitMinutes, forKey: "sessionLimitMinutes") }
    }

    @Published var sessionResetMinutes: Int = UserDefaults.standard.object(forKey: "sessionResetMinutes") as? Int ?? 15 {
        didSet { UserDefaults.standard.set(sessionResetMinutes, forKey: "sessionResetMinutes") }
    }

    @Published var currentSessionSeconds: TimeInterval = 0
    @Published var dailySeconds: TimeInterval = 0 {
        didSet {
            UserDefaults.standard.set(dailySeconds, forKey: "dailySeconds")
            UserDefaults.standard.set(Date(), forKey: "lastDailyUpdate")
        }
    }

    @Published var showDailyLimitAlert = false
    @Published var showSessionLimitAlert = false

    private var dailyTimer: Timer?

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

    /// Wordt elke seconde aangeroepen vanuit AppDelegate zolang de gebruiker actief is.
    func tickActivity() {
        dailySeconds += 1
        currentSessionSeconds += 1
        checkLimits()
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
        showSessionLimitAlert = false
    }

    func resetDaily() {
        dailySeconds = 0
        showDailyLimitAlert = false
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
            return remainingMinutes > 0 ? "\(hours)u \(remainingMinutes)m" : "\(hours)u"
        } else {
            return "\(remainingMinutes)m"
        }
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

    private func setupMidnightReset() {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let midnight = calendar.startOfDay(for: tomorrow)
        dailyTimer = Timer(fireAt: midnight, interval: 24 * 3600, target: self,
                           selector: #selector(resetDailyAutomatically), userInfo: nil, repeats: true)
        RunLoop.main.add(dailyTimer!, forMode: .common)
    }

    @objc private func resetDailyAutomatically() {
        resetDaily()
    }

    deinit {
        dailyTimer?.invalidate()
    }
}
