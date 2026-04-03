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
    private(set) var sessionExtensionMinutes: Int = 0
    private(set) var dailyExtensionMinutes: Int = 0

    @Published var dailySeconds: TimeInterval = 0 {
        didSet {
            UserDefaults.standard.set(dailySeconds, forKey: "dailySeconds")
            UserDefaults.standard.set(Date(), forKey: "lastDailyUpdate")
        }
    }

    @Published var showDailyLimitAlert = false
    @Published var showSessionLimitAlert = false
    var dailyAlertDismissed = false
    var sessionAlertDismissed = false

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
        dailyExtensionMinutes += minutes
        dailyAlertDismissed = false
        showDailyLimitAlert = false
    }

    func extendSessionLimit(by minutes: Int) {
        sessionExtensionMinutes += minutes
        sessionAlertDismissed = false
        showSessionLimitAlert = false
    }

    func dismissDailyAlert() {
        dailyAlertDismissed = true
        showDailyLimitAlert = false
    }

    func dismissSessionAlert() {
        sessionAlertDismissed = true
        showSessionLimitAlert = false
    }

    func resetSession() {
        currentSessionSeconds = 0
        sessionExtensionMinutes = 0
        sessionAlertDismissed = false
        showSessionLimitAlert = false
    }

    func resetDaily() {
        dailySeconds = 0
        dailyExtensionMinutes = 0
        dailyAlertDismissed = false
        showDailyLimitAlert = false
    }

    var effectiveDailyLimitMinutes: Int {
        dailyLimitMinutes + dailyExtensionMinutes
    }

    var dailyRemainingSeconds: TimeInterval {
        TimeInterval(effectiveDailyLimitMinutes * 60) - dailySeconds
    }

    var dailyOriginalOvertimeSeconds: TimeInterval {
        dailySeconds - TimeInterval(dailyLimitMinutes * 60)
    }

    var effectiveSessionLimitMinutes: Int {
        sessionLimitMinutes + sessionExtensionMinutes
    }

    var sessionRemainingSeconds: TimeInterval {
        TimeInterval(effectiveSessionLimitMinutes * 60) - currentSessionSeconds
    }

    var sessionOriginalOvertimeSeconds: TimeInterval {
        currentSessionSeconds - TimeInterval(sessionLimitMinutes * 60)
    }

    var isDailyLimitExceeded: Bool {
        dailySeconds >= TimeInterval(effectiveDailyLimitMinutes * 60)
    }

    var isSessionLimitExceeded: Bool {
        currentSessionSeconds >= TimeInterval(effectiveSessionLimitMinutes * 60)
    }

    func dailyProgressPercentage() -> Double {
        let limit = TimeInterval(effectiveDailyLimitMinutes * 60)
        guard limit > 0 else { return 0 }
        return min(1.0, dailySeconds / limit)
    }

    func sessionProgressPercentage() -> Double {
        let limit = TimeInterval(effectiveSessionLimitMinutes * 60)
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
        let dailyLimitSeconds = TimeInterval(effectiveDailyLimitMinutes * 60)
        if dailySeconds >= dailyLimitSeconds && !showDailyLimitAlert && !dailyAlertDismissed {
            showDailyLimitAlert = true
        }
        let sessionLimitSeconds = TimeInterval(effectiveSessionLimitMinutes * 60)
        if currentSessionSeconds >= sessionLimitSeconds && !showSessionLimitAlert && !sessionAlertDismissed {
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
