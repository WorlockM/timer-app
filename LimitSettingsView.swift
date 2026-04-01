import SwiftUI

struct LimitSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var limitManager: LimitManager
    
    @State private var dailyHours: Int = 5
    @State private var dailyMinutes: Int = 0
    @State private var sessionHours: Int = 1
    @State private var sessionMinutes: Int = 15
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Limiet Instellingen")
                .font(.headline)
            
            // Dagelijkse limiet
            VStack(alignment: .leading, spacing: 8) {
                Label("Dagelijkse limiet", systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
                
                HStack(spacing: 8) {
                    VStack {
                        Text("Uren")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Uren", selection: $dailyHours) {
                            ForEach(0..<24) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60, height: 80)
                        .clipped()
                    }
                    
                    Text(":")
                        .font(.title2.bold())
                        .padding(.top, 20)
                    
                    VStack {
                        Text("Minuten")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Minuten", selection: $dailyMinutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60, height: 80)
                        .clipped()
                    }
                }
            }
            
            // Sessie limiet
            VStack(alignment: .leading, spacing: 8) {
                Label("Sessie limiet", systemImage: "timer")
                    .font(.subheadline.weight(.medium))
                
                HStack(spacing: 8) {
                    VStack {
                        Text("Uren")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Uren", selection: $sessionHours) {
                            ForEach(0..<6) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60, height: 80)
                        .clipped()
                    }
                    
                    Text(":")
                        .font(.title2.bold())
                        .padding(.top, 20)
                    
                    VStack {
                        Text("Minuten")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Minuten", selection: $sessionMinutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60, height: 80)
                        .clipped()
                    }
                }
            }
            
            Divider()
            
            // Reset opties
            VStack(alignment: .leading, spacing: 8) {
                Text("Acties")
                    .font(.subheadline.weight(.medium))
                
                HStack {
                    Button("Reset Sessie") {
                        limitManager.resetSession()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Reset Dag") {
                        limitManager.resetDaily()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.orange)
                }
            }
            
            // Buttons
            HStack {
                Button("Annuleer") { 
                    dismiss() 
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Opslaan") {
                    let newDailyLimit = TimeInterval(dailyHours * 3600 + dailyMinutes * 60)
                    let newSessionLimit = TimeInterval(sessionHours * 3600 + sessionMinutes * 60)
                    
                    limitManager.dailyLimitSeconds = newDailyLimit
                    limitManager.sessionLimitSeconds = newSessionLimit
                    
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
            // Initialize with current values
            dailyHours = Int(limitManager.dailyLimitSeconds) / 3600
            dailyMinutes = (Int(limitManager.dailyLimitSeconds) % 3600) / 60
            sessionHours = Int(limitManager.sessionLimitSeconds) / 3600
            sessionMinutes = (Int(limitManager.sessionLimitSeconds) % 3600) / 60
        }
    }
}