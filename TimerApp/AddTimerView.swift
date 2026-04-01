import SwiftUI

struct AddTimerView: View {
    @State private var name = ""
    @State private var hours = 0
    @State private var minutes = 25
    @State private var seconds = 0

    let onAdd: (String, TimeInterval) -> Void
    let onCancel: () -> Void

    var totalDuration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nieuwe Timer")
                .font(.headline)

            TextField("Naam (bijv. Focusblok)", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                timeField(label: "Uren", value: $hours, range: 0...23)
                Text(":").font(.title2.bold())
                timeField(label: "Min", value: $minutes, range: 0...59)
                Text(":").font(.title2.bold())
                timeField(label: "Sec", value: $seconds, range: 0...59)
            }

            HStack {
                Button("Annuleer") { onCancel() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Voeg toe") {
                    let timerName = name.isEmpty ? formatDuration() : name
                    onAdd(timerName, totalDuration)
                }
                .buttonStyle(.borderedProminent)
                .disabled(totalDuration == 0)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 260)
    }

    private func timeField(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Stepper(value: value, in: range) {
                Text(String(format: "%02d", value.wrappedValue))
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 28, alignment: .center)
            }
        }
    }

    private func formatDuration() -> String {
        if hours > 0 {
            return "\(hours)u \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}
