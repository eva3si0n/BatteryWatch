import SwiftUI

@main
struct BatteryWatchApp: App {
    init() {
        // Activate monitor immediately on launch
        _ = PhoneBatteryMonitor.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
