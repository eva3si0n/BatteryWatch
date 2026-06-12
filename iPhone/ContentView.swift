import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = PhoneBatteryMonitor.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                        .frame(width: 160, height: 160)

                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, monitor.data.level)))
                        .stroke(
                            monitor.data.isCharging ? Color.green : levelColor(monitor.data.level),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: monitor.data.level)

                    VStack(spacing: 4) {
                        if monitor.data.isUnknown {
                            Image(systemName: "questionmark")
                                .font(.largeTitle)
                        } else {
                            Text("\(monitor.data.percentage)%")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            if monitor.data.isCharging {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }

                Text(stateLabel)
                    .foregroundStyle(.secondary)

                Text("Updated: \(formattedTime(monitor.data.timestamp))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    monitor.refresh()
                } label: {
                    Label("Send to Watch", systemImage: "applewatch")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Battery Watch")
        }
    }

    private var stateLabel: String {
        switch monitor.data.state {
        case 2: return String(localized: "Charging")
        case 3: return String(localized: "Charged")
        case 1: return String(localized: "Not charging")
        default: return String(localized: "Unknown")
        }
    }

    private func levelColor(_ level: Float) -> Color {
        if level < 0.2 { return .red }
        if level < 0.4 { return .orange }
        return .green
    }

    private func formattedTime(_ date: Date) -> String {
        if date == .distantPast { return String(localized: "never") }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}
