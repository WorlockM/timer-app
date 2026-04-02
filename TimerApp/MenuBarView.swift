import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var showLimitSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if timerManager.showDailyLimitAlert {
                OvertimeAlertView(
                    title: "Dagelijkse limiet bereikt!",
                    message: "Je hebt je dagelijkse limiet van \(timerManager.formatMinutes(timerManager.dailyLimitMinutes)) bereikt. Wil je doorgaan?",
                    onExtend: { minutes in timerManager.extendDailyLimit(by: minutes) },
                    onDismiss: { timerManager.showDailyLimitAlert = false }
                )
            } else if timerManager.showSessionLimitAlert {
                OvertimeAlertView(
                    title: "Sessie limiet bereikt!",
                    message: "Je huidige sessie heeft de limiet van \(timerManager.formatMinutes(timerManager.effectiveSessionLimitMinutes)) bereikt. Wil je doorgaan?",
                    onExtend: { minutes in timerManager.extendSessionLimit(by: minutes) },
                    onDismiss: { timerManager.showSessionLimitAlert = false }
                )
            } else if showLimitSettings {
                LimitSettingsView(timerManager: timerManager) {
                    showLimitSettings = false
                }
            } else {
                headerView
                Divider()
                limitView
                Divider()
                stopButton
            }
        }
        .frame(width: 300)
    }

    private var headerView: some View {
        HStack {
            Text("Tijdstracker")
                .font(.headline)
            Spacer()
            Button {
                showLimitSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var limitView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text("Dagelijks")
                            .font(.caption.weight(.medium))
                    }
                    Text(timerManager.formatTime(timerManager.dailyRemainingSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(timerManager.isDailyLimitExceeded ? Color.red : Color.primary)
                }
                Spacer()
                ProgressView(value: timerManager.dailyProgressPercentage())
                    .progressViewStyle(.linear)
                    .frame(width: 60)
                    .accentColor(timerManager.isDailyLimitExceeded ? .red : .blue)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Sessie")
                            .font(.caption.weight(.medium))
                    }
                    Text(timerManager.formatTime(timerManager.sessionRemainingSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(timerManager.isSessionLimitExceeded ? Color.red : Color.primary)
                    if timerManager.sessionExtensionMinutes > 0 && timerManager.sessionOriginalOvertimeSeconds > 0 {
                        Text("+\(timerManager.formatTime(timerManager.sessionOriginalOvertimeSeconds)) over limiet")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                ProgressView(value: timerManager.sessionProgressPercentage())
                    .progressViewStyle(.linear)
                    .frame(width: 60)
                    .accentColor(timerManager.isSessionLimitExceeded ? .red : .orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var stopButton: some View {
        HStack {
            Spacer()
            Button("Stop app") {
                NSApplication.shared.terminate(nil)
            }
            .foregroundStyle(.red)
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct LimitSettingsView: View {
    @ObservedObject var timerManager: TimerManager
    let onDismiss: () -> Void

    @State private var dailyMinutes: Int = 300
    @State private var sessionMinutes: Int = 75
    @State private var sessionResetMinutes: Int = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Limiet Instellingen")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Label("Dagelijkse limiet (minuten)", systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
                TextField("Minuten", value: $dailyMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Text("\(dailyMinutes) minuten = \(timerManager.formatMinutes(dailyMinutes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Sessie limiet (minuten)", systemImage: "timer")
                    .font(.subheadline.weight(.medium))
                TextField("Minuten", value: $sessionMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Text("\(sessionMinutes) minuten = \(timerManager.formatMinutes(sessionMinutes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Sessie reset na inactiviteit", systemImage: "pause.circle")
                    .font(.subheadline.weight(.medium))
                TextField("Minuten", value: $sessionResetMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Text("Reset sessie na \(timerManager.formatMinutes(sessionResetMinutes)) inactiviteit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Acties")
                    .font(.subheadline.weight(.medium))
                HStack {
                    Button("Reset Sessie") {
                        timerManager.resetSession()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Reset Dag") {
                        timerManager.resetDaily()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.orange)
                }
            }

            HStack {
                Button("Annuleer") { onDismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Opslaan") {
                    timerManager.dailyLimitMinutes = dailyMinutes
                    timerManager.sessionLimitMinutes = sessionMinutes
                    timerManager.sessionResetMinutes = sessionResetMinutes
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(dailyMinutes <= 0 || sessionMinutes <= 0 || sessionResetMinutes <= 0)
            }
        }
        .padding(20)
        .frame(width: 260)
        .onAppear {
            dailyMinutes = timerManager.dailyLimitMinutes
            sessionMinutes = timerManager.sessionLimitMinutes
            sessionResetMinutes = timerManager.sessionResetMinutes
        }
    }
}

struct OvertimeAlertView: View {
    let title: String
    let message: String
    let onExtend: (Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("5 min") { onExtend(5) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("10 min") { onExtend(10) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Stop") { onDismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}
