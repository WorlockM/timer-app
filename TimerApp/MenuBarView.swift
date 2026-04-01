import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var showAddTimer = false
    @State private var showLimitSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showAddTimer {
                AddTimerView { name, duration in
                    timerManager.addTimer(name: name, duration: duration)
                    showAddTimer = false
                } onCancel: {
                    showAddTimer = false
                }
            } else if showLimitSettings {
                LimitSettingsView(timerManager: timerManager) {
                    showLimitSettings = false
                }
            } else {
                headerView
                Divider()
                limitView
                Divider()
                timerListView
                Divider()
                stopButton
            }
        }
        .frame(width: 300)
        .overlay {
            if timerManager.showDailyLimitAlert {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        OvertimeAlertView(
                            title: "Dagelijkse limiet bereikt!",
                            message: "Je hebt je dagelijkse limiet van \(timerManager.formatMinutes(timerManager.dailyLimitMinutes)) bereikt. Wil je doorgaan?",
                            onExtend: { minutes in
                                timerManager.extendDailyLimit(by: minutes)
                            },
                            onDismiss: {
                                timerManager.showDailyLimitAlert = false
                                if let active = timerManager.activeTimer {
                                    timerManager.pause(active)
                                }
                            }
                        )
                    }
            }

            if timerManager.showSessionLimitAlert {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        OvertimeAlertView(
                            title: "Sessie limiet bereikt!",
                            message: "Je huidige sessie heeft de limiet van \(timerManager.formatMinutes(timerManager.sessionLimitMinutes)) bereikt. Wil je doorgaan?",
                            onExtend: { minutes in
                                timerManager.extendSessionLimit(by: minutes)
                            },
                            onDismiss: {
                                timerManager.showSessionLimitAlert = false
                                if let active = timerManager.activeTimer {
                                    timerManager.pause(active)
                                }
                            }
                        )
                    }
            }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Timers")
                    .font(.headline)
                HStack(spacing: 6) {
                    Image(systemName: "sum")
                        .foregroundStyle(.secondary)
                    Text(timerManager.totalActiveString())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("totaal actief")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            Button {
                showLimitSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                showAddTimer = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
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
                    .frame(width: 60)
                    .tint(timerManager.isDailyLimitExceeded ? .red : .blue)
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
                }
                Spacer()
                ProgressView(value: timerManager.sessionProgressPercentage())
                    .frame(width: 60)
                    .tint(timerManager.isSessionLimitExceeded ? .red : .orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var timerListView: some View {
        Group {
            if timerManager.timers.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(timerManager.timers) { timer in
                            TimerRowView(timer: timer,
                                         onStart: { timerManager.start(timer) },
                                         onPause: { timerManager.pause(timer) },
                                         onReset: { timerManager.reset(timer) },
                                         onDelete: { timerManager.remove(timer) })
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 300)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Geen timers")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Gebruik + of een snelknop hieronder")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
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

struct TimerRowView: View {
    @ObservedObject var timer: WorkTimer
    let onStart: () -> Void
    let onPause: () -> Void
    let onReset: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(timer.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .center) {
                Text(timer.remainingTimeString)
                    .font(.system(.title, design: .monospaced))
                    .foregroundStyle(timerColor)
                Spacer()
                controlButtons
            }

            ProgressView(value: timer.progress)
                .tint(timerColor)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private var timerColor: Color {
        if timer.isOvertime { return .red }
        if timer.isRunning { return .accentColor }
        return .primary
    }

    @ViewBuilder
    private var controlButtons: some View {
        switch timer.state {
        case .idle:
            Button("Start") { onStart() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        case .paused:
            HStack {
                Button("Start") { onStart() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Reset") { onReset() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        case .running:
            HStack {
                Button("Pauze") { onPause() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Reset") { onReset() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

struct LimitSettingsView: View {
    @ObservedObject var timerManager: TimerManager
    let onDismiss: () -> Void

    @State private var dailyMinutes: Int = 300
    @State private var sessionMinutes: Int = 75

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
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(dailyMinutes <= 0 || sessionMinutes <= 0)
            }
        }
        .padding(20)
        .frame(width: 260)
        .onAppear {
            dailyMinutes = timerManager.dailyLimitMinutes
            sessionMinutes = timerManager.sessionLimitMinutes
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

            HStack(spacing: 12) {
                Button("5 min") { onExtend(5) }
                    .buttonStyle(.bordered)
                Button("10 min") { onExtend(10) }
                    .buttonStyle(.borderedProminent)
                Button("Stop") { onDismiss() }
                    .buttonStyle(.bordered)
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
