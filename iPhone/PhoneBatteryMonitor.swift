import UIKit
import WatchConnectivity
import Combine

final class PhoneBatteryMonitor: NSObject, ObservableObject {
    @Published private(set) var data: BatteryData = .load()

    static let shared = PhoneBatteryMonitor()

    private var session: WCSession?

    override private init() {
        super.init()
        UIDevice.current.isBatteryMonitoringEnabled = true
        setupWatchConnectivity()
        refresh()
        subscribeToSystemNotifications()
    }

    // MARK: - Public

    func refresh() {
        let fresh = currentData()
        fresh.save()
        data = fresh
        sendToWatch(fresh)
    }

    // MARK: - Private

    private func currentData() -> BatteryData {
        #if targetEnvironment(simulator)
        // Simulator has no battery API — demo value so the full data flow is testable
        return BatteryData(level: 0.82, state: 2, timestamp: Date())
        #else
        return BatteryData(
            level: UIDevice.current.batteryLevel,
            state: UIDevice.current.batteryState.rawValue,
            timestamp: Date()
        )
        #endif
    }

    private func subscribeToSystemNotifications() {
        let names: [Notification.Name] = [
            UIDevice.batteryLevelDidChangeNotification,
            UIDevice.batteryStateDidChangeNotification,
            UIApplication.didBecomeActiveNotification,
        ]
        names.forEach {
            NotificationCenter.default.addObserver(self, selector: #selector(systemEvent), name: $0, object: nil)
        }
    }

    @objc private func systemEvent() { refresh() }

    // MARK: - WatchConnectivity

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        session = s
    }

    private func sendToWatch(_ data: BatteryData) {
        guard let s = session, s.activationState == .activated else { return }

        // Latest-state snapshot (coalesced, best-effort)
        try? s.updateApplicationContext(data.asDictionary)

        // Guaranteed FIFO delivery — survives suspension/relaunch, no reachability needed
        s.transferUserInfo(data.asDictionary)

        // Instant path when the watch app is foregrounded
        if s.isReachable {
            s.sendMessage(data.asDictionary, replyHandler: nil, errorHandler: { _ in })
        }
    }

}

extension PhoneBatteryMonitor: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated else { return }
        refresh()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["ping"] != nil { refresh() }
    }
}
