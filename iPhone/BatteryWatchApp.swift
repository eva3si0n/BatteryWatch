import SwiftUI
import BackgroundTasks

@main
struct BatteryWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    static let refreshTaskID = "com.eva3si0n.batterywatch.refresh"

    init() {
        // Activate monitor immediately on launch
        _ = PhoneBatteryMonitor.shared
        registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Self.scheduleRefresh() }
        }
    }

    // iOS wakes the app periodically (its own schedule) so battery thresholds
    // can be checked and notifications fired even while the app is suspended.
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskID, using: nil) { task in
            PhoneBatteryMonitor.shared.refresh()
            Self.scheduleRefresh() // chain the next wake-up
            task.setTaskCompleted(success: true)
        }
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
