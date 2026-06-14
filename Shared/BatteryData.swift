import Foundation

// Add this file to BOTH iPhone target and Watch App target in Xcode (Target Membership)
struct BatteryData: Codable {
    var level: Float   // 0.0–1.0, negative means unknown
    var state: Int     // UIDevice.BatteryState rawValue: 0=unknown,1=unplugged,2=charging,3=full
    var timestamp: Date

    var percentage: Int { Int((max(0, level) * 100).rounded()) }
    var isCharging: Bool { state == 2 || state == 3 }
    var isUnknown: Bool { level < 0 }

    static let unknown = BatteryData(level: -1, state: 0, timestamp: .distantPast)

    static let appGroupID = "group.com.eva3si0n.batterywatch"
    static let defaultsKey = "com.batterywatch.data"
}

extension BatteryData {
    static func load() -> BatteryData {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let raw = defaults.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(BatteryData.self, from: raw)
        else {
            #if targetEnvironment(simulator)
            // Simulator has no battery API — demo value so UI/complications are visible
            return BatteryData(level: 0.82, state: 2, timestamp: Date())
            #else
            return .unknown
            #endif
        }
        return decoded
    }

    func save() {
        guard
            let defaults = UserDefaults(suiteName: BatteryData.appGroupID),
            let raw = try? JSONEncoder().encode(self)
        else { return }
        defaults.set(raw, forKey: BatteryData.defaultsKey)
    }

    var asDictionary: [String: Any] {
        ["level": level, "state": state, "ts": timestamp.timeIntervalSince1970]
    }

    static func from(dictionary d: [String: Any]) -> BatteryData? {
        guard
            let level = d["level"] as? Float,
            let state = d["state"] as? Int,
            let ts = d["ts"] as? TimeInterval
        else { return nil }
        return BatteryData(level: level, state: state, timestamp: Date(timeIntervalSince1970: ts))
    }
}
