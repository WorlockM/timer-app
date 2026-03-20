import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var showAddTimer = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            timerListView
            Divider()
            footerView
        }
        .frame(width: 300)
        .sheet(isPresented: $showAddTimer) {
            AddTimerView { name, duration in
                timerManager.addTimer(name: name, duration: duration)
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("Timers")
                .font(.headline)
            Spacer()
            Button {
                showAddTimer = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var timerListView: some View {
        Group {
            if timerManager.timers.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(timerManager.timers) { timer in
                            TimerRowView(timer: timer) {
                                timerManager.remove(timer)
                            }
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
                .foregroundColor(.secondary)
            Text("Geen timers")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Gebruik + of een snelknop hieronder")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var footerView: some View {
        HStack(spacing: 6) {
            ForEach([("25m", 25.0 * 60), ("45m", 45.0 * 60), ("90m", 90.0 * 60)], id: \.0) { label, duration in
                Button(label) {
                    timerManager.addTimer(name: label, duration: duration)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Spacer()
            Button("Stop app") {
                NSApplication.shared.terminate(nil)
            }
            .foregroundColor(.red)
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct TimerRowView: View {
    @ObservedObject var timer: WorkTimer
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(timer.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .center) {
                Text(timer.remainingTimeString)
                    .font(.system(.title, design: .monospaced))
                    .foregroundColor(timerColor)
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
        switch timer.state {
        case .finished: return .red
        case .running: return .accentColor
        default: return .primary
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        switch timer.state {
        case .idle, .paused:
            Button("Start") { timer.start() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        case .running:
            Button("Pauze") { timer.pause() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .finished:
            HStack {
                Text("Klaar!")
                    .foregroundColor(.red)
                    .font(.caption.bold())
                Button("Reset") { timer.reset() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}
