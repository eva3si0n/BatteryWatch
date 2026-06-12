import WatchConnectivity
import WidgetKit
import Combine

final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published private(set) var data: BatteryData = .load()

    static let shared = WatchConnectivityManager()

    override private init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func requestUpdate() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["ping": true], replyHandler: nil, errorHandler: nil)
    }

    private func handle(_ payload: [String: Any]) {
        guard let fresh = BatteryData.from(dictionary: payload) else { return }
        fresh.save()
        DispatchQueue.main.async { self.data = fresh }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

    // Called when Watch app is foregrounded and iPhone sends sendMessage
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    // Called for background complication updates (transferCurrentComplicationUserInfo)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }

    // Fallback: application context
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }
}
