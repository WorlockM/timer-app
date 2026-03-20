import SwiftUI

struct AddTimerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var hours = 0
    @State private var minutes = 25
    @State private var seconds = 0

    let onAdd: (String, TimeInterval) -> Void

    var totalDuration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nieuwe Timer")
                .font(.headline)

            TextField("Naam (bijv. Focusblok)", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 4) {
                pickerColumn(label: "Uren", selection: $hours, range: 0..<24)
                Text(":").font(.title2.bold())
                pickerColumn(label: "Min", selection: $minutes, range: 0..<60)
                Text(":").font(.title2.bold())
                pickerColumn(label: "Sec", selection: $seconds, range: 0..<60)
            }
            .frame(height: 100)

            HStack {
                Button("Annuleer") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Voeg toe") {
                    let timerName = name.isEmpty ? formatDuration() : name
                    onAdd(timerName, totalDuration)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(totalDuration == 0)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    private func pickerColumn(label: String, selection: Binding<Int>, range: Range<Int>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70, height: 80)
            .clipped()
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
