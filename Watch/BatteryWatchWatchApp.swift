import SwiftUI

@main
struct BatteryWatchWatchApp: App {
    init() {
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
