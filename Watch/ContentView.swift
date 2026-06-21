import SwiftUI

struct ContentView: View {
    @StateObject private var conn = WatchConnectivityManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var tapped = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 5)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: CGFloat(max(0, conn.data.level)))
                    .stroke(
                        conn.data.isCharging ? Color.green : levelColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: conn.data.level)

                VStack(spacing: 2) {
                    if conn.data.isUnknown {
                        Image(systemName: "iphone.slash")
                            .font(.title3)
                    } else {
                        Text("\(conn.data.percentage)%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        if conn.data.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }

            Text("iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(staleness)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { conn.requestUpdate() }
        }
        .onTapGesture {
            conn.requestUpdate()
            withAnimation(.easeIn(duration: 0.1)) { tapped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { tapped = false }
        }
        .scaleEffect(tapped ? 0.95 : 1)
    }

    private var levelColor: Color {
        let l = conn.data.level
        if l < 0.2 { return .red }
        if l < 0.4 { return .orange }
        return .green
    }

    private var staleness: String {
        guard !conn.data.isUnknown else { return String(localized: "no data") }
        let mins = Int(-conn.data.timestamp.timeIntervalSinceNow / 60)
        if mins < 1 { return String(localized: "just now") }
        if mins < 60 { return String(localized: "\(mins) min ago") }
        return String(localized: "\(mins / 60) h ago")
    }
}
