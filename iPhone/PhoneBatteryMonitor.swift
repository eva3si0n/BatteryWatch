import UIKit
import WatchConnectivity
import UserNotifications
import Combine

final class PhoneBatteryMonitor: NSObject, ObservableObject {
    @Published private(set) var data: BatteryData = .load()

    static let shared = PhoneBatteryMonitor()

    private var session: WCSession?

    // Charge target (user has an 80% hardware charge limit) and low-battery warning
    private let highThreshold = 80
    private let lowThreshold = 20

    override private init() {
        super.init()
        UIDevice.current.isBatteryMonitoringEnabled = true
        requestNotificationAuthorization()
        setupWatchConnectivity()
        refresh()
        subscribeToSystemNotifications()
    }

    // MARK: - Public

    func refresh() {
        let fresh = currentData()
        fresh.save()
        data = fresh
        checkThresholds(fresh)
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

    // MARK: - Notifications

    private let highNotifiedKey = "com.batterywatch.notifiedHigh"
    private let lowNotifiedKey = "com.batterywatch.notifiedLow"

    private var defaults: UserDefaults? { UserDefaults(suiteName: BatteryData.appGroupID) }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func checkThresholds(_ data: BatteryData) {
        guard !data.isUnknown, let defaults else { return }
        let pct = data.percentage
        let onPower = data.isCharging // charging or full

        // Reached charge target while on power — fire once per charging session
        if pct >= highThreshold, onPower {
            if !defaults.bool(forKey: highNotifiedKey) {
                defaults.set(true, forKey: highNotifiedKey)
                notify(title: "iPhone заряжён до \(highThreshold)%",
                       body: "Зарядка достигла лимита — можно отключать.")
            }
        } else if pct < highThreshold - 5 || !onPower {
            defaults.set(false, forKey: highNotifiedKey) // reset (hysteresis)
        }

        // Low battery while discharging — fire once per discharge
        if pct <= lowThreshold, !onPower {
            if !defaults.bool(forKey: lowNotifiedKey) {
                defaults.set(true, forKey: lowNotifiedKey)
                notify(title: "Низкий заряд iPhone — \(pct)%",
                       body: "Пора поставить на зарядку.")
            }
        } else if pct >= lowThreshold + 5 || onPower {
            defaults.set(false, forKey: lowNotifiedKey)
        }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

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
