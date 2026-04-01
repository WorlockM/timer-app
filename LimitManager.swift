import Foundation
import Combine
import SwiftUI

final class LimitManager: ObservableObject {
    // Dagelijkse limiet in seconden
    @Published var dailyLimitSeconds: TimeInterval = 5 * 3600 // 5 uur default
    
    // Sessie limiet in seconden  
    @Published var sessionLimitSeconds: TimeInterval = 75 * 60 // 75 minuten default
    
    // Huidige sessie tijd
    @Published var currentSessionSeconds: TimeInterval = 0
    
    // Dagelijkse tijd (reset elke dag om middernacht) - geen private(set) meer
    @Published var dailySeconds: TimeInterval {
        didSet {
            UserDefaults.standard.set(dailySeconds, forKey: "dailySeconds")
            UserDefaults.standard.set(Date(), forKey: "lastDailyUpdate")
        }
    }
    
    // Overtime tracking
    @Published var dailyOvertimeSeconds: TimeInterval = 0
    @Published var sessionOvertimeSeconds: TimeInterval = 0
    
    // Alert states
    @Published var showDailyLimitAlert = false
    @Published var showSessionLimitAlert = false
    
    private var dailyTimer: Timer?
    
    init() {
        // Herstel dagelijkse tijd of reset als het een nieuwe dag is
        let savedDaily = UserDefaults.standard.double(forKey: "dailySeconds")
        let lastUpdate = UserDefaults.standard.object(forKey: "lastDailyUpdate") as? Date ?? Date.distantPast
        
        if Calendar.current.isDateInToday(lastUpdate) {
            self.dailySeconds = savedDaily
        } else {
            self.dailySeconds = 0
            UserDefaults.standard.set(0, forKey: "dailySeconds")
        }
        
        // Setup midnight timer voor dagelijkse reset
        setupMidnightReset()
    }
    
    // Voeg tijd toe van een actieve timer
    func addTime(_ seconds: TimeInterval, isTimerOvertime: Bool) {
        if isTimerOvertime {
            // Timer is in overtime, trek af van beide limieten
            dailySeconds = max(0, dailySeconds - seconds)
            currentSessionSeconds = max(0, currentSessionSeconds - seconds)
            
            // Track overtime
            dailyOvertimeSeconds += seconds
            sessionOvertimeSeconds += seconds
        } else {
            // Normale tijd, tel bij beide op
            dailySeconds += seconds
            currentSessionSeconds += seconds
        }
        
        // Check limieten
        checkLimits()
    }
    
    private func checkLimits() {
        // Check dagelijkse limiet
        if dailySeconds >= dailyLimitSeconds && !showDailyLimitAlert {
            showDailyLimitAlert = true
        }
        
        // Check sessie limiet
        if currentSessionSeconds >= sessionLimitSeconds && !showSessionLimitAlert {
            showSessionLimitAlert = true
        }
    }
    
    // Extend daily limit
    func extendDailyLimit(by minutes: Int) {
        dailyLimitSeconds += TimeInterval(minutes * 60)
        showDailyLimitAlert = false
    }
    
    // Extend session limit
    func extendSessionLimit(by minutes: Int) {
        sessionLimitSeconds += TimeInterval(minutes * 60)
        showSessionLimitAlert = false
    }
    
    // Reset sessie (handmatig of automatisch na pauze)
    func resetSession() {
        currentSessionSeconds = 0
        sessionOvertimeSeconds = 0
    }
    
    // Reset dagelijkse tijd (voor settings)
    func resetDaily() {
        dailySeconds = 0
        dailyOvertimeSeconds = 0
    }
    
    // Computed properties voor UI
    var dailyRemainingSeconds: TimeInterval {
        dailyLimitSeconds - dailySeconds
    }
    
    var sessionRemainingSeconds: TimeInterval {
        sessionLimitSeconds - currentSessionSeconds
    }
    
    var isDailyLimitExceeded: Bool {
        dailySeconds >= dailyLimitSeconds
    }
    
    var isSessionLimitExceeded: Bool {
        currentSessionSeconds >= sessionLimitSeconds
    }
    
    // Formatters
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
    
    func dailyProgressPercentage() -> Double {
        guard dailyLimitSeconds > 0 else { return 0 }
        return min(1.0, dailySeconds / dailyLimitSeconds)
    }
    
    func sessionProgressPercentage() -> Double {
        guard sessionLimitSeconds > 0 else { return 0 }
        return min(1.0, currentSessionSeconds / sessionLimitSeconds)
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
    
    deinit {
        dailyTimer?.invalidate()
    }
}

// MARK: - Overtime Alert Views

struct OvertimeAlertView: View {
    let title: String
    let message: String
    let onExtend: (Int) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button("5 min") {
                    onExtend(5)
                }
                .buttonStyle(.bordered)
                
                Button("10 min") {
                    onExtend(10)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Stop") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}